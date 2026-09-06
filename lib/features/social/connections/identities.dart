import 'dart:convert';

import 'package:crypto/crypto.dart';

const socialIdentityVersion = 'v1';

class ConnectionIdentity {
  const ConnectionIdentity._();

  static String forPair(String firstUserId, String secondUserId) {
    final ids = _validatedPair(firstUserId, secondUserId)..sort();
    return _digest('connection', ids);
  }
}

class ConnectionRequestIdentity {
  const ConnectionRequestIdentity._();

  static String forDirection(String requesterId, String recipientId) {
    _validateDistinct(requesterId, recipientId);
    return _digest('connection_request', [
      requesterId.trim(),
      recipientId.trim(),
    ]);
  }
}

class ConversationRequestIdentity {
  const ConversationRequestIdentity._();

  static String forDirection(String requesterId, String recipientId) {
    _validateDistinct(requesterId, recipientId);
    return _digest('conversation_request', [
      requesterId.trim(),
      recipientId.trim(),
    ]);
  }
}

class BlockIdentity {
  const BlockIdentity._();

  static String forDirection(String blockerId, String blockedUserId) {
    _validateDistinct(blockerId, blockedUserId);
    return _digest('block', [blockerId.trim(), blockedUserId.trim()]);
  }
}

List<String> _validatedPair(String first, String second) {
  _validateDistinct(first, second);
  return [first.trim(), second.trim()];
}

void _validateDistinct(String first, String second) {
  if (first.isEmpty || second.isEmpty || first.trim() != first || second.trim() != second) {
    throw ArgumentError('identity components must not be empty');
  }
  if (first == second) {
    throw ArgumentError('identity components must differ');
  }
  if (first.runes.length > 128 || second.runes.length > 128) {
    throw ArgumentError('identity components exceed the Firebase Auth UID limit');
  }
}

String _digest(String purpose, List<String> participants) {
  final tuple = jsonEncode([
    socialIdentityVersion,
    purpose,
    ...participants,
  ]);
  return sha256.convert(utf8.encode(tuple)).toString();
}
