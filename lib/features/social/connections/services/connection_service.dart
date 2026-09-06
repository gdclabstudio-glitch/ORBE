import '../models/connection_request.dart';
import '../models/social_connection.dart';

abstract class ConnectionService {
  Future<ConnectionRequest> sendConnectionRequest({
    required String requesterId,
    required String recipientId,
  });

  Future<ConnectionRequest> acceptConnectionRequest(String requestId);

  Future<ConnectionRequest> declineConnectionRequest(String requestId);

  Future<ConnectionRequest> cancelConnectionRequest(String requestId);

  Future<SocialConnection> removeConnection({
    required String firstUserId,
    required String secondUserId,
    required String removedBy,
  });
}
