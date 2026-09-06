import '../models/connection_request.dart';
import '../models/connection_status.dart';
import '../models/social_connection.dart';

abstract class ConnectionRepository {
  Future<SocialConnection?> getConnection({
    required String firstUserId,
    required String secondUserId,
  });

  Future<ConnectionStatus> getConnectionStatus({
    required String currentUserId,
    required String otherUserId,
  });

  Future<SocialConnection> createConnection(ConnectionRequest request);

  Future<SocialConnection> removeConnection({
    required String firstUserId,
    required String secondUserId,
    required String removedBy,
  });

  Future<ConnectionRequest?> getRequest(String requestId);

  Future<ConnectionRequest?> getPendingRequest({
    required String requesterId,
    required String recipientId,
  });

  Future<ConnectionRequest> createRequest(ConnectionRequest request);

  Future<ConnectionRequest> acceptRequest(String requestId);

  Future<ConnectionRequest> declineRequest(String requestId);

  Future<ConnectionRequest> cancelRequest(String requestId);
}
