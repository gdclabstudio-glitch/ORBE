enum CommunityMemberRole {
  owner,
  admin,
  moderator,
  member,
}

enum CommunityMembershipStatus {
  active,
  pending,
  blocked,
  left,
}

class CommunityMembership {
  CommunityMembership({
    required this.membershipId,
    required this.communityId,
    required this.userId,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  }) {
    _validate();
  }

  final String membershipId;
  final String communityId;
  final String userId;
  final CommunityMemberRole role;
  final CommunityMembershipStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == CommunityMembershipStatus.active;

  CommunityMembership copyWith({
    String? membershipId,
    String? communityId,
    String? userId,
    CommunityMemberRole? role,
    CommunityMembershipStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommunityMembership(
      membershipId: membershipId ?? this.membershipId,
      communityId: communityId ?? this.communityId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  void _validate() {
    if (membershipId.trim().isEmpty) {
      throw ArgumentError.value(
          membershipId, 'membershipId', 'Cannot be empty');
    }
    if (communityId.trim().isEmpty) {
      throw ArgumentError.value(communityId, 'communityId', 'Cannot be empty');
    }
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Cannot be empty');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError.value(
        updatedAt,
        'updatedAt',
        'Cannot be earlier than createdAt',
      );
    }
  }
}
