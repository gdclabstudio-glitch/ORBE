import '../domain/community/community_membership.dart';
import '../domain/community/community_pagination.dart';
import '../domain/community/community_read_service.dart';
import '../domain/community/community_repository.dart';
import '../models/social_community.dart';

class FirestoreCommunityReadService implements CommunityReadService {
  const FirestoreCommunityReadService(this._repository);

  final CommunityRepository _repository;

  @override
  Future<SocialCommunity?> getCommunity(String communityId) =>
      _repository.getCommunity(communityId);

  @override
  Future<CommunityPage<SocialCommunity>> listCommunities({
    CommunityPageRequest page = const CommunityPageRequest(),
  }) =>
      _repository.listCommunities(page: page);

  @override
  Future<CommunityPage<SocialCommunity>> listUserCommunities({
    required String userId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) =>
      _repository.listUserCommunities(userId: userId, page: page);

  @override
  Future<bool> isMember({
    required String userId,
    required String communityId,
  }) =>
      _repository.isMember(userId: userId, communityId: communityId);

  @override
  Future<CommunityMembership?> getMembership({
    required String userId,
    required String communityId,
  }) =>
      _repository.getMembership(userId: userId, communityId: communityId);

  @override
  Future<CommunityPage<CommunityMembership>> listMembers({
    required String communityId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) =>
      _repository.listMembers(communityId: communityId, page: page);

  @override
  Future<CommunityPage<SocialCommunity>> listCommunitiesByTopic({
    required String topicId,
    CommunityPageRequest page = const CommunityPageRequest(),
  }) =>
      _repository.listCommunitiesByTopic(topicId: topicId, page: page);
}
