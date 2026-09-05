enum CommunityModerationAppealStatus {
  open,
  underReview,
  accepted,
  rejected,
  withdrawn,
}

enum CommunityModerationAppealResolution {
  uphold,
  overturn,
  modify,
}

class CommunityModerationAppeal {
  CommunityModerationAppeal({
    required this.appealId,
    required this.communityId,
    required this.targetType,
    required this.targetId,
    required this.createdBy,
    required this.createdAt,
    required this.reason,
    required this.status,
    this.parentContentId,
    this.originalActionId,
    this.reportId,
    this.resolution,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewReason,
  }) {
    _requireText(appealId, 'appealId');
    _requireText(communityId, 'communityId');
    _requireText(targetType, 'targetType');
    _requireText(targetId, 'targetId');
    _requireText(createdBy, 'createdBy');
    _requireText(reason, 'reason');
    if (parentContentId != null)
      _requireText(parentContentId!, 'parentContentId');
    if (originalActionId != null)
      _requireText(originalActionId!, 'originalActionId');
    if (reportId != null) _requireText(reportId!, 'reportId');
    if (reviewedBy != null) _requireText(reviewedBy!, 'reviewedBy');
    if (reviewReason != null) _requireText(reviewReason!, 'reviewReason');
  }

  final String appealId;
  final String communityId;
  final String targetType;
  final String targetId;
  final String? parentContentId;
  final String? originalActionId;
  final String? reportId;
  final String createdBy;
  final DateTime createdAt;
  final String reason;
  final CommunityModerationAppealStatus status;
  final CommunityModerationAppealResolution? resolution;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewReason;

  Map<String, Object?> toMap() => {
        'appealId': appealId,
        'communityId': communityId,
        'targetType': targetType,
        'targetId': targetId,
        if (parentContentId != null) 'parentContentId': parentContentId,
        if (originalActionId != null) 'originalActionId': originalActionId,
        if (reportId != null) 'reportId': reportId,
        'createdBy': createdBy,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'reason': reason,
        'status': status.name,
        if (resolution != null) 'resolution': resolution!.name,
        if (reviewedBy != null) 'reviewedBy': reviewedBy,
        if (reviewedAt != null)
          'reviewedAt': reviewedAt!.toUtc().toIso8601String(),
        if (reviewReason != null) 'reviewReason': reviewReason,
      };

  factory CommunityModerationAppeal.fromMap(Map<String, dynamic> map) {
    return CommunityModerationAppeal(
      appealId: _requiredString(map['appealId'], 'appealId'),
      communityId: _requiredString(map['communityId'], 'communityId'),
      targetType: _requiredString(map['targetType'], 'targetType'),
      targetId: _requiredString(map['targetId'], 'targetId'),
      parentContentId: _optionalString(map['parentContentId']),
      originalActionId: _optionalString(map['originalActionId']),
      reportId: _optionalString(map['reportId']),
      createdBy: _requiredString(map['createdBy'], 'createdBy'),
      createdAt: _dateTime(map['createdAt'], 'createdAt'),
      reason: _requiredString(map['reason'], 'reason'),
      status: _enumValue(
          CommunityModerationAppealStatus.values, map['status'], 'status'),
      resolution: map['resolution'] == null
          ? null
          : _enumValue(CommunityModerationAppealResolution.values,
              map['resolution'], 'resolution'),
      reviewedBy: _optionalString(map['reviewedBy']),
      reviewedAt: map['reviewedAt'] == null
          ? null
          : _dateTime(map['reviewedAt'], 'reviewedAt'),
      reviewReason: _optionalString(map['reviewReason']),
    );
  }

  static void _requireText(String value, String field) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, field, 'Cannot be empty');
    }
  }

  static String _requiredString(Object? value, String field) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw FormatException('Missing or invalid $field');
  }

  static String? _optionalString(Object? value) {
    if (value == null) return null;
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw FormatException('Invalid optional string value');
  }

  static T _enumValue<T extends Enum>(
      List<T> values, Object? value, String field) {
    if (value is String) {
      for (final item in values) {
        if (item.name == value) return item;
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
