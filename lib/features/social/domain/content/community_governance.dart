import '../community/community_pagination.dart';
import 'community_content.dart';
import 'community_moderation.dart';

enum CommunityModerationActionType {
  reportCreated,
  reportResolved,
  lifecycleChanged,
  appealCreated,
  appealResolved,
}

enum CommunityAppealStatus { open, underReview, accepted, rejected, withdrawn }

enum CommunityAppealResolution { uphold, overturn, modify }

class CommunityModerationAction {
  CommunityModerationAction({
    required this.actionId,
    required this.communityId,
    required this.actorId,
    required this.actionType,
    required this.targetType,
    required this.targetId,
    required this.createdAt,
    required this.reason,
    this.previousLifecycle,
    this.newLifecycle,
    this.originalActionId,
  }) {
    _required(actionId, 'actionId');
    _required(communityId, 'communityId');
    _required(actorId, 'actorId');
    _required(targetId, 'targetId');
    _required(reason, 'reason');
  }

  final String actionId;
  final String communityId;
  final String actorId;
  final CommunityModerationActionType actionType;
  final CommunityReportTargetType targetType;
  final String targetId;
  final String reason;
  final DateTime createdAt;
  final CommunityContentLifecycle? previousLifecycle;
  final CommunityContentLifecycle? newLifecycle;
  final String? originalActionId;

  Map<String, Object?> toMap() => {
        'actionId': actionId,
        'communityId': communityId,
        'actorId': actorId,
        'actionType': actionType.name,
        'targetType': targetType.name,
        'targetId': targetId,
        'reason': reason,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (previousLifecycle != null)
          'previousLifecycle': previousLifecycle!.name,
        if (newLifecycle != null) 'newLifecycle': newLifecycle!.name,
        if (originalActionId != null) 'originalActionId': originalActionId,
      };

  factory CommunityModerationAction.fromMap(Map<String, dynamic> map) =>
      CommunityModerationAction(
        actionId: _string(map['actionId'], 'actionId'),
        communityId: _string(map['communityId'], 'communityId'),
        actorId: _string(map['actorId'], 'actorId'),
        actionType: _enum(CommunityModerationActionType.values,
            map['actionType'], 'actionType'),
        targetType: _enum(
            CommunityReportTargetType.values, map['targetType'], 'targetType'),
        targetId: _string(map['targetId'], 'targetId'),
        reason: _string(map['reason'], 'reason'),
        createdAt: _date(map['createdAt'], 'createdAt'),
        previousLifecycle: map['previousLifecycle'] == null
            ? null
            : _enum(CommunityContentLifecycle.values, map['previousLifecycle'],
                'previousLifecycle'),
        newLifecycle: map['newLifecycle'] == null
            ? null
            : _enum(CommunityContentLifecycle.values, map['newLifecycle'],
                'newLifecycle'),
        originalActionId: map['originalActionId'] as String?,
      );
}

class CommunityModerationAppeal {
  CommunityModerationAppeal({
    required this.appealId,
    required this.communityId,
    required this.targetType,
    required this.targetId,
    required this.affectedUserId,
    required this.createdBy,
    required this.createdAt,
    required this.originalActionId,
    required this.reason,
    this.status = CommunityAppealStatus.open,
    this.reviewedBy,
    this.reviewedAt,
    this.resolution,
  }) {
    for (final entry in <String, String>{
      'appealId': appealId,
      'communityId': communityId,
      'targetId': targetId,
      'affectedUserId': affectedUserId,
      'createdBy': createdBy,
      'originalActionId': originalActionId,
      'reason': reason,
    }.entries) {
      _required(entry.value, entry.key);
    }
  }

  final String appealId;
  final String communityId;
  final CommunityReportTargetType targetType;
  final String targetId;
  final String affectedUserId;
  final String createdBy;
  final DateTime createdAt;
  final String originalActionId;
  final String reason;
  final CommunityAppealStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final CommunityAppealResolution? resolution;

  factory CommunityModerationAppeal.fromMap(Map<String, dynamic> map) =>
      CommunityModerationAppeal(
        appealId: _string(map['appealId'], 'appealId'),
        communityId: _string(map['communityId'], 'communityId'),
        targetType: _enum(
            CommunityReportTargetType.values, map['targetType'], 'targetType'),
        targetId: _string(map['targetId'], 'targetId'),
        affectedUserId: _string(map['affectedUserId'], 'affectedUserId'),
        createdBy: _string(map['createdBy'], 'createdBy'),
        createdAt: _date(map['createdAt'], 'createdAt'),
        originalActionId: _string(map['originalActionId'], 'originalActionId'),
        reason: _string(map['reason'], 'reason'),
        status: _enum(CommunityAppealStatus.values, map['status'], 'status'),
        reviewedBy: map['reviewedBy'] as String?,
        reviewedAt: map['reviewedAt'] == null
            ? null
            : _date(map['reviewedAt'], 'reviewedAt'),
        resolution: map['resolution'] == null
            ? null
            : _enum(CommunityAppealResolution.values, map['resolution'],
                'resolution'),
      );

  Map<String, Object?> toMap() => {
        'appealId': appealId,
        'communityId': communityId,
        'targetType': targetType.name,
        'targetId': targetId,
        'affectedUserId': affectedUserId,
        'createdBy': createdBy,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'originalActionId': originalActionId,
        'reason': reason,
        'status': status.name,
        if (reviewedBy != null) 'reviewedBy': reviewedBy,
        if (reviewedAt != null)
          'reviewedAt': reviewedAt!.toUtc().toIso8601String(),
        if (resolution != null) 'resolution': resolution!.name,
      };
}

abstract class CommunityGovernanceRepository {
  Future<CommunityModerationAppeal> createAppeal(
      {required CommunityModerationAppeal appeal});
  Future<CommunityPage<CommunityModerationAppeal>> listAppeals(
      {required String communityId,
      CommunityPageRequest page = const CommunityPageRequest()});
  Future<CommunityModerationAppeal> resolveAppeal(
      {required CommunityModerationAppeal appeal,
      required CommunityAppealResolution resolution,
      required String reviewerId,
      required String reason});
  Future<CommunityPage<CommunityModerationAction>> listAuditActions(
      {required String communityId,
      CommunityPageRequest page = const CommunityPageRequest()});
}

void _required(String value, String field) {
  if (value.trim().isEmpty)
    throw ArgumentError.value(value, field, 'Cannot be empty');
}

String _string(Object? value, String field) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('Missing or invalid $field');
}

T _enum<T extends Enum>(List<T> values, Object? value, String field) {
  if (value is String)
    for (final item in values) if (item.name == value) return item;
  throw FormatException('Missing or invalid $field');
}

DateTime _date(Object? value, String field) {
  if (value is String) {
    final result = DateTime.tryParse(value);
    if (result != null) return result.toUtc();
  }
  throw FormatException('Missing or invalid $field');
}
