enum SocialBlockStatus { active, removed }

class SocialBlock {
  final String blockId;
  final String blockerId;
  final String blockedUserId;
  final SocialBlockStatus status;
  final DateTime createdAt;
  final DateTime? removedAt;
  final String? removedBy;

  SocialBlock({
    required this.blockId,
    required this.blockerId,
    required this.blockedUserId,
    required this.status,
    required this.createdAt,
    this.removedAt,
    this.removedBy,
  }) {
    _requireBlockValue(blockId, 'blockId');
    _requireBlockValue(blockerId, 'blockerId');
    _requireBlockValue(blockedUserId, 'blockedUserId');
    if (blockerId == blockedUserId) {
      throw ArgumentError('blockerId and blockedUserId must differ');
    }
    if (status == SocialBlockStatus.active &&
        (removedAt != null || removedBy != null)) {
      throw ArgumentError('active blocks cannot have removal data');
    }
    if (status == SocialBlockStatus.removed &&
        (removedAt == null || removedBy == null || removedBy!.trim().isEmpty)) {
      throw ArgumentError('removed blocks require removal data');
    }
  }
}

void _requireBlockValue(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError('$name must not be empty');
  }
}
