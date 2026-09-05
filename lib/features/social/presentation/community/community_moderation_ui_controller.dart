import 'package:flutter/foundation.dart';

import '../../domain/community/community_errors.dart';
import '../../domain/community/community_pagination.dart';
import '../../domain/content/community_content.dart';
import '../../domain/content/community_moderation.dart';
import '../../domain/content/community_moderation_repository.dart';

class CommunityModerationUiController extends ChangeNotifier {
  CommunityModerationUiController({
    required CommunityModerationRepository repository,
    required this.userId,
  }) : _repository = repository;

  final CommunityModerationRepository _repository;
  final String? userId;
  final Map<String, List<CommunityContentReport>> _reports = {};
  final Map<String, String?> _cursors = {};
  final Map<String, CommunityError?> _errors = {};
  final Set<String> _loading = {};
  final Set<String> _submitting = {};
  bool _disposed = false;

  List<CommunityContentReport> reportsFor(String communityId) =>
      List.unmodifiable(_reports[communityId] ?? const []);

  CommunityError? errorFor(String communityId) => _errors[communityId];
  bool isLoading(String communityId) => _loading.contains(communityId);
  bool hasMore(String communityId) => _cursors[communityId] != null;
  bool isSubmitting(String operation) => _submitting.contains(operation);

  Future<void> loadReports(String communityId, {bool refresh = true}) async {
    if (_loading.contains(communityId)) return;
    if (refresh) {
      _reports[communityId] = [];
      _cursors[communityId] = null;
    }
    _loading.add(communityId);
    _errors.remove(communityId);
    _notify();
    try {
      final page = await _repository.listOpenReports(
        communityId: communityId,
        page: CommunityPageRequest(cursor: _cursors[communityId]),
      );
      _reports[communityId] = [
        ...(_reports[communityId] ?? const []),
        ...page.items,
      ];
      _cursors[communityId] = page.nextCursor;
    } catch (error) {
      _errors[communityId] = _asError(error);
    } finally {
      _loading.remove(communityId);
      _notify();
    }
  }

  Future<CommunityContentReport?> createReport({
    required String communityId,
    required ReportTargetType targetType,
    required String targetId,
    String? targetContentId,
    required ReportReason reason,
    String? description,
    String? parentContentId,
  }) async {
    final reporter = _requireUser();
    final operation = '$communityId:$targetType:$targetId:$reason';
    if (!_submitting.add(operation)) return null;
    _notify();
    try {
      final report = CommunityContentReport(
        reportId: '$reporter::$communityId::$targetType::$targetId::$reason',
        communityId: communityId,
        targetType: targetType,
        targetId: targetId,
        targetContentId: targetContentId ?? parentContentId,
        reason: reason,
        description: description?.trim(),
        reportedBy: reporter,
        createdAt: DateTime.now().toUtc(),
      );
      return await _repository.createReport(report: report);
    } finally {
      _submitting.remove(operation);
      _notify();
    }
  }

  Future<CommunityContentReport> resolveReport({
    required CommunityContentReport report,
    required ReportStatus status,
    required ReportResolution resolution,
  }) async {
    final reviewer = _requireUser();
    final operation = 'resolve:${report.reportId}';
    if (!_submitting.add(operation)) throw StateError('Report is submitting');
    _notify();
    try {
      final updated = await _repository.resolveReport(
        report: report,
        resolution: resolution,
        reviewedBy: reviewer,
      );
      if (report.targetType == ReportTargetType.content &&
          (resolution == ReportResolution.restrictContent ||
              resolution == ReportResolution.archiveContent ||
              resolution == ReportResolution.requestCorrection)) {
        final lifecycle = resolution == ReportResolution.restrictContent
            ? CommunityContentLifecycle.restricted
            : resolution == ReportResolution.archiveContent
                ? CommunityContentLifecycle.archived
                : CommunityContentLifecycle.corrected;
        await _repository.updateLifecycleById(
          contentId: report.targetId,
          lifecycle: lifecycle,
          updatedBy: reviewer,
          reason: resolution.name,
        );
      }
      _reports.update(report.communityId, (items) {
        return items
            .map((item) => item.reportId == updated.reportId ? updated : item)
            .toList();
      });
      return updated;
    } finally {
      _submitting.remove(operation);
      _notify();
    }
  }

  Future<CommunityContent> updateLifecycle({
    required String contentId,
    required CommunityContentLifecycle lifecycle,
    required String reason,
  }) async {
    final reviewer = _requireUser();
    return _repository.updateLifecycleById(
      contentId: contentId,
      lifecycle: lifecycle,
      updatedBy: reviewer,
      reason: reason.trim(),
    );
  }

  String _requireUser() {
    final value = userId?.trim();
    if (value == null || value.isEmpty) {
      throw const CommunityError(
        CommunityErrorCode.unauthorized,
        'Authentication required',
      );
    }
    return value;
  }

  CommunityError _asError(Object error) => error is CommunityError
      ? error
      : const CommunityError(
          CommunityErrorCode.unknown,
          'Unexpected moderation error',
        );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
