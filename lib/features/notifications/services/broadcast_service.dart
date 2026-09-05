import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/broadcast.dart';

class BroadcastService {
  final FirebaseFirestore _firestore;

  BroadcastService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<BroadcastMessage>> streamAllBroadcasts() {
    return _firestore
        .collection('broadcasts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => BroadcastMessage.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }
}
