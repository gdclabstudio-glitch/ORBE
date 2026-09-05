import 'community_content.dart';

enum CommunityModerationActionType {
  reportCreated,
  reportResolved,
  lifecycleChanged,
  correctionRequested,
  appealCreated,
  appealResolved,
}

class CommunityModerationAction {
  CommunityModerationAction({
    required this.actionId,
    required this.communityId,
    required this.actorId,
    required this.actionType,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.createdAt,
    this.parentContentId,
    this.reportId,
    this.appealId,
    this.previousLifecycle,
    this.newLifecycle,
  }) {
    _requireText(actionId, 'actionId');
    _requireText(communityId, 'communityId');
    _requireText(actorId, 'actorId');
    _requireText(targetType, 'targetType');
    _requireText(targetId, 'targetId');
    _requireText(reason, 'reason');
    if (previousLifecycle != null) {
      _validateLifecycle(previousLifecycle!, 'previousLifecycle');
    }
    if (newLifecycle != null) {
      _validateLifecycle(newLifecycle!, 'newLifecycle');
    }
  }

  final String actionId;
  final String communityId;
  final String actorId;
  final CommunityModerationActionType actionType;
  final String targetType;
  final String targetId;
  final String? parentContentId;
  final String? reportId;
  final String? appealId;
  final String reason;
  final CommunityContentLifecycle? previousLifecycle;
  final CommunityContentLifecycle? newLifecycle;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'actionId': actionId,
        'communityId': communityId,
        'actorId': actorId,
        'actionType': actionType.name,
        'targetType': targetType,
        'targetId': targetId,
        if (parentContentId != null) 'parentContentId': parentContentId,
        if (reportId != null) 'reportId': reportId,
        if (appealId != null) 'appealId': appealId,
        'reason': reason,
        if (previousLifecycle != null)
          'previousLifecycle': previousLifecycle!.name,
        if (newLifecycle != null) 'newLifecycle': newLifecycle!.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory CommunityModerationAction.fromMap(Map<String, dynamic> map) {
    final rawActionType = _requiredString(map['actionType'], 'actionType');
    final actionType = CommunityModerationActionType.values.firstWhere(
      (value) => value.name == rawActionType,
      orElse: () => throw const FormatException('Invalid actionType'),
    );

    return CommunityModerationAction(
      actionId: _requiredString(map['actionId'], 'actionId'),
      communityId: _requiredString(map['communityId'], 'communityId'),
      actorId: _requiredString(map['actorId'], 'actorId'),
      actionType: actionType,
      targetType: _requiredString(map['targetType'], 'targetType'),
      targetId: _requiredString(map['targetId'], 'targetId'),
      parentContentId: _optionalString(map['parentContentId']),
      reportId: _optionalString(map['reportId']),
      appealId: _optionalString(map['appealId']),
      reason: _requiredString(map['reason'], 'reason'),
      previousLifecycle: map['previousLifecycle'] == null
          ? null
          : _parseLifecycle(map['previousLifecycle'], 'previousLifecycle'),
      newLifecycle: map['newLifecycle'] == null
          ? null
          : _parseLifecycle(map['newLifecycle'], 'newLifecycle'),
      createdAt: _dateTime(map['createdAt'], 'createdAt'),
    );
  }

  void _validateLifecycle(CommunityContentLifecycle lifecycle, String field) {
    if (lifecycle == CommunityContentLifecycle.active ||
        lifecycle == CommunityContentLifecycle.underReview ||
        lifecycle == CommunityContentLifecycle.restricted ||
        lifecycle == CommunityContentLifecycle.corrected ||
        lifecycle == CommunityContentLifecycle.archived) {
      return;
    }
    throw ArgumentError.value(lifecycle, field, 'Unsupported lifecycle');
  }

  static void _requireText(String value, String field) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, field, 'Cannot be empty');
    }
  }

  static String _requiredString(Object? value, String field) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    throw FormatException('Missing or invalid $field');
  }

  static String? _optionalString(Object? value) {
    if (value == null) return null;
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw FormatException('Invalid optional string value');
  }

  static CommunityContentLifecycle _parseLifecycle(
      Object? value, String field) {
    if (value is String) {
      for (final lifecycle in CommunityContentLifecycle.values) {
        if (lifecycle.name == value) return lifecycle;
      }
    }
    throw FormatException('Missing or invalid $field');
  }

  static DateTime _dateTime(Object? value, String field) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toUtc();
    }
    throw FormatException('Missing or invalid $field');
  }
}
