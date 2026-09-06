import '../models/connection_status.dart';

class ConnectionPolicy {
  const ConnectionPolicy._();

  static bool canConnect({
    required String currentUserId,
    required String otherUserId,
    required ConnectionStatus status,
  }) {
    if (currentUserId.trim().isEmpty ||
        otherUserId.trim().isEmpty ||
        currentUserId == otherUserId) {
      return false;
    }
    return status == ConnectionStatus.none;
  }
}

class BlockingPolicy {
  const BlockingPolicy._();

  static bool canSendConnectionRequest({
    required String currentUserId,
    required String otherUserId,
    required ConnectionStatus status,
  }) =>
      ConnectionPolicy.canConnect(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
        status: status,
      );

  static bool canSendConversationRequest({
    required String currentUserId,
    required String otherUserId,
    required ConnectionStatus status,
  }) {
    if (currentUserId.trim().isEmpty ||
        otherUserId.trim().isEmpty ||
        currentUserId == otherUserId ||
        status == ConnectionStatus.blocked ||
        status == ConnectionStatus.connected) {
      return false;
    }
    return true;
  }

  static bool canSendPrivateMessage({
    required ConnectionStatus status,
    required bool conversationRequestAccepted,
  }) =>
      status != ConnectionStatus.blocked &&
      (status == ConnectionStatus.connected || conversationRequestAccepted);

  static bool canFollow({
    required String currentUserId,
    required String otherUserId,
    required ConnectionStatus status,
  }) =>
      currentUserId.trim().isNotEmpty &&
      otherUserId.trim().isNotEmpty &&
      currentUserId != otherUserId &&
      status != ConnectionStatus.blocked;
}
