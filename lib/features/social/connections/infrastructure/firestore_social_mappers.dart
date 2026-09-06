import 'package:cloud_firestore/cloud_firestore.dart';

import '../identities.dart';
import '../models/connection_request.dart';
import '../models/conversation_request.dart';
import '../models/social_block.dart';
import '../models/social_connection.dart';
import 'firestore_social_errors.dart';

class FirestoreSocialMappers {
  const FirestoreSocialMappers._();

  static Map<String, Object?> connectionToMap(
    SocialConnection connection, {
    bool useServerTimestamps = false,
  }) {
    final timestamp = useServerTimestamps
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(connection.createdAt.toUtc());
    final updatedAt = useServerTimestamps
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(connection.updatedAt.toUtc());
    final connectedAt = useServerTimestamps
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(connection.connectedAt.toUtc());
    return <String, Object?>{
      'userA': connection.userAId,
      'userB': connection.userBId,
      'status': connection.status.name,
      'createdAt': timestamp,
      'updatedAt': updatedAt,
      'connectedAt': connectedAt,
      if (connection.removedAt != null)
        'removedAt': Timestamp.fromDate(connection.removedAt!.toUtc()),
      if (connection.removedBy != null) 'removedBy': connection.removedBy,
    };
  }

  static SocialConnection connectionFromMap(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final userA = _string(data, 'userA');
    final userB = _string(data, 'userB');
    final expectedId = ConnectionIdentity.forPair(userA, userB);
    if (documentId != expectedId) {
      throw _invalid('connection ID does not match its users');
    }
    final status = _enumValue(
      data,
      'status',
      SocialConnectionStatus.values,
    );
    return SocialConnection(
      connectionId: documentId,
      userAId: userA,
      userBId: userB,
      status: status,
      createdAt: _timestamp(data, 'createdAt'),
      updatedAt: _timestamp(data, 'updatedAt'),
      connectedAt: _timestamp(data, 'connectedAt'),
      removedAt: _optionalTimestamp(data, 'removedAt'),
      removedBy: _optionalString(data, 'removedBy'),
    );
  }

  static Map<String, Object?> connectionRequestToMap(
    ConnectionRequest request, {
    bool useServerTimestamps = false,
  }) {
    final createdAt = useServerTimestamps
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(request.createdAt.toUtc());
    final updatedAt = useServerTimestamps
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(request.updatedAt.toUtc());
    return <String, Object?>{
      'fromUserId': request.requesterId,
      'toUserId': request.recipientId,
      'status': request.status.name,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  static ConnectionRequest connectionRequestFromMap(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final requester = _string(data, 'fromUserId');
    final recipient = _string(data, 'toUserId');
    if (documentId !=
        ConnectionRequestIdentity.forDirection(requester, recipient)) {
      throw _invalid('connection request ID does not match its direction');
    }
    return ConnectionRequest(
      requestId: documentId,
      requesterId: requester,
      recipientId: recipient,
      status: _enumValue(data, 'status', ConnectionRequestStatus.values),
      createdAt: _timestamp(data, 'createdAt'),
      updatedAt: _timestamp(data, 'updatedAt'),
    );
  }

  static Map<String, Object?> conversationRequestToMap(
    ConversationRequest request, {
    bool useServerTimestamps = false,
  }) {
    final createdAt = useServerTimestamps
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(request.createdAt.toUtc());
    final updatedAt = useServerTimestamps
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(request.updatedAt.toUtc());
    return <String, Object?>{
      'fromUserId': request.requesterId,
      'toUserId': request.recipientId,
      'status': request.status.name,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  static ConversationRequest conversationRequestFromMap(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final requester = _string(data, 'fromUserId');
    final recipient = _string(data, 'toUserId');
    if (documentId !=
        ConversationRequestIdentity.forDirection(requester, recipient)) {
      throw _invalid('conversation request ID does not match its direction');
    }
    return ConversationRequest(
      requestId: documentId,
      requesterId: requester,
      recipientId: recipient,
      status: _enumValue(data, 'status', ConversationRequestStatus.values),
      createdAt: _timestamp(data, 'createdAt'),
      updatedAt: _timestamp(data, 'updatedAt'),
    );
  }

  static Map<String, Object?> blockToMap(
    SocialBlock block, {
    bool useServerTimestamps = false,
  }) {
    final createdAt = useServerTimestamps
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(block.createdAt.toUtc());
    final updatedAt = useServerTimestamps
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(
            (block.removedAt ?? block.createdAt).toUtc(),
          );
    return <String, Object?>{
      'blockerId': block.blockerId,
      'blockedUserId': block.blockedUserId,
      'status': block.status.name,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (block.removedAt != null)
        'removedAt': Timestamp.fromDate(block.removedAt!.toUtc()),
      if (block.removedBy != null) 'removedBy': block.removedBy,
    };
  }

  static SocialBlock blockFromMap(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final blocker = _string(data, 'blockerId');
    final blocked = _string(data, 'blockedUserId');
    if (documentId != BlockIdentity.forDirection(blocker, blocked)) {
      throw _invalid('block ID does not match its direction');
    }
    return SocialBlock(
      blockId: documentId,
      blockerId: blocker,
      blockedUserId: blocked,
      status: _enumValue(data, 'status', SocialBlockStatus.values),
      createdAt: _timestamp(data, 'createdAt'),
      removedAt: _optionalTimestamp(data, 'removedAt'),
      removedBy: _optionalString(data, 'removedBy'),
    );
  }

  static String _string(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value is! String || value.trim().isEmpty) {
      throw _invalid('missing or invalid $field');
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw _invalid('invalid $field');
    }
    return value;
  }

  static DateTime _timestamp(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value is! Timestamp) {
      throw _invalid('missing or invalid $field');
    }
    return value.toDate().toUtc();
  }

  static DateTime? _optionalTimestamp(
      Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value == null) return null;
    if (value is! Timestamp) throw _invalid('invalid $field');
    return value.toDate().toUtc();
  }

  static T _enumValue<T extends Enum>(
    Map<String, dynamic> data,
    String field,
    List<T> values,
  ) {
    final value = data[field];
    if (value is! String) throw _invalid('missing or invalid $field');
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    throw _invalid('unknown $field value');
  }

  static FirestoreSocialException _invalid(String message) =>
      FirestoreSocialException(FirestoreSocialErrorCode.invalidData, message);
}
