class MembershipIdentity {
  const MembershipIdentity._();

  /// Stable local key with encoded components to prevent separator collisions.
  static String forPair({
    required String communityId,
    required String userId,
  }) {
    final community = communityId.trim();
    final user = userId.trim();
    if (community.isEmpty) {
      throw ArgumentError.value(communityId, 'communityId', 'Cannot be empty');
    }
    if (user.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Cannot be empty');
    }
    return '${Uri.encodeComponent(community)}::${Uri.encodeComponent(user)}';
  }
}
