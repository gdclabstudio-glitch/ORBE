import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/orb_relationship.dart';
import '../models/orb_position.dart';
import '../models/social_orb.dart';

class OrbPhysicsEngine {
  const OrbPhysicsEngine({
    this.padding = 8,
    this.springStrength = 7,
    this.attractionStrength = 2.2,
    this.repulsionStrength = 5,
    this.collisionStrength = 0.75,
    this.defaultDamping = 0.92,
  });

  final double padding;
  final double springStrength;
  final double attractionStrength;
  final double repulsionStrength;
  final double collisionStrength;
  final double defaultDamping;

  List<SocialOrb> step({
    required List<SocialOrb> orbs,
    required Size size,
    double deltaSeconds = 1 / 60,
    double timeSeconds = 0,
  }) {
    if (orbs.isEmpty || size.width <= 0 || size.height <= 0) return orbs;

    final delta = deltaSeconds.clamp(0.001, 0.05).toDouble();
    final center = Offset(size.width / 2, size.height / 2);
    final next = <SocialOrb>[];

    for (int index = 0; index < orbs.length; index++) {
      final orb = orbs[index];
      if (orb.relationship == OrbRelationship.self) {
        next.add(orb.copyWith(
          position: orb.position.copyWith(
            x: center.dx,
            y: center.dy,
            distanceFromCenter: 0,
            radius: _radiusForScore(orb.score.normalized),
          ),
          physics: orb.physics.copyWith(
            velocityX: 0,
            velocityY: 0,
            targetPosition: OrbPosition(
              x: center.dx,
              y: center.dy,
              radius: _radiusForScore(orb.score.normalized),
            ),
          ),
        ));
        continue;
      }
      final target = _targetPosition(orb, center, timeSeconds);
      final current = Offset(orb.position.x, orb.position.y);
      var force = Offset(
        (target.x - current.dx) * springStrength,
        (target.y - current.dy) * springStrength,
      );

      final centralStrength = _smooth(orb.score.normalized) *
          attractionStrength *
          (orb.relationship.name == 'self' ? 0 : 1);
      force += Offset(
        (center.dx - current.dx) * centralStrength,
        (center.dy - current.dy) * centralStrength,
      );

      for (int otherIndex = 0; otherIndex < orbs.length; otherIndex++) {
        if (index == otherIndex) continue;
        final other = orbs[otherIndex];
        final difference = current - Offset(other.position.x, other.position.y);
        final distance = difference.distance;
        final minimumDistance =
            orb.position.radius + other.position.radius + padding;
        if (distance >= minimumDistance) continue;

        final direction = distance > 0
            ? difference / distance
            : _fallbackDirection(index, otherIndex);
        final overlap = minimumDistance - distance;
        final repulsion = math.min(overlap * repulsionStrength, 180).toDouble();
        force += direction * repulsion;
        force += direction * (overlap * collisionStrength / delta);
      }

      final physics = orb.physics;
      final damping = physics.damping > 0 ? physics.damping : defaultDamping;
      final velocity = Offset(physics.velocityX, physics.velocityY);
      final dampedVelocity = (velocity + force * delta) *
          math.pow(damping.clamp(0.1, 1.0), delta * 60).toDouble();
      final rawPosition = current + dampedVelocity * delta;
      final radius = _radiusForScore(orb.score.normalized);
      final boundedPosition = _keepInside(rawPosition, radius, size);

      next.add(
        orb.copyWith(
          position: orb.position.copyWith(
            x: boundedPosition.dx,
            y: boundedPosition.dy,
            radius: _approach(orb.position.radius, radius, delta * 5),
            depth: (1 - orb.score.normalized).clamp(0, 1).toDouble(),
            scale: 0.92 + orb.score.normalized * 0.08,
            distanceFromCenter: (boundedPosition - center).distance,
          ),
          physics: physics.copyWith(
            velocityX: dampedVelocity.dx,
            velocityY: dampedVelocity.dy,
            targetPosition: target,
          ),
        ),
      );
    }

    return next;
  }

  static double radiusForScore(double normalizedScore) =>
      _radiusForScore(normalizedScore);

  static OrbPosition targetForScore({
    required double normalizedScore,
    required Size size,
    required double angle,
    double microMotion = 0,
  }) {
    final score = normalizedScore.clamp(0, 1).toDouble();
    final center = Offset(size.width / 2, size.height / 2);
    final maxDistance = math.min(size.width, size.height) * 0.34;
    final distance = maxDistance * (1 - _smooth(score));
    return OrbPosition(
      x: center.dx + math.cos(angle) * distance + microMotion,
      y: center.dy + math.sin(angle) * distance + microMotion * 0.7,
      radius: _radiusForScore(score),
      angle: angle,
      distanceFromCenter: distance,
    );
  }

  OrbPosition _targetPosition(
    SocialOrb orb,
    Offset center,
    double timeSeconds,
  ) {
    final seed = (orb.metadata['seed'] as int?) ?? orb.id.hashCode.abs();
    final baseAngle = orb.position.angle == 0
        ? (seed % 360) * math.pi / 180
        : orb.position.angle;
    final direction = seed.isEven ? 1.0 : -1.0;
    final orbitalSpeed =
        (0.045 + (1 - orb.score.normalized.clamp(0, 1)) * 0.035) * direction;
    final angle = baseAngle + timeSeconds * orbitalSpeed;
    final phase = (seed % 17) * 0.37;
    final microMotion = math.sin(timeSeconds * 0.7 + phase) * 1.8;
    return targetForScore(
      normalizedScore: orb.score.normalized,
      size: Size(center.dx * 2, center.dy * 2),
      angle: angle,
      microMotion: microMotion,
    );
  }

  static double _smooth(double value) => value * value * (3 - 2 * value);

  static double _radiusForScore(double normalizedScore) {
    final score = normalizedScore.clamp(0, 1).toDouble();
    return (38 + _smooth(score) * 42) / 2;
  }

  static double _approach(double current, double target, double amount) =>
      current + (target - current) * amount.clamp(0, 1);

  static Offset _fallbackDirection(int first, int second) {
    final angle = ((first * 31 + second * 17) % 360) * math.pi / 180;
    return Offset(math.cos(angle), math.sin(angle));
  }

  static Offset _keepInside(Offset position, double radius, Size size) {
    return Offset(
      position.dx.clamp(radius, math.max(radius, size.width - radius)),
      position.dy.clamp(radius, math.max(radius, size.height - radius)),
    );
  }
}
