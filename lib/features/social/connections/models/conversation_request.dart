enum ConversationRequestStatus { pending, accepted, declined, cancelled }

class ConversationRequest {
  final String requestId;
  final String requesterId;
  final String recipientId;
  final ConversationRequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  ConversationRequest({
    required this.requestId,
    required this.requesterId,
    required this.recipientId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (requestId.trim().isEmpty ||
        requesterId.trim().isEmpty ||
        recipientId.trim().isEmpty) {
      throw ArgumentError('conversation request IDs must not be empty');
    }
    if (requesterId == recipientId) {
      throw ArgumentError('requesterId and recipientId must differ');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError('updatedAt must not precede createdAt');
    }
  }
}
