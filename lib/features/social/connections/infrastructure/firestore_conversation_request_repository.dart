import 'package:cloud_firestore/cloud_firestore.dart';

import '../identities.dart';
import '../models/conversation_request.dart';
import '../repositories/conversation_request_repository.dart';
import 'firestore_social_errors.dart';
import 'firestore_social_mappers.dart';
import 'social_operation_client.dart';

class FirestoreConversationRequestRepository
    implements ConversationRequestRepository {
  FirestoreConversationRequestRepository({
    FirebaseFirestore? firestore,
    SocialOperationClient? operationClient,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _operationClient = operationClient ?? FirebaseSocialOperationClient();

  static const _requests = 'conversation_requests';
  final FirebaseFirestore _firestore;
  final SocialOperationClient _operationClient;

  @override
  Future<ConversationRequest?> getRequest(String requestId) async {
    if (requestId.trim().isEmpty) throw _invalid('requestId must not be empty');
    final snapshot = await _firestore.collection(_requests).doc(requestId).get();
    return snapshot.exists
        ? FirestoreSocialMappers.conversationRequestFromMap(
            snapshot.id,
            snapshot.data()!,
          )
        : null;
  }

  @override
  Future<ConversationRequest?> getPendingRequest({
    required String requesterId,
    required String recipientId,
  }) async {
    final id = ConversationRequestIdentity.forDirection(
      requesterId,
      recipientId,
    );
    final request = await getRequest(id);
    return request?.status == ConversationRequestStatus.pending ? request : null;
  }

  @override
  Future<ConversationRequest> createRequest(
      ConversationRequest request) async {
    if (request.status != ConversationRequestStatus.pending) {
      throw const FirestoreSocialException(
        FirestoreSocialErrorCode.conflict,
        'A new conversation request must be pending',
      );
    }
    final id = ConversationRequestIdentity.forDirection(
      request.requesterId,
      request.recipientId,
    );
    await _operationClient.call('sendConversationRequest', {
      'fromUserId': request.requesterId,
      'toUserId': request.recipientId,
      'expectedId': id,
    });
    return _readRequired(id);
  }

  @override
  Future<ConversationRequest> acceptRequest(String requestId) =>
      _transition(requestId, 'acceptConversationRequest');

  @override
  Future<ConversationRequest> declineRequest(String requestId) =>
      _transition(requestId, 'declineConversationRequest');

  @override
  Future<ConversationRequest> cancelRequest(String requestId) =>
      _transition(requestId, 'cancelConversationRequest');

  Future<ConversationRequest> _transition(
    String requestId,
    String operation,
  ) async {
    if (requestId.trim().isEmpty) throw _invalid('requestId must not be empty');
    final request = await getRequest(requestId);
    if (request == null) throw _notFound('Conversation request not found');
    await _operationClient.call(operation, {
      'fromUserId': request.requesterId,
      'toUserId': request.recipientId,
      'expectedId': requestId,
    });
    return _readRequired(requestId);
  }

  Future<ConversationRequest> _readRequired(String id) async {
    final request = await getRequest(id);
    if (request == null) {
      throw _unavailable('Conversation request was not readable after write');
    }
    return request;
  }

  FirestoreSocialException _invalid(String message) =>
      FirestoreSocialException(FirestoreSocialErrorCode.invalidData, message);
  FirestoreSocialException _notFound(String message) =>
      FirestoreSocialException(FirestoreSocialErrorCode.notFound, message);
  FirestoreSocialException _unavailable(String message) =>
      FirestoreSocialException(FirestoreSocialErrorCode.unavailable, message);
}
