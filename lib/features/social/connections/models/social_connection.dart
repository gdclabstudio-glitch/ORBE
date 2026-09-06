enum SocialConnectionStatus { connected, removed }

class SocialConnection {
  final String connectionId;
  final String userAId;
  final String userBId;
  final SocialConnectionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime connectedAt;
  final DateTime? removedAt;
  final String? removedBy;

  SocialConnection({
    required this.connectionId,
    required this.userAId,
    required this.userBId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.connectedAt,
    this.removedAt,
    this.removedBy,
  }) {
    _requireConnectionValue(connectionId, 'connectionId');
    _requireConnectionValue(userAId, 'userAId');
    _requireConnectionValue(userBId, 'userBId');
    if (userAId.compareTo(userBId) >= 0) {
      throw ArgumentError('userAId must be lexicographically less than userBId');
    }
    if (updatedAt.isBefore(createdAt) || connectedAt.isBefore(createdAt)) {
      throw ArgumentError('connection timestamps are inconsistent');
    }
    if (status == SocialConnectionStatus.connected &&
        (removedAt != null || removedBy != null)) {
      throw ArgumentError('connected connections cannot have removal data');
    }
    if (status == SocialConnectionStatus.removed &&
        (removedAt == null || removedBy == null || removedBy!.trim().isEmpty)) {
      throw ArgumentError('removed connections require removal data');
    }
  }
}

void _requireConnectionValue(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError('$name must not be empty');
  }
}
