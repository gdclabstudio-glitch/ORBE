import 'package:cloud_firestore/cloud_firestore.dart';

/// Backend-facing contract for writing administrative audit records.
///
/// IMPORTANT:
/// The production Firestore rule for `admin_audit_logs` is intentionally
/// server-only (`isServer()`). This helper is a typed contract for the backend or
/// Cloud Functions that should perform privileged administrative actions and then
/// persist an immutable audit record.
class AdminAuditService {
  final FirebaseFirestore _firestore;

  AdminAuditService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> recordExecution({
    required String action,
    required String resourceType,
    required String resourceId,
    required String actorUid,
    required String status,
    String? requestId,
    String? reason,
    Map<String, dynamic>? details,
  }) async {
    final logId =
        'audit_${DateTime.now().toUtc().microsecondsSinceEpoch}_$actorUid';
    final audit = {
      'logId': logId,
      'action': action,
      'actorUid': actorUid,
      'resourceType': resourceType,
      'resourceId': resourceId,
      'status': status,
      'reason': reason ?? 'Administrative action executed by backend',
      'requestId': requestId,
      'details': details ?? <String, dynamic>{},
      'executedAt': FieldValue.serverTimestamp(),
      'source': 'backend',
    };

    await _firestore.collection('admin_audit_logs').doc(logId).set(audit);
  }
}
