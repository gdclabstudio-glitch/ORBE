import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class OfficialAnnouncement {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;

  const OfficialAnnouncement({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
  });

  factory OfficialAnnouncement.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final timestamp = data['createdAt'];
    return OfficialAnnouncement(
      id: document.id,
      title: data['title'] as String? ?? 'Buzina oficial',
      message: data['message'] as String? ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }
}

class OfficialHornService {
  static FirebaseFirestore? _safeFirestore() {
    try {
      return Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null;
    } catch (_) {
      return null;
    }
  }

  final FirebaseFirestore? _firestore;

  OfficialHornService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? _safeFirestore();

  bool get isAvailable => _firestore != null;

  CollectionReference<Map<String, dynamic>>? get _announcements =>
      _firestore?.collection('official_announcements');

  Stream<QuerySnapshot<Map<String, dynamic>>> announcementsStream() {
    final announcements = _announcements;
    if (announcements == null) {
      return const Stream.empty();
    }

    return announcements
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  Future<void> publish({required String title, required String message}) async {
    final announcements = _announcements;
    if (announcements == null) return;

    await announcements.add({
      'title': title.trim(),
      'message': message.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
