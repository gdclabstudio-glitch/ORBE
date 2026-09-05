import 'package:cloud_firestore/cloud_firestore.dart';

class GroupService {
  final FirebaseFirestore _firestore;
  GroupService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> groupsStream() {
    return _firestore.collection('groups').orderBy('name').snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> createGroup(
    Map<String, dynamic> payload,
  ) async {
    final ref = await _firestore.collection('groups').add(payload);
    return ref;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> sendMessage(String groupId, Map<String, dynamic> payload) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .add(payload);
  }
}
