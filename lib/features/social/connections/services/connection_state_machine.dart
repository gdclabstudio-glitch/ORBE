import '../models/connection_request.dart';
import '../models/conversation_request.dart';
import '../models/social_block.dart';
import '../models/social_connection.dart';

class ConnectionStateMachine {
  const ConnectionStateMachine._();

  static bool canTransitionRequest(
    ConnectionRequestStatus from,
    ConnectionRequestStatus to,
  ) {
    if (from == to) return true;
    return from == ConnectionRequestStatus.pending &&
        (to == ConnectionRequestStatus.accepted ||
            to == ConnectionRequestStatus.declined ||
            to == ConnectionRequestStatus.cancelled);
  }

  static bool canTransitionConversationRequest(
    ConversationRequestStatus from,
    ConversationRequestStatus to,
  ) {
    if (from == to) return true;
    return from == ConversationRequestStatus.pending &&
        (to == ConversationRequestStatus.accepted ||
            to == ConversationRequestStatus.declined ||
            to == ConversationRequestStatus.cancelled);
  }

  static bool canTransitionConnection(
    SocialConnectionStatus from,
    SocialConnectionStatus to,
  ) {
    return from == to ||
        (from == SocialConnectionStatus.connected &&
            to == SocialConnectionStatus.removed);
  }

  static bool canTransitionBlock(
    SocialBlockStatus from,
    SocialBlockStatus to,
  ) {
    return from == to ||
        (from == SocialBlockStatus.active &&
            to == SocialBlockStatus.removed);
  }
}
