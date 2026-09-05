import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/admin_profile.dart';
import 'storage_platform.dart';
import 'storage_service.dart';

class AdminProfileService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final StorageService _storage;

  AdminProfileService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    StorageService? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? PlatformStorageService();

  String _cacheKey(String uid) => 'admin_profile_cache_$uid';

  Future<void> _cacheProfile(AdminProfile profile) async {
    await _storage.write(
      key: _cacheKey(profile.uid),
      value: jsonEncode(profile.toMap()),
    );
  }

  Future<AdminProfile?> _readCachedProfile(String uid) async {
    final value = await _storage.read(key: _cacheKey(uid));
    if (value == null || value.isEmpty) return null;
    return AdminProfile.fromMap(
      uid,
      Map<String, dynamic>.from(jsonDecode(value) as Map),
    );
  }

  /// Only trusted backend-issued custom claims can authorize admin access.
  /// A client-side admin profile document is not treated as the security source.
  Future<AdminProfile?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final tokenResult = await user.getIdTokenResult(true);
      final claims = tokenResult.claims ?? <String, dynamic>{};
      final isPrivileged = claims['owner'] == true ||
          claims['admin'] == true ||
          claims['isOwner'] == true ||
          claims['isAdmin'] == true ||
          claims['role'] == 'owner' ||
          claims['role'] == 'admin';

      if (!isPrivileged) {
        return null;
      }

      final doc =
          await _firestore.collection('admin_profiles').doc(user.uid).get();
      final profile = doc.exists
          ? AdminProfile.fromMap(user.uid, doc.data() ?? <String, dynamic>{})
          : AdminProfile(
              uid: user.uid,
              email: user.email,
              displayName: user.displayName,
              isAdmin: true,
            );

      await _cacheProfile(profile);
      return profile;
    } catch (_) {
      try {
        return await _readCachedProfile(user.uid);
      } catch (_) {
        return null;
      }
    }
  }

  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final tokenResult = await user.getIdTokenResult(true);
      final claims = tokenResult.claims ?? <String, dynamic>{};
      return claims['owner'] == true ||
          claims['admin'] == true ||
          claims['isOwner'] == true ||
          claims['isAdmin'] == true ||
          claims['role'] == 'owner' ||
          claims['role'] == 'admin';
    } catch (_) {
      return false;
    }
  }

  Future<void> setAdminProfile(AdminProfile profile) async {
    throw UnsupportedError(
      'Role assignment is backend-authoritative and cannot be set by the client.',
    );
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(displayName);
    await user.reload();
  }

  Future<void> updateProfile({
    required String displayName,
    required String bio,
    required Map<String, String> socialLinks,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(displayName);
    await user.reload();
    final cached = await _readCachedProfile(user.uid);
    final profile = AdminProfile(
      uid: user.uid,
      email: user.email,
      displayName: displayName,
      bio: bio,
      socialLinks: socialLinks,
      isAdmin: cached?.isAdmin ?? false,
    );
    await _cacheProfile(profile);
  }
}
