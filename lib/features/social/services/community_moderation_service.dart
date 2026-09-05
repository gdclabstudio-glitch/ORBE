import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/community/community_errors.dart';
import '../domain/content/community_content.dart';
import '../domain/content/community_moderation_action.dart';
import '../domain/content/community_moderation_appeal.dart';

class CommunityModerationService {
  CommunityModerationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> changeLifecycleWithHistory({
    required String communityId,
    required String targetId,
    required CommunityContentLifecycle expectedLifecycle,
    required CommunityContentLifecycle newLifecycle,
    required String reason,
    String? reportId,
    String? appealId,
  }) async {
    final actorId = _auth.currentUser?.uid;
    if (actorId == null) {
      throw const CommunityError(
          CommunityErrorCode.unauthorized, 'Authentication required');
    }
    if (expectedLifecycle == newLifecycle ||
        !_validTransition(expectedLifecycle, newLifecycle)) {
      throw const CommunityError(
          CommunityErrorCode.invalidRequest, 'Invalid lifecycle transition');
    }

    final contentRef = _firestore.collection('community_contents').doc(targetId);
    final actionRef =
        _firestore.collection('community_moderation_actions').doc();
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(contentRef);
      if (!snapshot.exists) {
        throw const CommunityError(
            CommunityErrorCode.notFound, 'Content not found');
      }
      final data = snapshot.data()!;
      if (data['communityId'] != communityId ||
          (data['lifecycle'] ?? CommunityContentLifecycle.active.name) !=
              expectedLifecycle.name) {
        throw const CommunityError(
            CommunityErrorCode.conflict, 'Content lifecycle has changed');
      }
      final action = CommunityModerationAction(
        actionId: actionRef.id,
        communityId: communityId,
        actorId: actorId,
        actionType: CommunityModerationActionType.lifecycleChanged,
        targetType: 'content',
        targetId: targetId,
        reportId: reportId,
        appealId: appealId,
        reason: reason,
        previousLifecycle: expectedLifecycle,
        newLifecycle: newLifecycle,
        createdAt: DateTime.now().toUtc(),
      );
      transaction.update(contentRef, {
        'lifecycle': newLifecycle.name,
        'lifecycleUpdatedBy': actorId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(actionRef, {
        ...action.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> recordLifecycleChange({
    required String communityId,
    required String actorId,
    required String targetId,
    required CommunityContentLifecycle previousLifecycle,
    required CommunityContentLifecycle newLifecycle,
    required String reason,
    String? reportId,
    String? appealId,
  }) async {
    if (_auth.currentUser?.uid != actorId) {
      throw const CommunityError(
          CommunityErrorCode.forbidden, 'Actor must match authenticated user');
    }
    final action = CommunityModerationAction(
      actionId:
          '${communityId}::${DateTime.now().toUtc().microsecondsSinceEpoch}',
      communityId: communityId,
      actorId: actorId,
      actionType: CommunityModerationActionType.lifecycleChanged,
      targetType: 'content',
      targetId: targetId,
      reportId: reportId,
      appealId: appealId,
      reason: reason,
      previousLifecycle: previousLifecycle,
      newLifecycle: newLifecycle,
      createdAt: DateTime.now().toUtc(),
    );

    await _firestore
        .collection('community_moderation_actions')
        .doc(action.actionId)
        .set(action.toMap());
  }

  Future<void> recordAppealResolution({
    required String communityId,
    required String actorId,
    required String appealId,
    required CommunityModerationAppealResolution resolution,
    required String reason,
  }) async {
    if (_auth.currentUser?.uid != actorId) {
      throw const CommunityError(
          CommunityErrorCode.forbidden, 'Actor must match authenticated user');
    }
    final action = CommunityModerationAction(
      actionId:
          '${communityId}::appeal::${DateTime.now().toUtc().microsecondsSinceEpoch}',
      communityId: communityId,
      actorId: actorId,
      actionType: CommunityModerationActionType.appealResolved,
      targetType: 'appeal',
      targetId: appealId,
      reason: reason,
      createdAt: DateTime.now().toUtc(),
      appealId: appealId,
    );

    await _firestore
        .collection('community_moderation_actions')
        .doc(action.actionId)
        .set(action.toMap());
  }

  bool _validTransition(
      CommunityContentLifecycle previous, CommunityContentLifecycle next) {
    switch (previous) {
      case CommunityContentLifecycle.active:
        return next == CommunityContentLifecycle.underReview ||
            next == CommunityContentLifecycle.restricted ||
            next == CommunityContentLifecycle.archived;
      case CommunityContentLifecycle.underReview:
        return next == CommunityContentLifecycle.active ||
            next == CommunityContentLifecycle.restricted ||
            next == CommunityContentLifecycle.corrected ||
            next == CommunityContentLifecycle.archived;
      case CommunityContentLifecycle.restricted:
        return next == CommunityContentLifecycle.active ||
            next == CommunityContentLifecycle.corrected ||
            next == CommunityContentLifecycle.archived;
      case CommunityContentLifecycle.corrected:
        return next == CommunityContentLifecycle.active ||
            next == CommunityContentLifecycle.archived;
      case CommunityContentLifecycle.archived:
        return next == CommunityContentLifecycle.archived;
    }
  }
}
