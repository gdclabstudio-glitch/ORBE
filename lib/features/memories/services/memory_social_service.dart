import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/storage_platform.dart';
import '../../../services/storage_service.dart';
import '../../../services/outbox_service.dart';

class MemoryComment {
  final String id;
  final String authorId;
  final String authorName;
  final String text;
  final String? parentId;
  final DateTime createdAt;

  const MemoryComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    this.parentId,
    required this.createdAt,
  });

  factory MemoryComment.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final timestamp = data['createdAt'];
    return MemoryComment(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Usuário',
      text: data['text'] as String? ?? '',
      parentId: data['parentId'] as String?,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }
}

class MemorySocialService {
  final FirebaseFirestore _firestore;
  final StorageService _storage;

  MemorySocialService({FirebaseFirestore? firestore, StorageService? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? PlatformStorageService();

  CollectionReference<Map<String, dynamic>> _likes(String memoryId) =>
      _firestore.collection('memories').doc(memoryId).collection('likes');

  CollectionReference<Map<String, dynamic>> _comments(String memoryId) =>
      _firestore.collection('memories').doc(memoryId).collection('comments');

  /// Stream of liked user IDs with local-cache fallback on error
  Stream<List<String>> likesListStream(String memoryId) async* {
    // Listen to remote snapshots and update cache; on error emit cached list
    final controller = StreamController<List<String>>();
    final sub = _likes(memoryId).snapshots().listen(
      (snapshot) async {
        final ids = snapshot.docs.map((d) => d.id).toList(growable: false);
        // persist cache
        try {
          await _storage.write(
            key: 'mem_likes_$memoryId',
            value: jsonEncode(ids),
          );
        } catch (_) {}
        controller.add(ids);
      },
      onError: (e, s) async {
        try {
          final raw = await _storage.read(key: 'mem_likes_$memoryId');
          if (raw != null && raw.isNotEmpty) {
            final list = (jsonDecode(raw) as List)
                .map((e) => e as String)
                .toList(growable: false);
            controller.add(list);
          } else {
            controller.add(const []);
          }
        } catch (_) {
          controller.add(const []);
        }
      },
    );

    // Forward controller stream
    yield* controller.stream;
    await sub.cancel();
    await controller.close();
  }

  Future<int> engagementCount(String memoryId) async {
    try {
      final results = await Future.wait([
        _likes(memoryId).get(),
        _comments(memoryId).get(),
      ]);
      return results[0].size + results[1].size;
    } catch (_) {
      // Fallback to cached counts
      try {
        final likesRaw = await _storage.read(key: 'mem_likes_$memoryId');
        final commentsRaw = await _storage.read(key: 'mem_comments_$memoryId');
        final likesCount =
            likesRaw == null ? 0 : (jsonDecode(likesRaw) as List).length;
        final commentsCount =
            commentsRaw == null ? 0 : (jsonDecode(commentsRaw) as List).length;
        return likesCount + commentsCount;
      } catch (_) {
        return 0;
      }
    }
  }

  Stream<List<MemoryComment>> commentsStream(String memoryId) async* {
    final controller = StreamController<List<MemoryComment>>();
    final sub = _comments(memoryId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen(
      (snapshot) async {
        final list = snapshot.docs
            .map(MemoryComment.fromDocument)
            .toList(growable: false);
        // persist cache
        try {
          final serial = list
              .map(
                (c) => {
                  'id': c.id,
                  'authorId': c.authorId,
                  'authorName': c.authorName,
                  'text': c.text,
                  'parentId': c.parentId,
                  'createdAt': c.createdAt.toIso8601String(),
                },
              )
              .toList(growable: false);
          await _storage.write(
            key: 'mem_comments_$memoryId',
            value: jsonEncode(serial),
          );
        } catch (_) {}
        controller.add(list);
      },
      onError: (e, s) async {
        try {
          final raw = await _storage.read(key: 'mem_comments_$memoryId');
          if (raw != null && raw.isNotEmpty) {
            final decoded = (jsonDecode(raw) as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(growable: false);
            final list = decoded
                .map(
                  (d) => MemoryComment(
                    id: d['id'] as String,
                    authorId: d['authorId'] as String,
                    authorName: d['authorName'] as String,
                    text: d['text'] as String,
                    parentId: d['parentId'] as String?,
                    createdAt: DateTime.tryParse(d['createdAt'] as String) ??
                        DateTime.now(),
                  ),
                )
                .toList(growable: false);
            controller.add(list);
          } else {
            controller.add(const []);
          }
        } catch (_) {
          controller.add(const []);
        }
      },
    );

    yield* controller.stream;
    await sub.cancel();
    await controller.close();
  }

  Future<void> toggleLike({
    required String memoryId,
    required String userId,
  }) async {
    final like = _likes(memoryId).doc(userId);
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(like);
        if (snapshot.exists) {
          transaction.delete(like);
        } else {
          transaction.set(like, {
            'userId': userId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      // enqueue to outbox for later sync
      try {
        await OutboxService.instance.enqueue({
          'id':
              'mem_like:${memoryId}:${userId}:${DateTime.now().millisecondsSinceEpoch}',
          'type': 'mem_like',
          'payload': {'memoryId': memoryId, 'userId': userId},
          'createdAt': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }
  }

  Future<void> addComment({
    required String memoryId,
    required String authorId,
    required String authorName,
    required String text,
    String? parentId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final commentMap = {
      'authorId': authorId,
      'authorName': authorName,
      'text': trimmed,
      'parentId': parentId,
      'createdAt': FieldValue.serverTimestamp(),
    };
    try {
      await _comments(memoryId).add(commentMap);
    } catch (e) {
      try {
        await OutboxService.instance.enqueue({
          'id':
              'mem_comment_add:${memoryId}:${DateTime.now().millisecondsSinceEpoch}',
          'type': 'mem_comment_add',
          'payload': {'memoryId': memoryId, 'comment': commentMap},
          'createdAt': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }
  }

  Future<void> deleteComment({
    required String memoryId,
    required String commentId,
  }) async {
    try {
      await _comments(memoryId).doc(commentId).delete();
    } catch (e) {
      try {
        await OutboxService.instance.enqueue({
          'id':
              'mem_comment_delete:${memoryId}:${commentId}:${DateTime.now().millisecondsSinceEpoch}',
          'type': 'mem_comment_delete',
          'payload': {'memoryId': memoryId, 'commentId': commentId},
          'createdAt': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }
  }
}
