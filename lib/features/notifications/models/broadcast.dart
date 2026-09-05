import 'package:cloud_firestore/cloud_firestore.dart';

class BroadcastMessage {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? authorId;

  BroadcastMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.authorId,
  });

  factory BroadcastMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final ts = data['createdAt'];
    return BroadcastMessage(
      id: doc.id,
      title: data['title'] as String? ?? 'Aviso',
      body: data['body'] as String? ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      authorId: data['authorId'] as String?,
    );
  }
}
