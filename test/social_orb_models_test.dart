import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/models/community_node.dart';
import 'package:labomba_app/features/social/models/community_node_social_orb.dart';
import 'package:labomba_app/features/social/models/interaction_score.dart';
import 'package:labomba_app/features/social/models/orb_position.dart';
import 'package:labomba_app/features/social/models/orb_relationship.dart';
import 'package:labomba_app/features/social/models/orb_type.dart';

void main() {
  group('ORBE social orb models', () {
    test('exposes the planned orb types', () {
      expect(
          OrbType.values,
          containsAll([
            OrbType.person,
            OrbType.group,
            OrbType.event,
            OrbType.content,
          ]));
    });

    test('calculates score total, normalization, and priority', () {
      const score = InteractionScore(
        socialRelevance: 20,
        interactionFrequency: 30,
        relationshipStrength: 40,
        activity: 20,
        recency: 10,
        presence: 10,
      );

      expect(score.total, 100);
      expect(score.normalized, 1);
      expect(score.priority, 1);
      expect(const InteractionScore().total, 0);
    });

    test('clamps extreme scores and handles invalid max score', () {
      const high = InteractionScore(socialRelevance: 1000);
      const low = InteractionScore(socialRelevance: -1000);
      const invalid = InteractionScore(socialRelevance: 10, maxScore: 0);

      expect(high.total, 100);
      expect(low.total, 0);
      expect(invalid.normalized, 0);
    });

    test('keeps relationship states explicit', () {
      expect(OrbRelationship.values, contains(OrbRelationship.unknown));
      expect(OrbRelationship.values, contains(OrbRelationship.closeFriend));
    });

    test('keeps position data independent from Firebase', () {
      const position = OrbPosition(
        x: 12,
        y: 16,
        radius: 20,
        angle: 1.5,
        distanceFromCenter: 20,
      );

      expect(position.distance, 20);
      expect(position.copyWith(scale: 0.8).scale, 0.8);
    });

    test('converts a community node to a person orb', () {
      const node = CommunityNode(
        uid: 'user-1',
        displayName: 'Alice',
        avatarUrl: 'https://example.com/alice.png',
        isOnline: true,
        isCloseFriend: true,
        isCurrentUser: false,
        hasStory: true,
        status: 'Available',
        interactionScore: 75,
        normalizedScore: 0.75,
        size: 70,
        distance: 100,
        rotation: 0.4,
        position: Offset(40, 50),
        seed: 42,
      );

      final orb = node.toSocialOrb();

      expect(orb.id, 'user-1');
      expect(orb.type, OrbType.person);
      expect(orb.title, 'Alice');
      expect(orb.relationship, OrbRelationship.closeFriend);
      expect(orb.position.radius, 35);
      expect(orb.position.x, 40);
      expect(orb.metadata['seed'], 42);
    });
  });
}
