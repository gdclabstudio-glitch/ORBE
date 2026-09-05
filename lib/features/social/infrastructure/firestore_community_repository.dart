import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/community/community_errors.dart';
import '../domain/community/community_membership.dart';
import '../domain/community/community_pagination.dart';
import '../domain/community/community_repository.dart';
import '../domain/community/membership_identity.dart';
import '../models/social_community.dart';
import '../models/social_topic.dart';

class FirestoreCommunityRepository implements CommunityRepository {
  FirestoreCommunityRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const _communities = 'communities';
  static const _memberships = 'community_memberships';

  final FirebaseFirestore _firestore;

  @override
  Future<SocialCommunity?> getCommunity(String communityId) async {
    _requireId(communityId, CommunityErrorCode.invalidCommunity);
    try {
      final snapshot = await _firestore
          .collection(_communities)
          .doc(communityId.trim())
          .get();
      return snapshot.exists ? _community(snapshot.id, snapshot.data()!) : null;
    } catch (error) {
      throw _mapError(error, 'Unable to read community');
    }
  }

  @override
  Future<CommunityPage<SocialCommunity>> listCommunities({
    CommunityPageRequest page = const CommunityPageRequest(),
  }) async {
    try {
      final query = await _pageQuery(
          _firestore.collection(_communities).orderBy('name'),
          page,
          _communities);
      final snapshots = await query.limit(page.limit + 1).get();
      return CommunityPage(
        items: snapshots.docs
            .take(page.limit)
            .map((doc) => _community(doc.id, doc.data()))
            .toList(),
        nextCursor: snapshots.docs.length > page.limit
            ? _encodeCursor(snapshots.docs[page.limit - 1].id)
            : null,
      );
    } catch (error) {
      throw _mapError(error, 'Unable to list communities');
    }
  }

