import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:labomba_app/features/social/connections/identities.dart';
import 'package:labomba_app/features/social/connections/infrastructure/firestore_block_repository.dart';
import 'package:labomba_app/features/social/connections/infrastructure/firestore_connection_repository.dart';
import 'package:labomba_app/features/social/connections/infrastructure/firestore_conversation_request_repository.dart';
import 'package:labomba_app/features/social/connections/infrastructure/firestore_social_errors.dart';
import 'package:labomba_app/features/social/connections/infrastructure/firestore_social_mappers.dart';
import 'package:labomba_app/features/social/connections/models/connection_request.dart';
import 'package:labomba_app/features/social/connections/models/connection_status.dart';
import 'package:labomba_app/features/social/connections/models/conversation_request.dart';
import 'package:labomba_app/features/social/connections/models/social_block.dart';
import 'package:labomba_app/features/social/connections/models/social_connection.dart';
import 'package:labomba_app/features/social/connections/infrastructure/social_operation_client.dart';

class _FakeSocialOperationClient implements SocialOperationClient {
  _FakeSocialOperationClient(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> payload,
  ) async {
    final now = FieldValue.serverTimestamp();
    if (operation == 'sendConnectionRequest' ||
        operation == 'sendConversationRequest') {
      final collection = operation == 'sendConnectionRequest'
          ? 'connection_requests'
          : 'conversation_requests';
      final id = operation == 'sendConnectionRequest'
          ? ConnectionRequestIdentity.forDirection(
              payload['fromUserId']! as String,
              payload['toUserId']! as String,
            )
          : ConversationRequestIdentity.forDirection(
              payload['fromUserId']! as String,
              payload['toUserId']! as String,
            );
      await firestore.collection(collection).doc(id).set({
        'fromUserId': payload['fromUserId'],
        'toUserId': payload['toUserId'],
        'status': 'pending',
        'createdAt': now,
        'updatedAt': now,
      });
    } else if (operation.contains('Request')) {
      final collection = operation.contains('Connection')
          ? 'connection_requests'
          : 'conversation_requests';
      final id = payload['expectedId']! as String;
      final status = operation.startsWith('accept')
          ? 'accepted'
          : operation.startsWith('decline')
              ? 'declined'
              : 'cancelled';
      await firestore.collection(collection).doc(id).update({
        'status': status,
        'updatedAt': now,
      });
    } else if (operation == 'createConnection' ||
        operation == 'removeConnection') {
      final first = payload['firstUserId']! as String;
      final second = payload['secondUserId']! as String;
      final id = ConnectionIdentity.forPair(first, second);
      final users = [first, second]..sort();
      await firestore.collection('connections').doc(id).set({
        'userA': users.first,
        'userB': users.last,
        'status': operation == 'removeConnection' ? 'removed' : 'connected',
        'createdAt': now,
        'updatedAt': now,
        'connectedAt': now,
        if (operation == 'removeConnection') 'removedAt': now,
        if (operation == 'removeConnection') 'removedBy': first,
      }, SetOptions(merge: true));
    } else if (operation == 'createBlock' || operation == 'removeBlock') {
      final blocker = payload['blockerId']! as String;
      final blocked = payload['blockedUserId']! as String;
      final id = BlockIdentity.forDirection(blocker, blocked);
      await firestore.collection('blocks').doc(id).set({
        'blockerId': blocker,
        'blockedUserId': blocked,
        'status': operation == 'removeBlock' ? 'removed' : 'active',
        'createdAt': now,
        'updatedAt': now,
        if (operation == 'removeBlock') 'removedAt': now,
        if (operation == 'removeBlock') 'removedBy': blocker,
      }, SetOptions(merge: true));
    }
    return <String, dynamic>{};
  }
}

