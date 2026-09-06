import '../models/conversation_request.dart';

abstract class ConversationRequestService {
  Future<ConversationRequest> sendConversationRequest({
    required String requesterId,
    required String recipientId,
  });

  Future<ConversationRequest> acceptConversationRequest(String requestId);

  Future<ConversationRequest> declineConversationRequest(String requestId);

  Future<ConversationRequest> cancelConversationRequest(String requestId);
}
