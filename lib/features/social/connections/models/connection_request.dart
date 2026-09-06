enum ConnectionRequestStatus { pending, accepted, declined, cancelled }

class ConnectionRequest {
  final String requestId;
  final String requesterId;
  final String recipientId;
  final ConnectionRequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  ConnectionRequest({
    required this.requestId,
    required this.requesterId,
    required this.recipientId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  }) {
    _requireNonEmpty(requestId, 'requestId');
    _requireNonEmpty(requesterId, 'requesterId');
    _requireNonEmpty(recipientId, 'recipientId');
    if (requesterId == recipientId) {
      throw ArgumentError('requesterId and recipientId must differ');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError('updatedAt must not precede createdAt');
    }
  }

  ConnectionRequest copyWith({
    ConnectionRequestStatus? status,
    DateTime? updatedAt,
  }) {
    return ConnectionRequest(
      requestId: requestId,
      requesterId: requesterId,
      recipientId: recipientId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

void _requireNonEmpty(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError('$name must not be empty');
  }
}