  @override
  Future<CommunityPage<SocialCommunity>> listUserCommunities({
    required String userId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) async {
    _requireId(userId, CommunityErrorCode.invalidRequest);
    try {
      final query = await _pageQuery(
        _firestore
            .collection(_memberships)
            .where('userId', isEqualTo: userId.trim())
            .where('status', isEqualTo: 'active')
            .orderBy('updatedAt', descending: true),
        page,
        _memberships,
      );
      final snapshots = await query.limit(page.limit + 1).get();
      final membershipDocs = snapshots.docs.take(page.limit).toList();
      final communities = <SocialCommunity>[];
      for (final membership in membershipDocs) {
        final communityId = _requiredString(membership.data()['communityId'],
            'communityId', CommunityErrorCode.invalidMembership);
        final community = await getCommunity(communityId);
        if (community != null) communities.add(community);
      }
      return CommunityPage(
        items: communities,
        nextCursor: snapshots.docs.length > page.limit
            ? _encodeCursor(snapshots.docs[page.limit - 1].id)
            : null,
      );
    } catch (error) {
      throw _mapError(error, 'Unable to list user communities');
    }
  }

  @override
  Future<bool> isMember(
      {required String userId, required String communityId}) async {
    return (await getMembership(userId: userId, communityId: communityId))
            ?.isActive ??
        false;
  }

  @override
  Future<CommunityMembership?> getMembership(
      {required String userId, required String communityId}) async {
    _requireId(userId, CommunityErrorCode.invalidRequest);
    _requireId(communityId, CommunityErrorCode.invalidCommunity);
    try {
      final membershipId =
          MembershipIdentity.forPair(userId: userId, communityId: communityId);
      final snapshot =
          await _firestore.collection(_memberships).doc(membershipId).get();
      return snapshot.exists
          ? _membership(snapshot.id, snapshot.data()!)
          : null;
    } catch (error) {
      throw _mapError(error, 'Unable to read membership');
    }
  }

  @override
  Future<CommunityPage<CommunityMembership>> listMembers(
      {required String communityId,
      CommunityPageRequest page = const CommunityPageRequest()}) async {
    _requireId(communityId, CommunityErrorCode.invalidCommunity);
    try {
      final query = await _pageQuery(
        _firestore
            .collection(_memberships)
            .where('communityId', isEqualTo: communityId.trim())
            .where('status', isEqualTo: 'active')
            .orderBy('createdAt', descending: true),
        page,
        _memberships,
      );
      final snapshots = await query.limit(page.limit + 1).get();
      return CommunityPage(
        items: snapshots.docs
            .take(page.limit)
            .map((doc) => _membership(doc.id, doc.data()))
            .toList(),
        nextCursor: snapshots.docs.length > page.limit
            ? _encodeCursor(snapshots.docs[page.limit - 1].id)
            : null,
      );
    } catch (error) {
      throw _mapError(error, 'Unable to list members');
    }
  }

  @override
  Future<CommunityPage<SocialCommunity>> listCommunitiesByTopic(
      {required String topicId,
      CommunityPageRequest page = const CommunityPageRequest()}) async {
    _requireId(topicId, CommunityErrorCode.invalidRequest);
    try {
      final query = await _pageQuery(
          _firestore
              .collection(_communities)
              .where('topicIds', arrayContains: topicId.trim())
              .orderBy('name'),
          page,
          _communities);
      final snapshots = await query.limit(page.limit + 1).get();
      return CommunityPage(
        items: snapshots.docs
            .take(page.limit)
            .map((doc) => _community(doc.id, doc.data()))
            .toList(),
        nextCursor: snapshots.docs.length > page.limit
            ? _encodeCursor(snapshots.docs[page.limit - 1].id)
            : null,
      );
    } catch (error) {
      throw _mapError(error, 'Unable to list communities by topic');
    }
  }

  Future<Query<Map<String, dynamic>>> _pageQuery(
      Query<Map<String, dynamic>> query,
      CommunityPageRequest page,
      String collection) async {
    if (page.cursor == null) return query;
    final snapshot = await _firestore
        .collection(collection)
        .doc(_decodeCursor(page.cursor!))
        .get();
    if (!snapshot.exists) {
      throw const CommunityError(
          CommunityErrorCode.invalidRequest, 'Invalid cursor');
    }
    return query.startAfterDocument(snapshot);
  }

  SocialCommunity _community(String id, Map<String, dynamic> data) {
    final name = _requiredString(
        data['name'], 'name', CommunityErrorCode.invalidCommunity);
    final topicData = data['topic'];
    return SocialCommunity(
      id: id,
      name: name,
      description: _optionalString(data['description']),
      topic: topicData is Map
          ? _topicFromMap(Map<String, dynamic>.from(topicData))
          : null,
    );
  }

  SocialTopic _topicFromMap(Map<String, dynamic> data) {
    return SocialTopic(
      id: _requiredString(
          data['id'], 'topic.id', CommunityErrorCode.invalidCommunity),
      title: _requiredString(
          data['title'], 'topic.title', CommunityErrorCode.invalidCommunity),
      description: _optionalString(data['description']),
      parentTopicId: _optionalString(data['parentTopicId']),
    );
  }

  CommunityMembership _membership(String id, Map<String, dynamic> data) {
    return CommunityMembership(
      membershipId: id,
      communityId: _requiredString(data['communityId'], 'communityId',
          CommunityErrorCode.invalidMembership),
      userId: _requiredString(
          data['userId'], 'userId', CommunityErrorCode.invalidMembership),
      role: _enumValue(CommunityMemberRole.values, data['role'], 'role'),
      status: _enumValue(
          CommunityMembershipStatus.values, data['status'], 'status'),
      createdAt: _timestamp(data['createdAt'], 'createdAt'),
      updatedAt: _timestamp(data['updatedAt'], 'updatedAt'),
    );
  }

  T _enumValue<T extends Enum>(List<T> values, Object? raw, String field) {
    if (raw is String) {
      for (final value in values) {
        if (value.name == raw) return value;
      }
    }
    throw CommunityError(
        CommunityErrorCode.invalidMembership, 'Invalid $field');
  }

  DateTime _timestamp(Object? value, String field) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    throw CommunityError(
        CommunityErrorCode.invalidMembership, 'Invalid $field');
  }

  String _requiredString(Object? value, String field, CommunityErrorCode code) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw CommunityError(code, 'Missing or invalid $field');
  }

  String? _optionalString(Object? value) => value is String ? value : null;

  void _requireId(String value, CommunityErrorCode code) {
    if (value.trim().isEmpty) throw CommunityError(code, 'ID cannot be empty');
  }

  String _encodeCursor(String id) => base64UrlEncode(utf8.encode(id));

  String _decodeCursor(String cursor) {
    try {
      final id = utf8.decode(base64Url.decode(base64Url.normalize(cursor)));
      if (id.trim().isEmpty) throw const FormatException();
      return id;
    } catch (_) {
      throw const CommunityError(
          CommunityErrorCode.invalidRequest, 'Invalid cursor');
    }
  }

  CommunityError _mapError(Object error, String message) {
    if (error is CommunityError) return error;
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return CommunityError(CommunityErrorCode.forbidden, message);
        case 'unauthenticated':
          return CommunityError(CommunityErrorCode.unauthorized, message);
        case 'unavailable':
        case 'deadline-exceeded':
          return CommunityError(CommunityErrorCode.unavailable, message);
        case 'invalid-argument':
          return CommunityError(CommunityErrorCode.invalidRequest, message);
      }
    }
    return CommunityError(CommunityErrorCode.unknown, message);
  }
}
