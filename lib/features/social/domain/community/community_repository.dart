import '../../models/social_community.dart';
import 'community_membership.dart';
import 'community_pagination.dart';

abstract class CommunityRepository {
  Future<SocialCommunity?> getCommunity(String communityId);

  Future<CommunityPage<SocialCommunity>> listCommunities({
    CommunityPageRequest page = const CommunityPageRequest(),
  });

  Future<CommunityPage<SocialCommunity>> listUserCommunities({
    required String userId,
    CommunityPageRequest page = const CommunityPageRequest(),
  });

  Future<bool> isMember({
    required String userId,
    required String communityId,
  });

  Future<CommunityMembership?> getMembership({
    required String userId,
    required String communityId,
  });

  Future<CommunityPage<CommunityMembership>> listMembers({
    required String communityId,
    CommunityPageRequest page = const CommunityPageRequest(),
  });

  Future<CommunityPage<SocialCommunity>> listCommunitiesByTopic({
    required String topicId,
    CommunityPageRequest page = const CommunityPageRequest(),
  });
}
