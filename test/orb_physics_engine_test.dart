import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/features/social/models/interaction_score.dart';
import 'package:labomba_app/features/social/models/orb_physics.dart';
import 'package:labomba_app/features/social/models/orb_position.dart';
import 'package:labomba_app/features/social/models/orb_relationship.dart';
import 'package:labomba_app/features/social/models/orb_type.dart';
import 'package:labomba_app/features/social/models/social_orb.dart';
import 'package:labomba_app/features/social/services/orb_physics_engine.dart';

SocialOrb orb(
  String id, {
  double score = 50,
  double x = 100,
  double y = 100,
  double radius = 20,
  double velocityX = 0,
  OrbRelationship relationship = OrbRelationship.unknown,
}) {
  return SocialOrb(
    id: id,
    type: OrbType.person,
    score: InteractionScore(socialRelevance: score),
    relationship: relationship,
    position: OrbPosition(x: x, y: y, radius: radius, angle: 0),
    physics: OrbPhysics(
      damping: 0.8,
      velocityX: velocityX,
      targetPosition: OrbPosition(x: x, y: y),
    ),
    metadata: <String, Object?>{'seed': id.hashCode.abs()},
  );
}

void main() {
  const engine = OrbPhysicsEngine();
  const size = Size(400, 400);

  group('OrbPhysicsEngine', () {
    test('handles zero and one orb deterministically', () {
      expect(engine.step(orbs: const [], size: size), isEmpty);
      final result = engine.step(
        orbs: [orb('one', x: 100, y: 100)],
        size: size,
      );

      expect(result, hasLength(1));
      expect(result.single.position.x.isFinite, isTrue);
      expect(result.single.position.y.isFinite, isTrue);
    });

    test('keeps the self orb fixed at the center', () {
      final result = engine.step(
        orbs: [
          orb(
            'self',
            x: 30,
            y: 40,
            relationship: OrbRelationship.self,
          ),
        ],
        size: size,
      ).single;

      expect(result.position.x, 200);
      expect(result.position.y, 200);
      expect(result.physics.velocityX, 0);
      expect(result.physics.velocityY, 0);
    });

    test('attracts an orb toward its score-based target', () {
      final low = engine.step(
        orbs: [orb('same-seed', score: 0, x: 200, y: 50)],
        size: size,
      ).single;
      final high = engine.step(
        orbs: [orb('same-seed', score: 100, x: 200, y: 50)],
        size: size,
      ).single;

      expect(high.position.distanceFromCenter,
          lessThan(low.position.distanceFromCenter));
      expect(high.physics.targetPosition.distanceFromCenter,
          lessThan(low.physics.targetPosition.distanceFromCenter));
    });

    test('repels overlapping orbs and applies collision correction', () {
      final result = engine.step(
        orbs: [
          orb('a', x: 180, y: 200),
          orb('b', x: 185, y: 200),
        ],
        size: size,
      );

      expect(result[0].position.x, lessThan(180));
      expect(result[1].position.x, greaterThan(185));
    });

    test('damping reduces existing velocity', () {
      final result = engine.step(
        orbs: [orb('moving', x: 200, y: 200, velocityX: 60)],
        size: size,
      ).single;

      expect(result.physics.velocityX.abs(), lessThan(60));
    });

    test('spring moves toward a changed target without teleporting', () {
      final initial = orb('spring', x: 50, y: 200).copyWith(
        physics: const OrbPhysics(
          spring: 10,
          targetPosition: OrbPosition(x: 350, y: 200),
        ),
      );
      final result = engine.step(orbs: [initial], size: size).single;

      expect(result.position.x, greaterThan(50));
      expect(result.position.x, lessThan(350));
    });

    test('gives non-center orbs a subtle deterministic orbital drift', () {
      final initial = orb('orbiting', x: 100, y: 200).copyWith(
        position: const OrbPosition(
          x: 100,
          y: 200,
          angle: 0.8,
          radius: 20,
        ),
      );
      final first = engine.step(
        orbs: [initial],
        size: size,
        timeSeconds: 0,
      ).single;
      final later = engine.step(
        orbs: [initial],
        size: size,
        timeSeconds: 10,
      ).single;

      expect(later.physics.targetPosition.angle, isNot(first.physics.targetPosition.angle));
      expect(later.position.x, isNot(first.position.x));
    });

    test('score maps to smooth radius values and clamps extremes', () {
      expect(OrbPhysicsEngine.radiusForScore(0), 19);
      expect(OrbPhysicsEngine.radiusForScore(1), 40);
      expect(OrbPhysicsEngine.radiusForScore(-10), 19);
      expect(OrbPhysicsEngine.radiusForScore(10), 40);
    });

    test('returns unchanged input for invalid dimensions', () {
      final input = [orb('invalid')];
      expect(engine.step(orbs: input, size: Size.zero), same(input));
    });
  });
}
