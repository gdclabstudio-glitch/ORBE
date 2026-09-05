import '../../models/social_community.dart';
import 'community_membership.dart';

abstract class CommunityService {
  Future<SocialCommunity> createCommunity({
    required String ownerId,
    required String name,
    String? description,
  });

  Future<SocialCommunity> updateCommunity(SocialCommunity community);

  Future<CommunityMembership> joinCommunity({
    required String userId,
    required String communityId,
  });

  Future<CommunityMembership> leaveCommunity({
    required String userId,
    required String communityId,
  });

  Future<CommunityMembership> approveMembership({
    required String actorId,
    required String membershipId,
  });

  Future<CommunityMembership> removeMember({
    required String actorId,
    required String membershipId,
  });

  Future<CommunityMembership> changeMemberRole({
    required String actorId,
    required String membershipId,
    required CommunityMemberRole role,
  });
}
