import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/chat/providers/chat_provider.dart';
import 'package:labomba_app/features/chat/services/chat_service.dart';

void main() {
  group('ChatService idempotence', () {
    test('reusing the same idempotency key does not create duplicate messages',
        () async {
      final fake = FakeFirebaseFirestore();
      final service = ChatService(firestore: fake, roomId: 'room-1');

      const messageId = 'message-idempotent-123';

      await service.sendMessage(
        senderId: 'user-1',
        senderName: 'Alice',
        text: 'Hello there',
        idempotencyKey: messageId,
      );

      await service.sendMessage(
        senderId: 'user-1',
        senderName: 'Alice',
        text: 'Hello there',
        idempotencyKey: messageId,
      );

      final messages = await fake
          .collection('chats')
          .doc('room-1')
          .collection('messages')
          .get();

      expect(messages.docs.length, 1);
      expect(messages.docs.single.id, messageId);
      expect(messages.docs.single.data()['text'], 'Hello there');
    });

    test('concurrent double-tap sends with the same payload are deduplicated',
        () async {
      final fake = FakeFirebaseFirestore();
      final service = _DelimitedChatService(fake, roomId: 'room-1');
      final provider = ChatProvider(service: service);

      await Future.wait([
        provider.sendMessage(
          senderId: 'user-1',
          senderName: 'Alice',
          text: 'Double tap payload',
        ),
        provider.sendMessage(
          senderId: 'user-1',
          senderName: 'Alice',
          text: 'Double tap payload',
        ),
      ]);

      final messages = await fake
          .collection('chats')
          .doc('room-1')
          .collection('messages')
          .get();

      expect(service.sendCalls, 1);
      expect(messages.docs.length, 1);
      expect(messages.docs.single.data()['text'], 'Double tap payload');
    });
  });
}

class _DelimitedChatService extends ChatService {
  _DelimitedChatService(
    FirebaseFirestore firestore, {
    required super.roomId,
  }) : super(firestore: firestore);

  int sendCalls = 0;

  @override
  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    String? text,
    String? stickerUrl,
    Map<String, dynamic>? meta,
    String? idempotencyKey,
  }) async {
    sendCalls += 1;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return super.sendMessage(
      senderId: senderId,
      senderName: senderName,
      text: text,
      stickerUrl: stickerUrl,
      meta: meta,
      idempotencyKey: idempotencyKey,
    );
  }
}
