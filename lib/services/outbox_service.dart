import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'storage_platform.dart';
import 'storage_service.dart';

/// OutboxService: persist social write operations locally and sync them when
/// connectivity is restored. Uses StorageService as durable backing store.
class OutboxService {
  static final OutboxService instance = OutboxService._internal();

  final FirebaseFirestore _firestore;
  final StorageService _storage;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  final String _key = 'social:outbox_v1';
  final String _deadLetterKey = 'social:outbox_deadletter_v1';
  bool _processing = false;

  OutboxService._internal()
      : _firestore = FirebaseFirestore.instance,
        _storage = PlatformStorageService() {
    _listenConnectivity();
    // try processing at startup (best-effort)
    _processQueue();
  }

  void _listenConnectivity() {
    try {
      _connSub = Connectivity().onConnectivityChanged.listen((results) {
        if (!results.contains(ConnectivityResult.none)) {
          _processQueue();
        }
      });
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _connSub?.cancel();
  }

  Future<List<Map<String, dynamic>>> _readQueue() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = (jsonDecode(raw) as List<dynamic>);
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeQueue(List<Map<String, dynamic>> items) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(items));
    } catch (_) {}
  }

  Future<void> _appendDeadLetter(
    Map<String, dynamic> item, {
    String? reason,
  }) async {
    try {
      final raw = await _storage.read(key: _deadLetterKey);
      final list = raw == null || raw.isEmpty
          ? <dynamic>[]
          : (jsonDecode(raw) as List<dynamic>);
      final entry = Map<String, dynamic>.from(item)
        ..['deadLetterAt'] = DateTime.now().toIso8601String()
        ..['deadReason'] = reason ?? 'max attempts reached or corrupted';
      list.add(entry);
      await _storage.write(key: _deadLetterKey, value: jsonEncode(list));
    } catch (_) {}
  }

  /// Read dead-letter items for audit/debug
  Future<List<Map<String, dynamic>>> readDeadLetter() async {
    try {
      final raw = await _storage.read(key: _deadLetterKey);
      if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
      final decoded = (jsonDecode(raw) as List<dynamic>);
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// Export dead-letter items to an absolute file path (overwrites if exists)
  Future<void> exportDeadLetterToFile(String filePath) async {
    try {
      final items = await readDeadLetter();
      final file = File(filePath);
      final encoder = const JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(items));
    } catch (_) {
      // ignore file write errors in this helper
    }
  }

  Future<void> enqueue(Map<String, dynamic> action) async {
    final list = await _readQueue();
    final nowIso = DateTime.now().toIso8601String();
    // Normalize and initialize metadata
    final item = Map<String, dynamic>.from(action);
    item['id'] = item['id'] ?? 'outbox:${nowIso}:${list.length}';
    item['attempts'] = 0;
    item['nextAttemptAt'] = null;
    item['createdAt'] = item['createdAt'] ?? nowIso;
    list.add(item);
    await _writeQueue(list);
  }

  // Retry/backoff configuration
  static const int _maxRetries = 5;
  static const int _baseBackoffMs = 500; // 500ms
  static const int _maxBackoffMs = 30000; // 30s

  Future<void> _processQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      var queue = await _readQueue();
      if (queue.isEmpty) return;

      final remaining = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (final item in queue) {
        // Ensure metadata fields
        final attempts = (item['attempts'] as int?) ?? 0;
        final nextAttemptStr = item['nextAttemptAt'] as String?;
        final nextAttempt =
            nextAttemptStr != null ? DateTime.tryParse(nextAttemptStr) : null;

        // If item is scheduled for future attempt, keep it
        if (nextAttempt != null && nextAttempt.isAfter(now)) {
          remaining.add(item);
          continue;
        }

        if (attempts >= _maxRetries) {
          // exhausted - move to dead-letter for auditing
          await _appendDeadLetter(item, reason: 'max attempts reached');
          continue;
        }

        final type = item['type'] as String? ?? '';
        final payload = item['payload'] as Map<String, dynamic>? ?? {};

        try {
          if (type == 'chat_message') {
            final roomId = payload['roomId'] as String? ?? '';
            final messageId =
                payload['messageId'] as String? ?? item['id'] as String? ?? '';
            final message = Map<String, dynamic>.from(
              payload['message'] as Map<String, dynamic>? ?? {},
            );
            if (roomId.isEmpty || messageId.isEmpty) {
              throw StateError('chat_message requires roomId and messageId');
            }
            final ref = _firestore
                .collection('chats')
                .doc(roomId)
                .collection('messages')
                .doc(messageId);
            final exists = await ref.get();
            if (!exists.exists) {
              final payloadMap = Map<String, dynamic>.from(message)
                ..['id'] = messageId
                ..['idempotencyKey'] = message['idempotencyKey'] ?? messageId;
              if (payloadMap['createdAt'] == null) {
                payloadMap['createdAt'] = FieldValue.serverTimestamp();
              }
              await ref.set(payloadMap, SetOptions(merge: true));
            }
          } else if (type == 'mem_like') {
            final memoryId = payload['memoryId'] as String;
            final userId = payload['userId'] as String;
            final likeDoc = _firestore
                .collection('memories')
                .doc(memoryId)
                .collection('likes')
                .doc(userId);
            final snapshot = await likeDoc.get();
            if (snapshot.exists) {
              await likeDoc.delete();
            } else {
              await likeDoc.set({
                'userId': userId,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          } else if (type == 'mem_comment_add') {
            final memoryId = payload['memoryId'] as String;
            final map = Map<String, dynamic>.from(
              payload['comment'] as Map<String, dynamic>,
            );
            await _firestore
                .collection('memories')
                .doc(memoryId)
                .collection('comments')
                .add(map);
          } else if (type == 'story_view') {
            // Persist a viewer-owned story view record:
            // users/{viewerId}/storyViews/{ownerId}_{storyId}
            final viewerId = payload['viewerId'] as String;
            final ownerId = payload['ownerId'] as String;
            final storyId = payload['storyId'] as String;
            final docRef = _firestore
                .collection('users')
                .doc(viewerId)
                .collection('storyViews')
                .doc('${ownerId}_$storyId');
            final sn = await docRef.get();
            if (!sn.exists) {
              await docRef.set({
                'ownerId': ownerId,
                'storyId': storyId,
                'viewerId': viewerId,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          } else if (type == 'story_delete') {
            // Delete story doc and (optionally) its media from storage
            final ownerId = payload['ownerId'] as String;
            final storyId = payload['storyId'] as String;
            final mediaUrl = payload['mediaUrl'] as String?;
            if (mediaUrl != null && mediaUrl.isNotEmpty) {
              try {
                final ref = FirebaseStorage.instance.refFromURL(mediaUrl);
                await ref.delete();
              } catch (_) {}
            }
            try {
              await _firestore
                  .collection('users')
                  .doc(ownerId)
                  .collection('stories')
                  .doc(storyId)
                  .delete();
            } catch (_) {}
          } else if (type == 'follow') {
            // Idempotent follow relationship stored in subcollections while keeping legacy
            // array fields for backward compatibility during migration.
            final from = payload['from'] as String;
            final to = payload['to'] as String;
            try {
              final toRef = _firestore.collection('users').doc(to);
              final fromRef = _firestore.collection('users').doc(from);
              final targetFollowerRef = toRef.collection('followers').doc(from);
              final sourceFollowingRef =
                  fromRef.collection('following').doc(to);
              final isPrivate =
                  ((await toRef.get()).data()?['private'] as bool?) ?? false;

              if (!isPrivate) {
                await _firestore.runTransaction((tx) async {
                  final followerSnap = await tx.get(targetFollowerRef);
                  final followingSnap = await tx.get(sourceFollowingRef);

                  if (!followerSnap.exists) {
                    tx.set(targetFollowerRef, {
                      'userId': to,
                      'followerId': from,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    tx.update(toRef, {
                      'followers': FieldValue.arrayUnion([from]),
                      'stats.followers': FieldValue.increment(1),
                    });
                  }

                  if (!followingSnap.exists) {
                    tx.set(sourceFollowingRef, {
                      'userId': from,
                      'followingId': to,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    tx.update(fromRef, {
                      'following': FieldValue.arrayUnion([to]),
                      'stats.following': FieldValue.increment(1),
                    });
                  }
                });
              }
            } catch (_) {}
          } else if (type == 'unfollow') {
            final from = payload['from'] as String;
            final to = payload['to'] as String;
            try {
              final toRef = _firestore.collection('users').doc(to);
              final fromRef = _firestore.collection('users').doc(from);
              final targetFollowerRef = toRef.collection('followers').doc(from);
              final sourceFollowingRef =
                  fromRef.collection('following').doc(to);

              await _firestore.runTransaction((tx) async {
                final followerSnap = await tx.get(targetFollowerRef);
                final followingSnap = await tx.get(sourceFollowingRef);

                if (followerSnap.exists) {
                  tx.delete(targetFollowerRef);
                  tx.update(toRef, {
                    'followers': FieldValue.arrayRemove([from]),
                    'stats.followers': FieldValue.increment(-1),
                  });
                }

                if (followingSnap.exists) {
                  tx.delete(sourceFollowingRef);
                  tx.update(fromRef, {
                    'following': FieldValue.arrayRemove([to]),
                    'stats.following': FieldValue.increment(-1),
                  });
                }
              });
            } catch (_) {}
          } else if (type == 'mem_comment_delete') {
            final memoryId = payload['memoryId'] as String;
            final commentId = payload['commentId'] as String;
            await _firestore
                .collection('memories')
                .doc(memoryId)
                .collection('comments')
                .doc(commentId)
                .delete();
          } else if (type == 'post_comment_add') {
            final postId = payload['postId'] as String;
            final map = Map<String, dynamic>.from(
              payload['comment'] as Map<String, dynamic>,
            );
            final commentId = (map['id'] as String?) ??
                'comment_${DateTime.now().microsecondsSinceEpoch}';
            final commentsRef = _firestore
                .collection('posts')
                .doc(postId)
                .collection('comments')
                .doc(commentId);
            await commentsRef.set({
              ...map,
              'id': commentId,
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            await _firestore.collection('posts').doc(postId).update({
              'commentCount': FieldValue.increment(1),
            });
          } else if (type == 'post_reaction_add') {
            final postId = payload['postId'] as String;
            final map = Map<String, dynamic>.from(
              payload['reaction'] as Map<String, dynamic>,
            );
            final userId =
                map['userId'] as String? ?? payload['userId'] as String?;
            if (userId == null) {
              throw StateError('post_reaction_add requires userId');
            }
            final reactionRef = _firestore
                .collection('posts')
                .doc(postId)
                .collection('reactions')
                .doc(userId);
            await reactionRef.set({
              ...map,
              'userId': userId,
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            await _firestore.collection('posts').doc(postId).update({
              'reactionCount': FieldValue.increment(1),
            });
          } else if (type == 'post_comment_delete') {
            final postId = payload['postId'] as String;
            final map = Map<String, dynamic>.from(
              payload['comment'] as Map<String, dynamic>,
            );
            final commentId = map['id'] as String?;
            if (commentId != null) {
              await _firestore
                  .collection('posts')
                  .doc(postId)
                  .collection('comments')
                  .doc(commentId)
                  .delete();
            }
            await _firestore.collection('posts').doc(postId).update({
              'commentCount': FieldValue.increment(-1),
            });
          } else {
            // Unknown or corrupt item - record in dead-letter and drop
            await _appendDeadLetter(
              item,
              reason: 'unknown type or corrupt payload',
            );
            continue;
          }
        } catch (e) {
          // Transient failure: increment attempts and schedule next attempt with backoff
          final newAttempts = attempts + 1;
          final backoffMs = (_baseBackoffMs * (1 << (attempts)))
              .clamp(_baseBackoffMs, _maxBackoffMs)
              .toInt();
          final next = DateTime.now().add(Duration(milliseconds: backoffMs));
          final updated = Map<String, dynamic>.from(item)
            ..['attempts'] = newAttempts
            ..['nextAttemptAt'] = next.toIso8601String();

          if (newAttempts < _maxRetries) {
            remaining.add(updated);
          } else {
            // exhausted - drop item (could write to dead-letter log in future)
          }
        }
      }

      // persist remaining
      await _writeQueue(remaining);
    } finally {
      _processing = false;
    }
  }
}
