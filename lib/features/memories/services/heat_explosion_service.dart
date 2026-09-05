import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class HeatExplosionService {
  static FirebaseFirestore? _safeFirestore() {
    try {
      return Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null;
    } catch (_) {
      return null;
    }
  }

  final FirebaseFirestore? _firestore;

  HeatExplosionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? _safeFirestore();

  bool get isAvailable => _firestore != null;

  CollectionReference<Map<String, dynamic>>? get _events =>
      _firestore?.collection('heat_explosions');

  Stream<QuerySnapshot<Map<String, dynamic>>> eventsStream() {
    final events = _events;
    if (events == null) return const Stream.empty();

    return events.orderBy('createdAt', descending: true).limit(20).snapshots();
  }

  Future<String> trigger({
    required String userId,
    required String displayName,
  }) async {
    final events = _events;
    if (events == null) return '';

    final reference = await events.add({
      'userId': userId,
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return reference.id;
  }
}
