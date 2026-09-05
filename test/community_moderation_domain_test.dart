import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/domain/content/community_content.dart';
import 'package:labomba_app/features/social/domain/content/community_moderation.dart';
import 'package:labomba_app/features/social/domain/content/community_moderation_action.dart';
import 'package:labomba_app/features/social/domain/content/community_moderation_appeal.dart';

void main() {
  test('serializes report lifecycle without truth semantics', () {
    final report = CommunityContentReport(
      reportId: 'science::alice::content::claim-1::misinformation',
      communityId: 'science',
      targetType: CommunityReportTargetType.content,
      targetId: 'claim-1',
      reason: CommunityReportReason.misinformation,
      description: 'Needs review',
      reportedBy: 'alice',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final restored = CommunityContentReport.fromMap(report.toMap());

    expect(restored.status, CommunityReportStatus.open);
    expect(restored.resolution, isNull);
    expect(restored.targetType, CommunityReportTargetType.content);
  });

  test('lifecycle is independent from content type and defaults active', () {
    final content = CommunityContent(
      contentId: 'claim-1',
      communityId: 'science',
      type: ContentType.fact,
      title: 'Claim',
      body: 'Context',
      createdBy: 'alice',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

    expect(content.lifecycle, CommunityContentLifecycle.active);
    expect(
      CommunityContent.fromMap(content.toMap()).lifecycle,
      CommunityContentLifecycle.active,
    );
  });

  test('creates a moderation action with lifecycle history data', () {
    final action = CommunityModerationAction(
      actionId: 'science::action-1',
      communityId: 'science',
      actorId: 'moderator-1',
      actionType: CommunityModerationActionType.lifecycleChanged,
      targetType: 'content',
      targetId: 'claim-1',
      reason: 'policyViolation',
      previousLifecycle: CommunityContentLifecycle.active,
      newLifecycle: CommunityContentLifecycle.restricted,
      createdAt: DateTime.utc(2026, 2, 3),
    );

    expect(action.actionType, CommunityModerationActionType.lifecycleChanged);
    expect(action.previousLifecycle, CommunityContentLifecycle.active);
    expect(action.newLifecycle, CommunityContentLifecycle.restricted);
    expect(action.toMap()['targetType'], 'content');
  });

  test('creates an appeal with a clear review status and payload', () {
    final appeal = CommunityModerationAppeal(
      appealId: 'science::appeal-1',
      communityId: 'science',
      targetType: 'content',
      targetId: 'claim-1',
      originalActionId: 'science::action-1',
      reportId: 'science::alice::content::claim-1::misinformation',
      createdBy: 'alice',
      createdAt: DateTime.utc(2026, 2, 4),
      reason: 'I want this action reviewed',
      status: CommunityModerationAppealStatus.open,
    );

    expect(appeal.status, CommunityModerationAppealStatus.open);
    expect(appeal.originalActionId, 'science::action-1');
    expect(appeal.toMap()['communityId'], 'science');
  });
}
