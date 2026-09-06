import '../models/conversation_request.dart';

abstract class ConversationRequestRepository {
  Future<ConversationRequest?> getRequest(String requestId);

  Future<ConversationRequest?> getPendingRequest({
    required String requesterId,
    required String recipientId,
  });

  Future<ConversationRequest> createRequest(ConversationRequest request);

  Future<ConversationRequest> acceptRequest(String requestId);

  Future<ConversationRequest> declineRequest(String requestId);

  Future<ConversationRequest> cancelRequest(String requestId);
}
