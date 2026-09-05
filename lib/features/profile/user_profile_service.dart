import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/user_profile.dart';
import '../../services/storage_service.dart';

/// UserProfileService: provides cached read/write of user profiles.
/// - Primary source: Firestore collection 'users' (document id = userId)
/// - Local cache: in-memory map + persistent StorageService (JSON) for offline reads
class UserProfileService {
  final FirebaseFirestore _firestore;
  final StorageService _storage;

  // in-memory cache
  final Map<String, UserProfile> _cache = {};

  UserProfileService({FirebaseFirestore? firestore, StorageService? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ??
            (throw ArgumentError('Provide a StorageService for caching'));

  String _storageKey(String uid) => 'user_profile:$uid:v1';

  /// Attempts to read from in-memory cache, then persistent storage, then Firestore.
  Future<UserProfile?> getUserProfile(String uid) async {
    if (_cache.containsKey(uid)) return _cache[uid];

    // try persistent storage (fast for offline)
    try {
      final raw = await _storage.read(key: _storageKey(uid));
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final profile = UserProfile.fromMap(map);
        _cache[uid] = profile;
        return profile;
      }
    } catch (_) {}

    // fallback to Firestore
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final map = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
      map['id'] = doc.id;
      final profile = UserProfile.fromMap(map);
      _cache[uid] = profile;

      // persist to storage asynchronously (best-effort)
      _storage
          .write(key: _storageKey(uid), value: jsonEncode(profile.toMap()))
          .catchError((_) {});
      return profile;
    } catch (e) {
      if (kDebugMode) debugPrint('UserProfileService.getUserProfile error: $e');
      return null;
    }
  }

  /// Stream profile updates directly from Firestore; does not rely on persistent storage.
  Stream<UserProfile?> userProfileStream(String uid) {
    final docRef = _firestore.collection('users').doc(uid);
    return docRef.snapshots().map((snap) {
      if (!snap.exists) return null;
      final map = Map<String, dynamic>.from(
        snap.data() as Map<String, dynamic>,
      );
      map['id'] = snap.id;
      final profile = UserProfile.fromMap(map);
      // update cache + storage
      _cache[uid] = profile;
      _storage
          .write(key: _storageKey(uid), value: jsonEncode(profile.toMap()))
          .catchError((_) {});
      return profile;
    });
  }

  /// Update allowed profile fields (displayName, bio, avatarUrl). Enforces limits.
  Future<void> updateProfile(UserProfile profile) async {
    final safeName = profile.displayName.length > 60
        ? profile.displayName.substring(0, 60)
        : profile.displayName;
    final safeBio = profile.bio != null && profile.bio!.length > 1000
        ? profile.bio!.substring(0, 1000)
        : profile.bio;

    final data = <String, dynamic>{
      'displayName': safeName,
      'bio': safeBio,
      'avatarUrl': profile.avatarUrl,
      // stats should be updated by server-side functions or separate flows to avoid races
    };

    await _firestore
        .collection('users')
        .doc(profile.id)
        .set(data, SetOptions(merge: true));

    final updated = profile.copyWith(displayName: safeName, bio: safeBio);
    _cache[profile.id] = updated;
    await _storage.write(
      key: _storageKey(profile.id),
      value: jsonEncode(updated.toMap()),
    );
  }

  /// Clear in-memory and persistent cache for a user
  Future<void> clearCache(String uid) async {
    _cache.remove(uid);
    try {
      await _storage.delete(key: _storageKey(uid));
    } catch (_) {}
  }
}
