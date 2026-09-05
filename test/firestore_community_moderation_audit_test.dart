import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/domain/content/community_content.dart';
import 'package:labomba_app/features/social/domain/content/community_moderation.dart';
import 'package:labomba_app/features/social/domain/content/community_moderation_appeal.dart';
import 'package:labomba_app/features/social/infrastructure/firestore_community_moderation_appeal_repository.dart';
import 'package:labomba_app/features/social/infrastructure/firestore_community_moderation_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreCommunityModerationRepository reports;
  late FirestoreCommunityModerationAppealRepository appeals;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    reports = FirestoreCommunityModerationRepository(firestore: firestore);
    appeals = FirestoreCommunityModerationAppealRepository(firestore: firestore);
  });

  test('report resolution writes the report and reportResolved action together',
      () async {
    await firestore.collection('community_reports').doc('report-1').set({
      'reportId': 'report-1',
      'communityId': 'science',
      'targetType': 'content',
      'targetId': 'content-1',
      'reason': 'misinformation',
      'reportedBy': 'alice',
      'createdAt': DateTime.utc(2026, 1, 1),
      'status': 'open',
    });

    final report = CommunityContentReport(
      reportId: 'report-1',
      communityId: 'science',
      targetType: CommunityReportTargetType.content,
      targetId: 'content-1',
      reason: CommunityReportReason.misinformation,
      reportedBy: 'alice',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    await reports.resolveReport(
      report: report,
      resolution: CommunityReportResolution.noAction,
      reviewedBy: 'moderator',
    );

    final actionSnapshot = await firestore
        .collection('community_moderation_actions')
        .where('reportId', isEqualTo: 'report-1')
        .get();
    expect(actionSnapshot.docs, hasLength(1));
    expect(actionSnapshot.docs.single.data()['actionType'], 'reportResolved');
    expect(
      (await firestore.collection('community_reports').doc('report-1').get())
          .data()!['status'],
      'resolved',
    );
  });

  test('appeal creation, review, and resolution write audit actions', () async {
    await firestore.collection('community_contents').doc('content-1').set({
      'contentId': 'content-1',
      'communityId': 'science',
      'type': 'fact',
      'title': 'Claim',
      'body': 'Context',
      'createdBy': 'alice',
      'lifecycle': 'restricted',
      'createdAt': DateTime.utc(2026, 1, 1),
      'updatedAt': DateTime.utc(2026, 1, 1),
    });
    final appeal = CommunityModerationAppeal(
      appealId: 'science::alice::content::content-1',
      communityId: 'science',
      targetType: 'content',
      targetId: 'content-1',
      createdBy: 'alice',
      createdAt: DateTime.utc(2026, 1, 2),
      reason: 'Please review',
      status: CommunityModerationAppealStatus.open,
    );

    await appeals.createAppeal(appeal: appeal);
    await appeals.beginAppealReview(
      appealId: appeal.appealId,
      reviewerId: 'moderator',
    );
    final resolved = await appeals.resolveAppeal(
      appealId: appeal.appealId,
      resolution: CommunityModerationAppealResolution.overturn,
      reviewerId: 'moderator',
      reviewReason: 'The restriction was not applicable',
      newLifecycle: CommunityContentLifecycle.active,
    );

    expect(resolved.status, CommunityModerationAppealStatus.accepted);
    final actions = await firestore
        .collection('community_moderation_actions')
        .where('appealId', isEqualTo: appeal.appealId)
        .get();
    expect(actions.docs, hasLength(3));
    expect(
      actions.docs.map((doc) => doc.data()['actionType']).toSet(),
      containsAll(<String>['appealCreated', 'appealResolved', 'lifecycleChanged']),
    );
    expect(
      (await firestore.collection('community_contents').doc('content-1').get())
          .data()!['lifecycle'],
      'active',
    );
  });

}
