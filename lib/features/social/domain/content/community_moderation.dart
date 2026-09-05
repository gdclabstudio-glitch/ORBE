import '../community/community_pagination.dart';
import 'community_content.dart';

enum CommunityReportTargetType { content, evidence, source, correction }

enum CommunityReportReason {
  misinformation,
  fabricatedEvidence,
  misleadingSource,
  harassment,
  spam,
  offTopic,
  other
}

enum CommunityReportStatus { open, underReview, resolved }

enum CommunityReportResolution {
  noAction,
  warning,
  restrictContent,
  archiveContent,
  requestCorrection,
  dismissReport
}

typedef ReportTargetType = CommunityReportTargetType;
typedef ReportReason = CommunityReportReason;
typedef ReportStatus = CommunityReportStatus;
typedef ReportResolution = CommunityReportResolution;

class CommunityContentReport {
  CommunityContentReport({
    required this.reportId,
    required this.communityId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.reportedBy,
    required this.createdAt,
    String? parentContentId,
    String? targetContentId,
    this.description,
    this.status = CommunityReportStatus.open,
    this.reviewedBy,
    this.reviewedAt,
    this.resolution,
  }) : parentContentId = parentContentId ?? targetContentId {
    _required(reportId, 'reportId');
    _required(communityId, 'communityId');
    _required(targetId, 'targetId');
    _required(reportedBy, 'reportedBy');
    if (reviewedBy != null) _required(reviewedBy!, 'reviewedBy');
  }

  final String reportId;
  final String communityId;
  final CommunityReportTargetType targetType;
  final String targetId;
  final String? parentContentId;
  String? get targetContentId => parentContentId;
  final CommunityReportReason reason;
  final String? description;
  final String reportedBy;
  final DateTime createdAt;
  final CommunityReportStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final CommunityReportResolution? resolution;

  Map<String, Object?> toMap() => {
        'reportId': reportId,
        'communityId': communityId,
        'targetType': targetType.name,
        'targetId': targetId,
        if (parentContentId != null) 'parentContentId': parentContentId,
        'reason': reason.name,
        if (description != null) 'description': description,
        'reportedBy': reportedBy,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'status': status.name,
        if (reviewedBy != null) 'reviewedBy': reviewedBy,
        if (reviewedAt != null)
          'reviewedAt': reviewedAt!.toUtc().toIso8601String(),
        if (resolution != null) 'resolution': resolution!.name,
      };

  factory CommunityContentReport.fromMap(Map<String, dynamic> map) =>
      CommunityContentReport(
        reportId: _string(map['reportId'], 'reportId'),
        communityId: _string(map['communityId'], 'communityId'),
        targetType: _enum(
            CommunityReportTargetType.values, map['targetType'], 'targetType'),
        targetId: _string(map['targetId'], 'targetId'),
        parentContentId: map['parentContentId'] as String?,
        reason: _enum(CommunityReportReason.values, map['reason'], 'reason'),
        description: map['description'] as String?,
        reportedBy: _string(map['reportedBy'], 'reportedBy'),
        createdAt: _date(map['createdAt'], 'createdAt'),
        status: _enum(CommunityReportStatus.values, map['status'], 'status'),
        reviewedBy: map['reviewedBy'] as String?,
        reviewedAt: map['reviewedAt'] == null
            ? null
            : _date(map['reviewedAt'], 'reviewedAt'),
        resolution: map['resolution'] == null
            ? null
            : _enum(CommunityReportResolution.values, map['resolution'],
                'resolution'),
      );
}

abstract class CommunityModerationRepository {
  Future<CommunityContentReport> createReport(
      {required CommunityContentReport report});
  Future<CommunityPage<CommunityContentReport>> listOpenReports(
      {required String communityId,
      CommunityPageRequest page = const CommunityPageRequest()});
  Future<CommunityContentReport> resolveReport(
      {required CommunityContentReport report,
      required CommunityReportResolution resolution,
      required String reviewedBy});
  Future<CommunityContent> updateLifecycle(
      {required CommunityContent content,
      required CommunityContentLifecycle lifecycle,
      required String reviewedBy});

  Future<CommunityContent> updateLifecycleById({
    required String contentId,
    required CommunityContentLifecycle lifecycle,
    required String updatedBy,
    String? reason,
  });
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
    final date = DateTime.tryParse(value);
    if (date != null) return date.toUtc();
  }
  throw FormatException('Missing or invalid $field');
}
