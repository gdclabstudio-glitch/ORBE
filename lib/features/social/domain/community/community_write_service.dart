import '../../models/social_community.dart';
import 'community_membership.dart';

abstract class CommunityWriteService {
  Future<SocialCommunity> createCommunity({
    required String name,
    String? description,
  });

  Future<CommunityMembership> joinCommunity({
    required String communityId,
  });
}
