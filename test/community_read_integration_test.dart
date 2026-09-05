import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/domain/community/community_membership.dart';
import 'package:labomba_app/features/social/domain/community/community_pagination.dart';
import 'package:labomba_app/features/social/infrastructure/firestore_community_read_service.dart';
import 'package:labomba_app/features/social/infrastructure/firestore_community_repository.dart';
import 'package:labomba_app/features/social/models/orb_membership.dart';
import 'package:labomba_app/features/social/models/orb_type.dart';
import 'package:labomba_app/features/social/models/social_community.dart';
import 'package:labomba_app/features/social/models/social_orb.dart';
import 'package:labomba_app/features/social/projections/community_universe_projection.dart';

void main() {
  test('read service forwards repository reads and preserves pagination',
      () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('communities').doc('music').set({
      'name': 'Music',
    });
    final service = FirestoreCommunityReadService(
      FirestoreCommunityRepository(firestore: firestore),
    );

    final page = await service.listCommunities(
      page: const CommunityPageRequest(limit: 10),
    );

    expect(page.items.single.id, 'music');
    expect(page.nextCursor, isNull);
    expect(await service.getMembership(userId: 'u1', communityId: 'music'),
        isNull);
  });

  test('projects a community without inventing member Orbs', () {
    const community = SocialCommunity(
      id: 'music',
      name: 'Music',
      description: 'Shared sound',
    );
    const center = SocialOrb(id: 'music', type: OrbType.community);

    final empty = CommunityUniverseProjection.fromCommunity(
      community: community,
      center: center,
    );

    expect(empty.type.name, 'community');
    expect(empty.contextId, 'music');
    expect(empty.orbs, isEmpty);
    expect(empty.memberships, isEmpty);
  });

  test('adapts persisted membership to contextual OrbMembership', () {
    final membership = CommunityMembership(
      membershipId: 'membership',
      communityId: 'music',
      userId: 'u1',
      role: CommunityMemberRole.member,
      status: CommunityMembershipStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

    final contextual = CommunityMembershipOrbAdapter.fromMembership(membership);

    expect(contextual.orbId, 'u1');
    expect(contextual.contextId, 'music');
    expect(contextual.kind, OrbMembershipKind.membership);
    expect(contextual.label, 'member');
  });

  test('does not project inactive memberships', () {
    final membership = CommunityMembership(
      membershipId: 'membership',
      communityId: 'music',
      userId: 'u1',
      role: CommunityMemberRole.member,
      status: CommunityMembershipStatus.pending,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

    final universe = CommunityUniverseProjection.fromCommunity(
      community: const SocialCommunity(id: 'music', name: 'Music'),
      center: const SocialOrb(id: 'music', type: OrbType.community),
      memberships: [membership],
    );

    expect(universe.memberships, isEmpty);
  });
}
