import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../../../services/outbox_service.dart';

class ChatService {
  final FirebaseFirestore _firestore;
  final String roomId;

  ChatService({this.roomId = 'general', FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<ChatMessage>> messagesStream() {
    return _firestore
        .collection('chats')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChatMessage.fromDoc(d)).toList());
  }

  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    String? text,
    String? stickerUrl,
    Map<String, dynamic>? meta,
    String? idempotencyKey,
  }) async {
    final resolvedMessageId = idempotencyKey ??
        meta?['clientMessageId'] as String? ??
        const Uuid().v4();
    final col =
        _firestore.collection('chats').doc(roomId).collection('messages');
    final doc = col.doc(resolvedMessageId);
    final existing = await doc.get();
    if (existing.exists) {
      return;
    }

    final mergedMeta = Map<String, dynamic>.from(meta ?? {})
      ..['clientMessageId'] = resolvedMessageId;

    final msg = ChatMessage(
      id: resolvedMessageId,
      senderId: senderId,
      senderName: senderName,
      text: text,
      stickerUrl: stickerUrl,
      meta: mergedMeta,
      createdAt: DateTime.now(),
    );
    final payload = msg.toMap()
      ..['id'] = resolvedMessageId
      ..['idempotencyKey'] = resolvedMessageId;

    try {
      await doc.set(payload).timeout(const Duration(seconds: 10));
    } catch (e) {
      try {
        await OutboxService.instance.enqueue({
          'type': 'chat_message',
          'payload': {
            'roomId': roomId,
            'messageId': resolvedMessageId,
            'message': payload,
          },
        });
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
