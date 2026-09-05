import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/community/community_errors.dart';
import '../domain/community/community_pagination.dart';
import '../domain/content/community_content.dart';
import '../domain/content/community_moderation_action.dart';
import '../domain/content/community_moderation_appeal.dart';

abstract class CommunityModerationAppealRepository {
  Future<CommunityModerationAppeal> createAppeal(
      {required CommunityModerationAppeal appeal});
  Future<CommunityModerationAppeal?> getAppeal({required String appealId});
  Future<CommunityPage<CommunityModerationAppeal>> listAppeals({
    required String communityId,
    CommunityPageRequest page = const CommunityPageRequest(),
  });
  Future<CommunityModerationAppeal> resolveAppeal({
    required String appealId,
    required CommunityModerationAppealResolution resolution,
    required String reviewerId,
    required String reviewReason,
  });
}

class FirestoreCommunityModerationAppealRepository
    implements CommunityModerationAppealRepository {
  FirestoreCommunityModerationAppealRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String _collection = 'community_moderation_appeals';

  @override
  Future<CommunityModerationAppeal> createAppeal(
      {required CommunityModerationAppeal appeal}) async {
    try {
      final ref = _firestore.collection(_collection).doc(appeal.appealId);
      final actionRef =
          _firestore.collection('community_moderation_actions').doc();
      await _firestore.runTransaction((transaction) async {
        if ((await transaction.get(ref)).exists) {
          throw const CommunityError(
              CommunityErrorCode.conflict, 'An appeal already exists');
        }
        transaction.set(ref, {
          ...appeal.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(actionRef, {
          'actionId': actionRef.id,
          'communityId': appeal.communityId,
          'actorId': appeal.createdBy,
          'actionType': CommunityModerationActionType.appealCreated.name,
          'targetType': appeal.targetType,
          'targetId': appeal.targetId,
          if (appeal.parentContentId != null)
            'parentContentId': appeal.parentContentId,
          if (appeal.reportId != null) 'reportId': appeal.reportId,
          'appealId': appeal.appealId,
          'reason': appeal.reason,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      return _map(await ref.get());
    } catch (error) {
      throw _mapError(error, 'Unable to create appeal');
    }
  }

  Future<CommunityModerationAppeal> beginAppealReview({
    required String appealId,
    required String reviewerId,
  }) async {
    try {
      final ref = _firestore.collection(_collection).doc(appealId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        if (!snapshot.exists) {
          throw const CommunityError(
              CommunityErrorCode.notFound, 'Appeal not found');
        }
        final current = _map(snapshot);
        if (current.status != CommunityModerationAppealStatus.open) {
          throw const CommunityError(
              CommunityErrorCode.conflict, 'Appeal is not open');
        }
        if (current.createdBy == reviewerId) {
          throw const CommunityError(
              CommunityErrorCode.forbidden, 'Appeal author cannot review it');
        }
        transaction.update(ref, {
          'status': CommunityModerationAppealStatus.underReview.name,
        });
      });
      return _map(await ref.get());
    } catch (error) {
      throw _mapError(error, 'Unable to begin appeal review');
    }
  }

  @override
  Future<CommunityModerationAppeal?> getAppeal(
      {required String appealId}) async {
    try {
      final snapshot =
          await _firestore.collection(_collection).doc(appealId).get();
      if (!snapshot.exists) return null;
      return _map(snapshot);
    } catch (error) {
      throw _mapError(error, 'Unable to read appeal');
    }
  }

  @override
  Future<CommunityPage<CommunityModerationAppeal>> listAppeals({
    required String communityId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) async {
    try {
      final query = _firestore
          .collection(_collection)
          .where('communityId', isEqualTo: communityId)
          .orderBy('createdAt', descending: true)
          .limit(page.limit + 1);
      final snapshots = await query.get();
      return CommunityPage(
        items:
            snapshots.docs.take(page.limit).map(_map).toList(growable: false),
        nextCursor: snapshots.docs.length > page.limit
            ? snapshots.docs[page.limit].id
            : null,
      );
    } catch (error) {
      throw _mapError(error, 'Unable to list appeals');
    }
  }

  @override
  Future<CommunityModerationAppeal> resolveAppeal({
    required String appealId,
    required CommunityModerationAppealResolution resolution,
    required String reviewerId,
    required String reviewReason,
    CommunityContentLifecycle? newLifecycle,
  }) async {
    try {
      final ref = _firestore.collection(_collection).doc(appealId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        if (!snapshot.exists) {
          throw const CommunityError(
              CommunityErrorCode.notFound, 'Appeal not found');
        }
        final current = _map(snapshot);
        if (current.status != CommunityModerationAppealStatus.underReview) {
          throw const CommunityError(
              CommunityErrorCode.conflict, 'Appeal is no longer reviewable');
        }
        if (current.createdBy == reviewerId) {
          throw const CommunityError(
              CommunityErrorCode.forbidden, 'Appeal author cannot review it');
        }
        final actionRef =
            _firestore.collection('community_moderation_actions').doc();
        final actionData = <String, Object?>{
          'actionId': actionRef.id,
          'communityId': current.communityId,
          'actorId': reviewerId,
          'actionType': CommunityModerationActionType.appealResolved.name,
          'targetType': current.targetType,
          'targetId': current.targetId,
          if (current.parentContentId != null)
            'parentContentId': current.parentContentId,
          if (current.reportId != null) 'reportId': current.reportId,
          'appealId': current.appealId,
          'reason': reviewReason,
          'createdAt': FieldValue.serverTimestamp(),
        };
        if (resolution != CommunityModerationAppealResolution.uphold &&
            current.targetType == 'content') {
          if (newLifecycle == null) {
            throw const CommunityError(
                CommunityErrorCode.invalidRequest,
                'A new lifecycle is required for overturn or modify');
          }
          final contentRef = _firestore
              .collection('community_contents')
              .doc(current.targetId);
          final contentSnapshot = await transaction.get(contentRef);
          if (!contentSnapshot.exists ||
              contentSnapshot.data()!['communityId'] != current.communityId) {
            throw const CommunityError(
                CommunityErrorCode.invalidRequest, 'Appeal target is invalid');
          }
          final previous = contentSnapshot.data()!['lifecycle'] ??
              CommunityContentLifecycle.active.name;
          if (previous == newLifecycle.name) {
            throw const CommunityError(
                CommunityErrorCode.invalidRequest, 'Lifecycle must change');
          }
          transaction.update(contentRef, {
            'lifecycle': newLifecycle.name,
            'lifecycleUpdatedBy': reviewerId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          actionData['previousLifecycle'] = previous;
          actionData['newLifecycle'] = newLifecycle.name;
          final lifecycleActionRef =
              _firestore.collection('community_moderation_actions').doc();
          transaction.set(lifecycleActionRef, {
            'actionId': lifecycleActionRef.id,
            'communityId': current.communityId,
            'actorId': reviewerId,
            'actionType':
                CommunityModerationActionType.lifecycleChanged.name,
            'targetType': 'content',
            'targetId': current.targetId,
            'appealId': current.appealId,
            'reason': resolution.name,
            'previousLifecycle': previous,
            'newLifecycle': newLifecycle.name,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        transaction.update(ref, {
          'status': resolution == CommunityModerationAppealResolution.uphold
              ? CommunityModerationAppealStatus.rejected.name
              : CommunityModerationAppealStatus.accepted.name,
          'resolution': resolution.name,
          'reviewedBy': reviewerId,
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewReason': reviewReason,
        });
        transaction.set(actionRef, actionData);
      });
      return _map(await ref.get());
    } catch (error) {
      throw _mapError(error, 'Unable to resolve appeal');
    }
  }

  CommunityModerationAppeal _map(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data =
        Map<String, dynamic>.from(snapshot.data() ?? <String, dynamic>{});
    data['appealId'] ??= snapshot.id;
    if (data['createdAt'] is Timestamp) {
      data['createdAt'] =
          (data['createdAt'] as Timestamp).toDate().toUtc().toIso8601String();
    }
    if (data['reviewedAt'] is Timestamp) {
      data['reviewedAt'] =
          (data['reviewedAt'] as Timestamp).toDate().toUtc().toIso8601String();
    }
    return CommunityModerationAppeal.fromMap(data);
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
