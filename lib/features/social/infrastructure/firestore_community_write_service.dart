import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/community/community_errors.dart';
import '../domain/community/community_membership.dart';
import '../domain/community/community_write_service.dart';
import '../domain/community/membership_identity.dart';
import '../models/social_community.dart';

class FirestoreCommunityWriteService implements CommunityWriteService {
  FirestoreCommunityWriteService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String? Function()? currentUserId,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth,
        _currentUserId = currentUserId;

  static const _communities = 'communities';
  static const _memberships = 'community_memberships';

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;
  final String? Function()? _currentUserId;

  @override
  Future<SocialCommunity> createCommunity({
    required String name,
    String? description,
  }) async {
    final ownerId = _requireCurrentUser();
    final normalizedName = _requireText(name, 'name');
    final normalizedDescription = description?.trim();
    final communityReference = _firestore.collection(_communities).doc();
    final membershipId = MembershipIdentity.forPair(
      communityId: communityReference.id,
      userId: ownerId,
    );
    final now = FieldValue.serverTimestamp();
    final communityData = <String, Object?>{
      'name': normalizedName,
      'ownerId': ownerId,
      'status': 'active',
      'createdAt': now,
      'updatedAt': now,
    };
    if (normalizedDescription != null && normalizedDescription.isNotEmpty) {
      communityData['description'] = normalizedDescription;
    }

    try {
      final batch = _firestore.batch();
      batch.set(communityReference, communityData);
      batch.set(
        _firestore.collection(_memberships).doc(membershipId),
        <String, Object?>{
          'communityId': communityReference.id,
          'userId': ownerId,
          'role': 'owner',
          'status': 'active',
          'createdAt': now,
          'updatedAt': now,
        },
      );
      await batch.commit();
      return SocialCommunity(
        id: communityReference.id,
        name: normalizedName,
        description: normalizedDescription?.isEmpty == true
            ? null
            : normalizedDescription,
      );
    } catch (error) {
      throw _mapError(error, 'Unable to create community');
    }
  }

  @override
  Future<CommunityMembership> joinCommunity({
    required String communityId,
  }) async {
    final userId = _requireCurrentUser();
    final normalizedCommunityId = _requireText(communityId, 'communityId');
    try {
      final membershipId = MembershipIdentity.forPair(
        communityId: normalizedCommunityId,
        userId: userId,
      );
      final existing = await _firestore.runTransaction<CommunityMembership?>(
        (transaction) async {
          final communitySnapshot = await transaction.get(
            _firestore.collection(_communities).doc(normalizedCommunityId),
          );
          if (!communitySnapshot.exists) {
            throw const CommunityError(
                CommunityErrorCode.notFound, 'Community not found');
          }
          final communityData = communitySnapshot.data()!;
          if (communityData['status'] != 'active') {
            throw const CommunityError(
                CommunityErrorCode.forbidden, 'Community is not active');
          }

          final membershipReference =
              _firestore.collection(_memberships).doc(membershipId);
          final membershipSnapshot = await transaction.get(membershipReference);
          if (membershipSnapshot.exists) {
            final membership = _membershipFromSnapshot(membershipSnapshot);
            if (membership.isActive) return membership;
            if (membership.status == CommunityMembershipStatus.blocked) {
              throw const CommunityError(
                  CommunityErrorCode.forbidden, 'Membership is blocked');
            }
            throw const CommunityError(
                CommunityErrorCode.conflict, 'Membership already exists');
          }

          final now = FieldValue.serverTimestamp();
          transaction.set(membershipReference, <String, Object?>{
            'communityId': normalizedCommunityId,
            'userId': userId,
            'role': 'member',
            'status': 'active',
            'createdAt': now,
            'updatedAt': now,
          });
          return null;
        },
      );
      if (existing != null) return existing;
      final created = await _readMembership(membershipId);
      if (created == null) {
        throw const CommunityError(
            CommunityErrorCode.unavailable, 'Membership was not readable');
      }
      return created;
    } catch (error) {
      throw _mapError(error, 'Unable to join community');
    }
  }

  Future<CommunityMembership?> _readMembership(String membershipId) async {
    final snapshot =
        await _firestore.collection(_memberships).doc(membershipId).get();
    if (!snapshot.exists) return null;
    return _membershipFromSnapshot(snapshot);
  }

  CommunityMembership _membershipFromSnapshot(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    final communityId = data['communityId'];
    final userId = data['userId'];
    final role = data['role'];
    final status = data['status'];
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    if (communityId is! String ||
        userId is! String ||
        role is! String ||
        status is! String ||
        createdAt is! Timestamp ||
        updatedAt is! Timestamp) {
      throw const CommunityError(
          CommunityErrorCode.invalidMembership, 'Membership is invalid');
    }
    final parsedRole =
        CommunityMemberRole.values.where((value) => value.name == role);
    final parsedStatus =
        CommunityMembershipStatus.values.where((value) => value.name == status);
    if (parsedRole.isEmpty || parsedStatus.isEmpty) {
      throw const CommunityError(
          CommunityErrorCode.invalidMembership, 'Membership enum is invalid');
    }
    return CommunityMembership(
      membershipId: snapshot.id,
      communityId: communityId,
      userId: userId,
      role: parsedRole.first,
      status: parsedStatus.first,
      createdAt: createdAt.toDate().toUtc(),
      updatedAt: updatedAt.toDate().toUtc(),
    );
  }

  String _requireCurrentUser() {
    final userId = _currentUserId != null
        ? _currentUserId!()
        : _auth?.currentUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.trim().isEmpty) {
      throw const CommunityError(
          CommunityErrorCode.unauthorized, 'Authentication is required');
    }
    return userId.trim();
  }

  String _requireText(String value, String field) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw CommunityError(
          CommunityErrorCode.invalidRequest, '$field cannot be empty');
    }
    return normalized;
  }

  CommunityError _mapError(Object error, String message) {
    if (error is CommunityError) return error;
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return CommunityError(CommunityErrorCode.forbidden, message);
        case 'unauthenticated':
          return CommunityError(CommunityErrorCode.unauthorized, message);
        case 'already-exists':
          return CommunityError(CommunityErrorCode.conflict, message);
        case 'unavailable':
        case 'deadline-exceeded':
          return CommunityError(CommunityErrorCode.unavailable, message);
      }
    }
    return CommunityError(CommunityErrorCode.unknown, message);
  }
}
