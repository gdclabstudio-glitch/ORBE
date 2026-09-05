import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../services/outbox_service.dart';

class ChatService {
  final FirebaseFirestore _firestore;

  ChatService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>?> sendMessage(
    String chatId,
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    final messages =
        _firestore.collection('chats').doc(chatId).collection('messages');
    final enriched = Map<String, dynamic>.from(payload);
    final resolvedMessageId = idempotencyKey ??
        enriched['clientMessageId'] as String? ??
        enriched['id'] as String? ??
        const Uuid().v4();
    enriched['clientMessageId'] = resolvedMessageId;
    enriched['id'] = resolvedMessageId;
    enriched['idempotencyKey'] = resolvedMessageId;
    enriched.putIfAbsent('createdAt', () => FieldValue.serverTimestamp());
    enriched.putIfAbsent('deliveredAt', () => null);
    enriched.putIfAbsent('isRead', () => false);

    final doc = messages.doc(resolvedMessageId);
    final existing = await doc.get();
    if (existing.exists) {
      return doc;
    }

    try {
      await doc.set(enriched).timeout(const Duration(seconds: 10));
      return doc;
    } catch (e) {
      try {
        final outboxPayload = Map<String, dynamic>.from(enriched);
        outboxPayload['createdAt'] = DateTime.now().toUtc().toIso8601String();
        await OutboxService.instance.enqueue({
          'type': 'chat_message',
          'payload': {
            'roomId': chatId,
            'messageId': resolvedMessageId,
            'message': outboxPayload,
          },
        });
        return null;
      } catch (_) {
        rethrow;
      }
    }
  }

  static String privateRoomId(String firstUserId, String secondUserId) {
    final users = [firstUserId, secondUserId]..sort();
    return 'private_${users[0]}_${users[1]}';
  }
}
