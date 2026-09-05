import 'package:cloud_firestore/cloud_firestore.dart';

class ModerationReport {
  final String id;
  final String contentType;
  final String contentId;
  final String reason;
  final String reporterId;
  final DateTime createdAt;
  final String status;

  const ModerationReport({
    required this.id,
    required this.contentType,
    required this.contentId,
    required this.reason,
    required this.reporterId,
    required this.createdAt,
    required this.status,
  });

  factory ModerationReport.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final timestamp = data['createdAt'];
    return ModerationReport(
      id: document.id,
      contentType: data['contentType'] as String? ?? 'memory',
      contentId: data['contentId'] as String? ?? '',
      reason: data['reason'] as String? ?? 'Sem motivo informado',
      reporterId: data['reporterId'] as String? ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      status: data['status'] as String? ?? 'open',
    );
  }
}

class ModerationService {
  final FirebaseFirestore _firestore;

  ModerationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<ModerationReport>> openReportsStream() {
    return _firestore
        .collection('moderation_reports')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ModerationReport.fromDocument)
              .toList(growable: false),
        );
  }

  Future<void> reportMemory({
    required String memoryId,
    required String reporterId,
    required String reason,
  }) async {
    await _firestore.collection('moderation_reports').add({
      'contentType': 'memory',
      'contentId': memoryId,
      'reporterId': reporterId,
      'reason': reason.trim(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> hideMemory({
    required String memoryId,
    required String reportId,
    required String moderatorId,
  }) async {
    await _firestore.collection('memories').doc(memoryId).set({
      'isHidden': true,
      'hiddenAt': FieldValue.serverTimestamp(),
      'hiddenBy': moderatorId,
    }, SetOptions(merge: true));
    await resolveReport(
      reportId: reportId,
      moderatorId: moderatorId,
      resolution: 'hidden',
    );
  }

  Future<void> resolveReport({
    required String reportId,
    required String moderatorId,
    required String resolution,
  }) async {
    await _firestore.collection('moderation_reports').doc(reportId).set({
      'status': 'resolved',
      'resolution': resolution,
      'resolvedBy': moderatorId,
      'resolvedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
