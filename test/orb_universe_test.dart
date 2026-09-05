import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/models/orb_membership.dart';
import 'package:labomba_app/features/social/models/orb_relationship.dart';
import 'package:labomba_app/features/social/models/orb_type.dart';
import 'package:labomba_app/features/social/models/orb_universe.dart';
import 'package:labomba_app/features/social/models/social_orb.dart';
import 'package:labomba_app/features/social/models/universe_stack.dart';
import 'package:labomba_app/features/social/models/universe_type.dart';
import 'package:labomba_app/features/social/models/social_community.dart';
import 'package:labomba_app/features/social/models/social_topic.dart';

SocialOrb person(String id, String title) => SocialOrb(
      id: id,
      type: OrbType.person,
      title: title,
      relationship: id == 'me' ? OrbRelationship.self : OrbRelationship.unknown,
    );

void main() {
  group('OrbUniverse', () {
    test('creates a personal universe with an explicit center', () {
      final universe = OrbUniverse.personal(
        center: person('me', 'Gustavo'),
        orbs: [person('friend', 'Friend')],
      );

      expect(universe.type, UniverseType.personal);
      expect(universe.center.id, 'me');
      expect(universe.orbs, hasLength(1));
      expect(universe.isEmpty, isFalse);
      expect(universe.containsOrb('friend'), isTrue);
    });

    test('supports empty and multiple universes', () {
      final empty = OrbUniverse(
        id: 'physics',
        type: UniverseType.community,
        title: 'Física',
        center: person('physics', 'Física'),
      );

      expect(empty.isEmpty, isTrue);
      expect(empty.hasMultipleOrbs, isFalse);
      expect(empty.containsOrb('missing'), isFalse);
    });

    test('keeps community, topic, and universe distinct', () {
      const topic = SocialTopic(
        id: 'topic-test',
        title: 'Relatividade',
      );
      const community = SocialCommunity(
        id: 'community-test',
        name: 'Fisica',
        topic: topic,
      );
      final membership = const OrbMembership(
        orbId: 'member-test',
        contextId: 'community-test',
        kind: OrbMembershipKind.membership,
      );
      final universe = OrbUniverse.community(
        center: person('community-test', community.name),
        communityId: community.id,
        title: community.name,
        memberships: [membership],
      );

      expect(topic.id, isNot(community.id));
      expect(universe.type, UniverseType.community);
      expect(universe.contextId, community.id);
      expect(universe.membershipFor('member-test')!.kind,
          OrbMembershipKind.membership);
      expect(community.toMap()['topic'], isA<Map<String, Object?>>());
    });

    test('creates topic and group universes with contextual centers', () {
      final topicUniverse = OrbUniverse.topic(
        center: person('topic-test', 'Relatividade'),
        topicId: 'topic-test',
        title: 'Relatividade',
      );
      final groupUniverse = OrbUniverse.group(
        center: person('group-test', 'Grupo de Estudos'),
        groupId: 'group-test',
        title: 'Grupo de Estudos',
      );

      expect(topicUniverse.type, UniverseType.topic);
      expect(topicUniverse.center.id, 'topic-test');
      expect(groupUniverse.type, UniverseType.group);
      expect(groupUniverse.contextId, 'group-test');
    });
  });

  group('UniverseStack', () {
    final root = OrbUniverse.personal(center: person('me', 'Meu Universo'));
    final child = OrbUniverse(
      id: 'physics',
      type: UniverseType.community,
      title: 'Física',
      center: person('physics', 'Física'),
    );

    test('pushes and pops universes in order', () {
      final stack = const UniverseStack().push(root).push(child);

      expect(stack.depth, 2);
      expect(stack.current!.id, 'physics');
      expect(stack.canGoBack, isTrue);
      expect(stack.pop().current!.id, 'me');
    });

    test('does not pop the root universe', () {
      final stack = UniverseStack([root]);

      expect(stack.pop().depth, 1);
      expect(stack.clear().current, isNull);
    });

    test('supports direct breadcrumb navigation and exposes the parent', () {
      final topic = OrbUniverse.topic(
        center: person('topic', 'Relatividade'),
        topicId: 'topic',
        title: 'Relatividade',
        parentId: 'physics',
      );
      final stack = UniverseStack([root, child, topic]);

      expect(stack.parent!.id, 'physics');
      expect(stack.popTo(1).current!.id, 'physics');
      expect(stack.popTo(99).depth, 3);
    });
  });
}