void main() {
  final created = DateTime.utc(2026, 1, 1);
  final updated = DateTime.utc(2026, 1, 2);

  test('mappers round-trip every persisted social model', () {
    final request = ConnectionRequest(
      requestId: ConnectionRequestIdentity.forDirection('alice', 'bob'),
      requesterId: 'alice',
      recipientId: 'bob',
      status: ConnectionRequestStatus.accepted,
      createdAt: created,
      updatedAt: updated,
    );
    final requestMap = FirestoreSocialMappers.connectionRequestToMap(request);
    final parsedRequest = FirestoreSocialMappers.connectionRequestFromMap(
      request.requestId,
      requestMap.cast<String, dynamic>(),
    );
    expect(parsedRequest.status, ConnectionRequestStatus.accepted);
    expect(parsedRequest.createdAt, created);
    expect(requestMap['createdAt'], isA<Timestamp>());

    final conversation = ConversationRequest(
      requestId: ConversationRequestIdentity.forDirection('alice', 'bob'),
      requesterId: 'alice',
      recipientId: 'bob',
      status: ConversationRequestStatus.cancelled,
      createdAt: created,
      updatedAt: updated,
    );
    final parsedConversation =
        FirestoreSocialMappers.conversationRequestFromMap(
      conversation.requestId,
      FirestoreSocialMappers.conversationRequestToMap(conversation)
          .cast<String, dynamic>(),
    );
    expect(parsedConversation.status, ConversationRequestStatus.cancelled);

    final connection = SocialConnection(
      connectionId: ConnectionIdentity.forPair('alice', 'bob'),
      userAId: 'alice',
      userBId: 'bob',
      status: SocialConnectionStatus.connected,
      createdAt: created,
      updatedAt: updated,
      connectedAt: created,
    );
    final parsedConnection = FirestoreSocialMappers.connectionFromMap(
      connection.connectionId,
      FirestoreSocialMappers.connectionToMap(connection)
          .cast<String, dynamic>(),
    );
    expect(parsedConnection.status, SocialConnectionStatus.connected);

    final block = SocialBlock(
      blockId: BlockIdentity.forDirection('alice', 'bob'),
      blockerId: 'alice',
      blockedUserId: 'bob',
      status: SocialBlockStatus.active,
      createdAt: created,
    );
    final parsedBlock = FirestoreSocialMappers.blockFromMap(
      block.blockId,
      FirestoreSocialMappers.blockToMap(block).cast<String, dynamic>(),
    );
    expect(parsedBlock.status, SocialBlockStatus.active);
  });

  test('mappers reject missing required fields and mismatched IDs', () {
    expect(
      () => FirestoreSocialMappers.connectionRequestFromMap(
        'wrong',
        <String, dynamic>{
          'fromUserId': 'alice',
          'toUserId': 'bob',
          'status': 'pending',
          'createdAt': Timestamp.fromDate(created),
          'updatedAt': Timestamp.fromDate(updated),
        },
      ),
      throwsA(isA<FirestoreSocialException>()),
    );
    expect(
      () => FirestoreSocialMappers.blockFromMap(
        BlockIdentity.forDirection('alice', 'bob'),
        <String, dynamic>{
          'blockerId': 'alice',
          'blockedUserId': 'bob',
          'status': 'active',
        },
      ),
      throwsA(isA<FirestoreSocialException>()),
    );
  });

  test('connection request persistence is deterministic and idempotent',
      () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreConnectionRepository(
      firestore: firestore,
      operationClient: _FakeSocialOperationClient(firestore),
    );
    final request = ConnectionRequest(
      requestId: ConnectionRequestIdentity.forDirection('alice', 'bob'),
      requesterId: 'alice',
      recipientId: 'bob',
      status: ConnectionRequestStatus.pending,
      createdAt: created,
      updatedAt: created,
    );

    final first = await repository.createRequest(request);
    final second = await repository.createRequest(request);
    expect(first.requestId, second.requestId);
    expect((await firestore.collection('connection_requests').get()).docs,
        hasLength(1));

    final accepted = await repository.acceptRequest(request.requestId);
    expect(accepted.status, ConnectionRequestStatus.accepted);
    expect(
        await repository.getPendingRequest(
          requesterId: 'alice',
          recipientId: 'bob',
        ),
        isNull);
  });

  test('conversation request acceptance does not create a connection',
      () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreConversationRequestRepository(
      firestore: firestore,
      operationClient: _FakeSocialOperationClient(firestore),
    );
    final request = ConversationRequest(
      requestId: ConversationRequestIdentity.forDirection('alice', 'bob'),
      requesterId: 'alice',
      recipientId: 'bob',
      status: ConversationRequestStatus.pending,
      createdAt: created,
      updatedAt: created,
    );

    await repository.createRequest(request);
    final accepted = await repository.acceptRequest(request.requestId);
    expect(accepted.status, ConversationRequestStatus.accepted);
    expect((await firestore.collection('connections').get()).docs, isEmpty);
  });

  test('connections are deterministic, idempotent, and logically removable',
      () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreConnectionRepository(
      firestore: firestore,
      operationClient: _FakeSocialOperationClient(firestore),
    );
    final request = ConnectionRequest(
      requestId: ConnectionRequestIdentity.forDirection('alice', 'bob'),
      requesterId: 'alice',
      recipientId: 'bob',
      status: ConnectionRequestStatus.accepted,
      createdAt: created,
      updatedAt: updated,
    );

    final first = await repository.createConnection(request);
    final second = await repository.createConnection(request);
    expect(first.connectionId, ConnectionIdentity.forPair('bob', 'alice'));
    expect(second.status, SocialConnectionStatus.connected);
    expect(
        (await firestore.collection('connections').get()).docs, hasLength(1));
    expect(
      await repository.getConnectionStatus(
        currentUserId: 'alice',
        otherUserId: 'bob',
      ),
      ConnectionStatus.connected,
    );

    final removed = await repository.removeConnection(
      firstUserId: 'bob',
      secondUserId: 'alice',
      removedBy: 'alice',
    );
    expect(removed.status, SocialConnectionStatus.removed);
    expect(
        (await firestore.collection('connections').get()).docs, hasLength(1));
    expect(
      await repository.getConnectionStatus(
        currentUserId: 'alice',
        otherUserId: 'bob',
      ),
      ConnectionStatus.none,
    );
  });

  test(
      'blocks are unilateral, idempotent, and removable without deleting history',
      () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreBlockRepository(
      firestore: firestore,
      operationClient: _FakeSocialOperationClient(firestore),
    );
    final block = SocialBlock(
      blockId: BlockIdentity.forDirection('alice', 'bob'),
      blockerId: 'alice',
      blockedUserId: 'bob',
      status: SocialBlockStatus.active,
      createdAt: created,
    );

    final first = await repository.createBlock(block);
    final second = await repository.createBlock(block);
    expect(first.blockId, second.blockId);
    expect(
        await repository.isBlocked(
          firstUserId: 'alice',
          secondUserId: 'bob',
        ),
        isTrue);

    final removed = await repository.removeBlock(
      blockerId: 'alice',
      blockedUserId: 'bob',
      removedBy: 'alice',
    );
    expect(removed.status, SocialBlockStatus.removed);
    expect((await firestore.collection('blocks').get()).docs, hasLength(1));
  });
}
