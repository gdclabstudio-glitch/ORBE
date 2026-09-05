import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/community/community_errors.dart';
import '../domain/community/community_pagination.dart';
import '../domain/content/community_content.dart';
import '../domain/content/community_moderation.dart';
import '../domain/content/community_moderation_action.dart';
import '../domain/content/community_moderation_repository.dart';

class FirestoreCommunityModerationRepository
    implements CommunityModerationRepository {
  FirestoreCommunityModerationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<CommunityContentReport> createReport({
    required CommunityContentReport report,
  }) async {
    final ref = _firestore.collection('community_reports').doc(report.reportId);
    await ref.set({...report.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    return _mapReport(await ref.get());
  }

  @override
  Future<CommunityPage<CommunityContentReport>> listOpenReports({
    required String communityId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) async {
    final snapshot = await _firestore
        .collection('community_reports')
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: CommunityReportStatus.open.name)
        .limit(page.limit + 1)
        .get();
    return CommunityPage(
      items: snapshot.docs.take(page.limit).map(_mapReport).toList(growable: false),
      nextCursor: snapshot.docs.length > page.limit
          ? snapshot.docs[page.limit].id
          : null,
    );
  }

  Future<CommunityPage<CommunityContentReport>> listReports({
    required String communityId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) =>
      listOpenReports(communityId: communityId, page: page);

  @override
  Future<CommunityContentReport> resolveReport({
    required CommunityContentReport report,
    required CommunityReportResolution resolution,
    required String reviewedBy,
  }) async {
    final reportRef =
        _firestore.collection('community_reports').doc(report.reportId);
    final actionRef =
        _firestore.collection('community_moderation_actions').doc();
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reportRef);
      if (!snapshot.exists ||
          snapshot.data()!['status'] != CommunityReportStatus.open.name) {
        throw const CommunityError(
            CommunityErrorCode.conflict, 'Report is no longer open');
      }
      transaction.update(reportRef, {
        'status': CommunityReportStatus.resolved.name,
        'reviewedBy': reviewedBy,
        'reviewedAt': FieldValue.serverTimestamp(),
        'resolution': resolution.name,
      });
      transaction.set(actionRef, {
        'actionId': actionRef.id,
        'communityId': snapshot.data()!['communityId'],
        'actorId': reviewedBy,
        'actionType': CommunityModerationActionType.reportResolved.name,
        'targetType': snapshot.data()!['targetType'],
        'targetId': snapshot.data()!['targetId'],
        'reportId': report.reportId,
        'reason': resolution.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return _mapReport(await reportRef.get());
  }

  Future<CommunityContentReport> updateReport({
    required CommunityContentReport report,
  }) =>
      resolveReport(
        report: report,
        resolution: report.resolution!,
        reviewedBy: report.reviewedBy!,
      );

  @override
  Future<CommunityContent> updateLifecycle({
    required CommunityContent content,
    required CommunityContentLifecycle lifecycle,
    required String reviewedBy,
    String? reason,
  }) async {
    final contentRef =
        _firestore.collection('community_contents').doc(content.contentId);
    final actionRef =
        _firestore.collection('community_moderation_actions').doc();
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(contentRef);
      final previous = snapshot.data()?['lifecycle'] ??
          CommunityContentLifecycle.active.name;
      transaction.update(contentRef, {
        'lifecycle': lifecycle.name,
        'lifecycleUpdatedBy': reviewedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(actionRef, {
        'actionId': actionRef.id,
        'communityId': content.communityId,
        'actorId': reviewedBy,
        'actionType': CommunityModerationActionType.lifecycleChanged.name,
        'targetType': 'content',
        'targetId': content.contentId,
        'previousLifecycle': previous,
        'newLifecycle': lifecycle.name,
        'reason': reason ?? lifecycle.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return CommunityContent.fromMap({
      ...content.toMap(),
      'lifecycle': lifecycle.name,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<CommunityContent> updateLifecycleById({
    required String contentId,
    required CommunityContentLifecycle lifecycle,
    required String updatedBy,
    String? reason,
  }) async {
    final snapshot =
        await _firestore.collection('community_contents').doc(contentId).get();
    if (!snapshot.exists) {
      throw const CommunityError(
          CommunityErrorCode.notFound, 'Content not found');
    }
    final data = snapshot.data()!;
    return updateLifecycle(
      content: CommunityContent.fromMap({
        ...data,
        'contentId': contentId,
        'createdAt': _isoDate(data['createdAt']),
        'updatedAt': _isoDate(data['updatedAt']),
      }),
      lifecycle: lifecycle,
      reviewedBy: updatedBy,
      reason: reason,
    );
  }

  CommunityContentReport _mapReport(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = Map<String, dynamic>.from(snapshot.data()!);
    data['reportId'] ??= snapshot.id;
    for (final field in ['createdAt', 'reviewedAt']) {
      if (data[field] is Timestamp) {
        data[field] =
            (data[field] as Timestamp).toDate().toUtc().toIso8601String();
      }
    }
    return CommunityContentReport.fromMap(data);
  }

  String _isoDate(Object? value) => value is Timestamp
      ? value.toDate().toUtc().toIso8601String()
      : value as String;
}
