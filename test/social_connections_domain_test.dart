import 'package:flutter_test/flutter_test.dart';

import 'package:labomba_app/features/social/connections/identities.dart';
import 'package:labomba_app/features/social/connections/models/connection_request.dart';
import 'package:labomba_app/features/social/connections/models/connection_status.dart';
import 'package:labomba_app/features/social/connections/models/conversation_request.dart';
import 'package:labomba_app/features/social/connections/models/social_block.dart';
import 'package:labomba_app/features/social/connections/models/social_connection.dart';
import 'package:labomba_app/features/social/connections/services/connection_policy.dart';
import 'package:labomba_app/features/social/connections/services/connection_state_machine.dart';

void main() {
  final created = DateTime.utc(2026, 1, 1);
  final updated = DateTime.utc(2026, 1, 2);

  group('connection identities', () {
    test('connection identity is independent of direction', () {
      expect(
        ConnectionIdentity.forPair('alice', 'bob'),
        ConnectionIdentity.forPair('bob', 'alice'),
      );
    });

    test('request and block identities preserve direction', () {
      expect(
        ConnectionRequestIdentity.forDirection('alice', 'bob'),
        isNot(ConnectionRequestIdentity.forDirection('bob', 'alice')),
      );
      expect(
        ConversationRequestIdentity.forDirection('alice', 'bob'),
        isNot(ConversationRequestIdentity.forDirection('bob', 'alice')),
      );
      expect(
        BlockIdentity.forDirection('alice', 'bob'),
        isNot(BlockIdentity.forDirection('bob', 'alice')),
      );
    });

    test('identities reject empty and self pairs', () {
      expect(() => ConnectionIdentity.forPair('alice', 'alice'),
          throwsArgumentError);
      expect(() => BlockIdentity.forDirection('', 'bob'), throwsArgumentError);
    });

    test('identities are safe for arbitrary UID characters and bounded', () {
      for (final uid in [
        'a/b',
        'a%b',
        'a:b',
        'a b',
        'á世界',
        List.filled(128, 'x').join(),
      ]) {
        expect(
          BlockIdentity.forDirection(uid, 'recipient'),
          matches(RegExp(r'^[0-9a-f]{64}$')),
        );
      }
      expect(
        ConnectionRequestIdentity.forDirection('alice', 'bob'),
        isNot(ConversationRequestIdentity.forDirection('alice', 'bob')),
      );
    });
  });

  group('models and lifecycle', () {
    test('validates connection request and lifecycle transitions', () {
      final request = ConnectionRequest(
        requestId: ConnectionRequestIdentity.forDirection('alice', 'bob'),
        requesterId: 'alice',
        recipientId: 'bob',
        status: ConnectionRequestStatus.pending,
        createdAt: created,
        updatedAt: created,
      );

      expect(
        ConnectionStateMachine.canTransitionRequest(
          request.status,
          ConnectionRequestStatus.accepted,
        ),
        isTrue,
      );
      expect(
        ConnectionStateMachine.canTransitionRequest(
          ConnectionRequestStatus.declined,
          ConnectionRequestStatus.accepted,
        ),
        isFalse,
      );
      expect(
        () => ConnectionRequest(
          requestId: 'request',
          requesterId: 'alice',
          recipientId: 'alice',
          status: ConnectionRequestStatus.pending,
          createdAt: created,
          updatedAt: updated,
        ),
        throwsArgumentError,
      );
    });

    test('connection requires sorted users and removal data', () {
      final connection = SocialConnection(
        connectionId: ConnectionIdentity.forPair('alice', 'bob'),
        userAId: 'alice',
        userBId: 'bob',
        status: SocialConnectionStatus.connected,
        createdAt: created,
        updatedAt: updated,
        connectedAt: created,
      );
      expect(
        ConnectionStateMachine.canTransitionConnection(
          connection.status,
          SocialConnectionStatus.removed,
        ),
        isTrue,
      );
      expect(
        () => SocialConnection(
          connectionId: 'bob::alice',
          userAId: 'bob',
          userBId: 'alice',
          status: SocialConnectionStatus.connected,
          createdAt: created,
          updatedAt: updated,
          connectedAt: created,
        ),
        throwsArgumentError,
      );
      expect(
        () => SocialConnection(
          connectionId: 'alice::bob',
          userAId: 'alice',
          userBId: 'bob',
          status: SocialConnectionStatus.removed,
          createdAt: created,
          updatedAt: updated,
          connectedAt: created,
        ),
        throwsArgumentError,
      );
    });

    test('block and conversation request are independent models', () {
      final block = SocialBlock(
        blockId: BlockIdentity.forDirection('alice', 'bob'),
        blockerId: 'alice',
        blockedUserId: 'bob',
        status: SocialBlockStatus.active,
        createdAt: created,
      );
      final request = ConversationRequest(
        requestId: ConversationRequestIdentity.forDirection('alice', 'bob'),
        requesterId: 'alice',
        recipientId: 'bob',
        status: ConversationRequestStatus.pending,
        createdAt: created,
        updatedAt: updated,
      );
      expect(block.blockerId, isNot(block.blockedUserId));
      expect(request.status, ConversationRequestStatus.pending);
      expect(
        ConnectionStateMachine.canTransitionBlock(
          SocialBlockStatus.removed,
          SocialBlockStatus.active,
        ),
        isFalse,
      );
    });
  });

  group('policies', () {
    test('connection policy only permits a new relationship from none', () {
      expect(
        ConnectionPolicy.canConnect(
          currentUserId: 'alice',
          otherUserId: 'bob',
          status: ConnectionStatus.none,
        ),
        isTrue,
      );
      expect(
        ConnectionPolicy.canConnect(
          currentUserId: 'alice',
          otherUserId: 'bob',
          status: ConnectionStatus.pendingIncoming,
        ),
        isFalse,
      );
      expect(
        BlockingPolicy.canSendPrivateMessage(
          status: ConnectionStatus.none,
          conversationRequestAccepted: true,
        ),
        isTrue,
      );
      expect(
        BlockingPolicy.canSendPrivateMessage(
          status: ConnectionStatus.blocked,
          conversationRequestAccepted: true,
        ),
        isFalse,
      );
    });

    test('conversation requests are allowed for non-connected users only', () {
      expect(
        BlockingPolicy.canSendConversationRequest(
          currentUserId: 'alice',
          otherUserId: 'bob',
          status: ConnectionStatus.none,
        ),
        isTrue,
      );
      expect(
        BlockingPolicy.canSendConversationRequest(
          currentUserId: 'alice',
          otherUserId: 'bob',
          status: ConnectionStatus.connected,
        ),
        isFalse,
      );
      expect(
        BlockingPolicy.canSendConversationRequest(
          currentUserId: 'alice',
          otherUserId: 'alice',
          status: ConnectionStatus.none,
        ),
        isFalse,
      );
    });
  });
}
