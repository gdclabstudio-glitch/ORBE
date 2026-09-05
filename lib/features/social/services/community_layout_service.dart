import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/community_node.dart';
import '../models/community_node_social_orb.dart';
import '../models/orb_relationship.dart';
import '../models/social_orb.dart';

class CommunityLayoutService {
  static List<CommunityNode> layoutNodes({
    required List<CommunityNode> nodes,
    required Size size,
  }) {
    final orbs = nodes.map((node) => node.toSocialOrb()).toList();
    final positionedOrbs = layoutOrbs(orbs: orbs, size: size);
    return [
      for (int index = 0; index < nodes.length; index++)
        nodes[index].copyWith(
          position: Offset(
            positionedOrbs[index].position.x,
            positionedOrbs[index].position.y,
          ),
          size: positionedOrbs[index].position.radius * 2,
          distance: positionedOrbs[index].position.distanceFromCenter,
          rotation: positionedOrbs[index].position.angle,
        ),
    ];
  }

  static List<SocialOrb> layoutOrbs({
    required List<SocialOrb> orbs,
    required Size size,
  }) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.38;
    final positioned = <SocialOrb>[];

    for (int index = 0; index < orbs.length; index++) {
      final orb = orbs[index];
      final isCenter = orb.relationship == OrbRelationship.self;
      if (isCenter) {
        positioned.add(orb.copyWith(
          position: orb.position.copyWith(
            x: center.dx,
            y: center.dy,
            radius: 43,
            distanceFromCenter: 0,
          ),
        ));
        continue;
      }

      final normalized = orb.score.normalized;
      final baseDistance = (1 - normalized) * maxRadius;
      final seed = (orb.metadata['seed'] as int?) ?? orb.id.hashCode.abs();
      final angle = _angleForNode(seed, index, orbs.length);
      final radialVariance = ((seed % 11) - 5) * 8.0;
      final dx = math.cos(angle) * (baseDistance + radialVariance);
      final dy = math.sin(angle) * (baseDistance + radialVariance * 0.75);

      final x = (center.dx + dx).clamp(size.width * 0.12, size.width * 0.88);
      final y = (center.dy + dy).clamp(size.height * 0.14, size.height * 0.86);

      positioned.add(orb.copyWith(
        position: orb.position.copyWith(
          x: x,
          y: y,
          distanceFromCenter: baseDistance,
          angle: angle,
        ),
      ));
    }

    return positioned;
  }

  static double _angleForNode(int seed, int index, int total) {
    final base = (seed % 360) / 360.0;
    final offset = (index / math.max(1, total)) * (math.pi * 2);
    return base * (math.pi * 2) + offset;
  }
}
