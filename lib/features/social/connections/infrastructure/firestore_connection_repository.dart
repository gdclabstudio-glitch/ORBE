import 'package:cloud_firestore/cloud_firestore.dart';

import '../identities.dart';
import '../models/connection_request.dart';
import '../models/connection_status.dart';
import '../models/social_block.dart';
import '../models/social_connection.dart';
import '../repositories/connection_repository.dart';
import 'firestore_social_errors.dart';
import 'firestore_social_mappers.dart';
import 'social_operation_client.dart';

class FirestoreConnectionRepository implements ConnectionRepository {
  FirestoreConnectionRepository({
    FirebaseFirestore? firestore,
    SocialOperationClient? operationClient,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _operationClient = operationClient ?? FirebaseSocialOperationClient();

  static const _connections = 'connections';
  static const _requests = 'connection_requests';

  final FirebaseFirestore _firestore;
  final SocialOperationClient _operationClient;

  @override
  Future<SocialConnection?> getConnection({
    required String firstUserId,
    required String secondUserId,
  }) async {
    final id = ConnectionIdentity.forPair(firstUserId, secondUserId);
    final snapshot = await _firestore.collection(_connections).doc(id).get();
    return snapshot.exists
        ? FirestoreSocialMappers.connectionFromMap(id, snapshot.data()!)
        : null;
  }

  @override
  Future<ConnectionStatus> getConnectionStatus({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final activeBlock = await _activeBlockExists(currentUserId, otherUserId);
    if (activeBlock) return ConnectionStatus.blocked;

    final connection = await getConnection(
      firstUserId: currentUserId,
      secondUserId: otherUserId,
    );
    if (connection?.status == SocialConnectionStatus.connected) {
      return ConnectionStatus.connected;
    }

    final outgoing = await getPendingRequest(
      requesterId: currentUserId,
      recipientId: otherUserId,
    );
    if (outgoing != null) return ConnectionStatus.pendingOutgoing;

    final incoming = await getPendingRequest(
      requesterId: otherUserId,
      recipientId: currentUserId,
    );
    if (incoming != null) return ConnectionStatus.pendingIncoming;
    return ConnectionStatus.none;
  }

  @override
  Future<SocialConnection> createConnection(ConnectionRequest request) async {
    if (request.status != ConnectionRequestStatus.accepted) {
      throw const FirestoreSocialException(
        FirestoreSocialErrorCode.conflict,
        'Only an accepted request can create a connection',
      );
    }
    final id = ConnectionIdentity.forPair(
      request.requesterId,
      request.recipientId,
    );
    await _operationClient.call('createConnection', {
      'firstUserId': request.requesterId,
      'secondUserId': request.recipientId,
      'expectedId': id,
    });
    return _readRequiredConnection(id);
  }

  @override
  Future<SocialConnection> removeConnection({
    required String firstUserId,
    required String secondUserId,
    required String removedBy,
  }) async {
    if (removedBy.trim().isEmpty) {
      throw const FirestoreSocialException(
        FirestoreSocialErrorCode.invalidData,
        'removedBy must not be empty',
      );
    }
    final id = ConnectionIdentity.forPair(firstUserId, secondUserId);
    await _operationClient.call('removeConnection', {
      'firstUserId': firstUserId,
      'secondUserId': secondUserId,
      'expectedId': id,
    });
    return _readRequiredConnection(id);
  }

  @override
  Future<ConnectionRequest?> getRequest(String requestId) async {
    if (requestId.trim().isEmpty) throw _invalid('requestId must not be empty');
    final snapshot =
        await _firestore.collection(_requests).doc(requestId).get();
    return snapshot.exists
        ? FirestoreSocialMappers.connectionRequestFromMap(
            snapshot.id,
            snapshot.data()!,
          )
        : null;
  }

  @override
  Future<ConnectionRequest?> getPendingRequest({
    required String requesterId,
    required String recipientId,
  }) async {
    final id = ConnectionRequestIdentity.forDirection(
      requesterId,
      recipientId,
    );
    final request = await getRequest(id);
    return request?.status == ConnectionRequestStatus.pending ? request : null;
  }

  @override
  Future<ConnectionRequest> createRequest(ConnectionRequest request) async {
    if (request.status != ConnectionRequestStatus.pending) {
      throw const FirestoreSocialException(
        FirestoreSocialErrorCode.conflict,
        'A new connection request must be pending',
      );
    }
    final id = ConnectionRequestIdentity.forDirection(
      request.requesterId,
      request.recipientId,
    );
    await _operationClient.call('sendConnectionRequest', {
      'fromUserId': request.requesterId,
      'toUserId': request.recipientId,
      'expectedId': id,
    });
    return _readRequiredRequest(id);
  }

  @override
  Future<ConnectionRequest> acceptRequest(String requestId) =>
      _transitionRequest(requestId, 'acceptConnectionRequest');

  @override
  Future<ConnectionRequest> declineRequest(String requestId) =>
      _transitionRequest(requestId, 'declineConnectionRequest');

  @override
  Future<ConnectionRequest> cancelRequest(String requestId) =>
      _transitionRequest(requestId, 'cancelConnectionRequest');

  Future<ConnectionRequest> _transitionRequest(
    String requestId,
    String operation,
  ) async {
    if (requestId.trim().isEmpty) throw _invalid('requestId must not be empty');
    final request = await getRequest(requestId);
    if (request == null) throw _notFound('Connection request not found');
    await _operationClient.call(operation, {
      'fromUserId': request.requesterId,
      'toUserId': request.recipientId,
      'expectedId': requestId,
    });
    return _readRequiredRequest(requestId);
  }

  Future<bool> _activeBlockExists(String first, String second) async {
    final ids = <String>[
      BlockIdentity.forDirection(first, second),
      BlockIdentity.forDirection(second, first),
    ];
    final snapshots = await Future.wait(
      ids.map((id) => _firestore.collection('blocks').doc(id).get()),
    );
    return snapshots.any((snapshot) {
      if (!snapshot.exists) return false;
      final block = FirestoreSocialMappers.blockFromMap(
        snapshot.id,
        snapshot.data()!,
      );
      return block.status == SocialBlockStatus.active;
    });
  }

  Future<SocialConnection> _readRequiredConnection(String id) async {
    final snapshot = await _firestore.collection(_connections).doc(id).get();
    if (!snapshot.exists) {
      throw _unavailable('Connection was not readable after write');
    }
    return FirestoreSocialMappers.connectionFromMap(id, snapshot.data()!);
  }

  Future<ConnectionRequest> _readRequiredRequest(String id) async {
    final request = await getRequest(id);
    if (request == null)
      throw _unavailable('Request was not readable after write');
    return request;
  }

  FirestoreSocialException _invalid(String message) =>
      FirestoreSocialException(FirestoreSocialErrorCode.invalidData, message);
  FirestoreSocialException _notFound(String message) =>
      FirestoreSocialException(FirestoreSocialErrorCode.notFound, message);
  FirestoreSocialException _unavailable(String message) =>
      FirestoreSocialException(FirestoreSocialErrorCode.unavailable, message);
}
