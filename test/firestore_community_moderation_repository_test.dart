import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/domain/content/community_content.dart';
import 'package:labomba_app/features/social/domain/content/community_moderation.dart';
import 'package:labomba_app/features/social/infrastructure/firestore_community_moderation_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreCommunityModerationRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreCommunityModerationRepository(firestore: firestore);
  });

  test('creates and lists an open community report', () async {
    final report = CommunityContentReport(
      reportId: 'science::alice::content::claim::spam',
      communityId: 'science',
      targetType: CommunityReportTargetType.content,
      targetId: 'claim',
      reason: CommunityReportReason.spam,
      reportedBy: 'alice',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    await repository.createReport(report: report);
    final page = await repository.listOpenReports(communityId: 'science');

    expect(page.items.single.reportId, report.reportId);
    expect(page.items.single.status, CommunityReportStatus.open);
  });

  test('updates lifecycle through the moderation repository', () async {
    await firestore.collection('community_contents').doc('claim').set({
      'contentId': 'claim',
      'communityId': 'science',
      'type': 'fact',
      'title': 'Claim',
      'body': 'Context',
      'createdBy': 'alice',
      'lifecycle': 'active',
      'createdAt': DateTime.utc(2026, 1, 1),
      'updatedAt': DateTime.utc(2026, 1, 1),
    });

    final updated = await repository.updateLifecycle(
      content: CommunityContent(
        contentId: 'claim',
        communityId: 'science',
        type: ContentType.fact,
        title: 'Claim',
        body: 'Context',
        createdBy: 'alice',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      lifecycle: CommunityContentLifecycle.restricted,
      reviewedBy: 'moderator',
    );

    expect(updated.lifecycle, CommunityContentLifecycle.restricted);
  });
}
