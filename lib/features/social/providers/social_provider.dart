import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../services/storage_platform.dart';
import '../../../services/storage_service.dart';
import '../models/user_profile_model.dart';

/// SocialProvider manages friendship flow and Close Friends toggles.
///
/// Primary strategy:
/// - Persist authoritative state in Firestore when available
/// - On failures, use a local persistent fallback via PlatformStorageService
class SocialProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final StorageService _storage;

  // In-memory caches to reduce roundtrips
  final Map<String, UserProfile> _profilesCache = {};

  SocialProvider({FirebaseFirestore? firestore, StorageService? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? PlatformStorageService();

  // Keys used in local storage fallback
  String _profilesKey() => 'social:profiles_cache';
  String _requestsKey(String uid) => 'social:requests:$uid';
  String _friendsKey(String uid) => 'social:friends:$uid';

  /// Search users by name or email (simple client-side filter over cached profiles)
  Future<List<UserProfile>> searchUsers(String query) async {
    final q = query.trim().toLowerCase();

    // Try Firestore search first (basic server-side query by name)
    try {
      final snap = await _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: q)
          .where('name', isLessThanOrEqualTo: '$q\uf8ff')
          .limit(20)
          .get();
      final results =
          snap.docs.map((d) => UserProfile.fromJson(d.data())).toList();

      // warm cache
      for (final p in results) _profilesCache[p.uid] = p;
      await _persistProfilesCache();
      return results;
    } catch (e) {
      // fallback to local cache
      final cached = await _readProfilesCache();
      return cached.where((p) {
        final name = p.name?.toLowerCase() ?? '';
        final email = p.email?.toLowerCase() ?? '';
        return name.contains(q) || email.contains(q) || p.uid.contains(q);
      }).toList();
    }
  }

  /// Send a friend request from [fromUid] to [toUid]
  Future<void> sendFriendRequest(String fromUid, String toUid) async {
    try {
      await _firestore.collection('friend_requests').add({
        'from': fromUid,
        'to': toUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // fallback: persist locally under toUid requests
      final requests = await _readRequests(toUid);
      requests.add(fromUid);
      await _storage.write(
        key: _requestsKey(toUid),
        value: jsonEncode(requests),
      );
    }
    notifyListeners();
  }

  /// Accept a friend request: add both users to each other's friend lists
  Future<void> acceptFriendRequest(
    String currentUid,
    String requesterUid,
  ) async {
    try {
      // Mark request as accepted in Firestore (if present)
      final q = await _firestore
          .collection('friend_requests')
          .where('from', isEqualTo: requesterUid)
          .where('to', isEqualTo: currentUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      for (final doc in q.docs) {
        await doc.reference.update({
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update users' friend lists atomically
      final batch = _firestore.batch();
      final u1 = _firestore.collection('users').doc(currentUid);
      final u2 = _firestore.collection('users').doc(requesterUid);
      batch.update(u1, {
        'friends': FieldValue.arrayUnion([requesterUid]),
      });
      batch.update(u2, {
        'friends': FieldValue.arrayUnion([currentUid]),
      });
      await batch.commit();
    } catch (e) {
      // fallback local: update stored friends lists
      final currentFriends = await _readFriends(currentUid);
      final requesterFriends = await _readFriends(requesterUid);
      if (!currentFriends.contains(requesterUid))
        currentFriends.add(requesterUid);
      if (!requesterFriends.contains(currentUid))
        requesterFriends.add(currentUid);
      await _storage.write(
        key: _friendsKey(currentUid),
        value: jsonEncode(currentFriends),
      );
      await _storage.write(
        key: _friendsKey(requesterUid),
        value: jsonEncode(requesterFriends),
      );

      // remove pending request locally
      final pending = await _readRequests(currentUid);
      pending.remove(requesterUid);
      await _storage.write(
        key: _requestsKey(currentUid),
        value: jsonEncode(pending),
      );
    }
    notifyListeners();
  }

  /// Toggle Close Friend status for [currentUid] regarding [friendUid]
  Future<void> toggleCloseFriend(
    String currentUid,
    String friendUid,
    bool isClose,
  ) async {
    try {
      final userDoc = _firestore.collection('users').doc(currentUid);
      if (isClose) {
        await userDoc.update({
          'closeFriends': FieldValue.arrayUnion([friendUid]),
        });
      } else {
        await userDoc.update({
          'closeFriends': FieldValue.arrayRemove([friendUid]),
        });
      }
    } catch (e) {
      // fallback local
      final currentClose = await _readCloseFriends(currentUid);
      if (isClose) {
        if (!currentClose.contains(friendUid)) currentClose.add(friendUid);
      } else {
        currentClose.remove(friendUid);
      }
      await _storage.write(
        key: 'social:close_friends:$currentUid',
        value: jsonEncode(currentClose),
      );
    }
    notifyListeners();
  }

  /// Read cached profiles from local storage
  Future<List<UserProfile>> _readProfilesCache() async {
    try {
      final raw = await _storage.read(key: _profilesKey());
      if (raw == null) return _profilesCache.values.toList();
      final list =
          (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
      return list.map((m) => UserProfile.fromJson(m)).toList();
    } catch (e) {
      return _profilesCache.values.toList();
    }
  }

  Future<void> _persistProfilesCache() async {
    try {
      final list = _profilesCache.values.map((p) => p.toJson()).toList();
      await _storage.write(key: _profilesKey(), value: jsonEncode(list));
    } catch (_) {}
  }

  Future<List<String>> _readRequests(String uid) async {
    try {
      final raw = await _storage.read(key: _requestsKey(uid));
      if (raw == null) return <String>[];
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (_) {
      return <String>[];
    }
  }

  Future<List<String>> _readFriends(String uid) async {
    try {
      final raw = await _storage.read(key: _friendsKey(uid));
      if (raw == null) return <String>[];
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (_) {
      return <String>[];
    }
  }

  Future<List<String>> _readCloseFriends(String uid) async {
    try {
      final raw = await _storage.read(key: 'social:close_friends:$uid');
      if (raw == null) return <String>[];
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (_) {
      return <String>[];
    }
  }
}
