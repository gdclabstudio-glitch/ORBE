import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? text;
  final String? stickerUrl;
  final DateTime createdAt;
  final Map<String, dynamic>? meta;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.text,
    this.stickerUrl,
    this.meta,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'stickerUrl': stickerUrl,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (meta != null) 'meta': meta,
      };

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime created;
    try {
      created = DateTime.parse(
        data['createdAt'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
      ).toLocal();
    } catch (_) {
      created = DateTime.now();
    }
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? 'unknown',
      senderName: data['senderName'] as String? ?? 'Anon',
      text: data['text'] as String?,
      stickerUrl: data['stickerUrl'] as String?,
      meta: (data['meta'] as Map<String, dynamic>?) ??
          (data['context'] as Map<String, dynamic>?),
      createdAt: created,
    );
  }
}
