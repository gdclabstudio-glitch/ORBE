import '../domain/community/community_membership.dart';
import '../models/orb_membership.dart';
import '../models/orb_universe.dart';
import '../models/social_community.dart';
import '../models/social_orb.dart';

class CommunityMembershipOrbAdapter {
  const CommunityMembershipOrbAdapter._();

  static OrbMembership fromMembership(CommunityMembership membership) {
    return OrbMembership(
      orbId: membership.userId,
      contextId: membership.communityId,
      kind: OrbMembershipKind.membership,
      label: membership.role.name,
    );
  }
}

class CommunityUniverseProjection {
  const CommunityUniverseProjection._();

  static OrbUniverse fromCommunity({
    required SocialCommunity community,
    required SocialOrb center,
    List<SocialOrb> memberOrbs = const <SocialOrb>[],
    List<CommunityMembership> memberships = const <CommunityMembership>[],
  }) {
    return OrbUniverse.community(
      center: center,
      communityId: community.id,
      title: community.name,
      subtitle: community.description,
      orbs: List.unmodifiable(memberOrbs),
      memberships: List.unmodifiable(
        memberships
            .where((membership) => membership.isActive)
            .map(CommunityMembershipOrbAdapter.fromMembership),
      ),
    );
  }
}
