import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/community/community_errors.dart';
import '../domain/community/community_pagination.dart';
import '../domain/content/community_moderation_action.dart';

abstract class CommunityModerationActionRepository {
  Future<CommunityModerationAction> createAction(
      {required CommunityModerationAction action});
  Future<CommunityPage<CommunityModerationAction>> listActions({
    required String communityId,
    String? targetId,
    String? reportId,
    String? appealId,
    CommunityPageRequest page = const CommunityPageRequest(),
  });
}

class FirestoreCommunityModerationActionRepository
    implements CommunityModerationActionRepository {
  FirestoreCommunityModerationActionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String _collection = 'community_moderation_actions';

  @override
  Future<CommunityModerationAction> createAction(
      {required CommunityModerationAction action}) async {
    try {
      final ref = _firestore.collection(_collection).doc(action.actionId);
      await ref.set(action.toMap());
      return _map(await ref.get());
    } catch (error) {
      throw _mapError(error, 'Unable to create moderation action');
    }
  }

  @override
  Future<CommunityPage<CommunityModerationAction>> listActions({
    required String communityId,
    String? targetId,
    String? reportId,
    String? appealId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_collection)
          .where('communityId', isEqualTo: communityId)
          .orderBy('createdAt', descending: true);

      if (targetId != null) {
        query = query.where('targetId', isEqualTo: targetId);
      }
      if (reportId != null) {
        query = query.where('reportId', isEqualTo: reportId);
      }
      if (appealId != null) {
        query = query.where('appealId', isEqualTo: appealId);
      }

      final snapshots = await query.limit(page.limit + 1).get();
      return CommunityPage(
        items:
            snapshots.docs.take(page.limit).map(_map).toList(growable: false),
        nextCursor: snapshots.docs.length > page.limit
            ? snapshots.docs[page.limit].id
            : null,
      );
    } catch (error) {
      throw _mapError(error, 'Unable to list moderation actions');
    }
  }

  CommunityModerationAction _map(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data =
        Map<String, dynamic>.from(snapshot.data() ?? <String, dynamic>{});
    data['actionId'] ??= snapshot.id;
    if (data['createdAt'] is Timestamp) {
      data['createdAt'] =
          (data['createdAt'] as Timestamp).toDate().toUtc().toIso8601String();
    }
    return CommunityModerationAction.fromMap(data);
  }

  CommunityError _mapError(Object error, String message) {
    if (error is CommunityError) return error;
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return CommunityError(CommunityErrorCode.forbidden, message);
      }
      if (error.code == 'not-found') {
        return CommunityError(CommunityErrorCode.notFound, message);
      }
      if (error.code == 'unavailable') {
        return CommunityError(CommunityErrorCode.unavailable, message);
      }
    }
    return CommunityError(CommunityErrorCode.unknown, message);
  }
}
