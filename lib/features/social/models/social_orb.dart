import 'interaction_score.dart';
import 'orb_physics.dart';
import 'orb_position.dart';
import 'orb_relationship.dart';
import 'orb_type.dart';

class SocialOrb {
  const SocialOrb({
    required this.id,
    required this.type,
    this.title,
    this.imageUrl,
    this.score = const InteractionScore(),
    this.position = const OrbPosition(),
    this.relationship = OrbRelationship.unknown,
    this.activity = 0,
    this.metadata = const <String, Object?>{},
    this.physics = const OrbPhysics(),
  });

  final String id;
  final OrbType type;
  final String? title;
  final String? imageUrl;
  final InteractionScore score;
  final OrbPosition position;
  final OrbRelationship relationship;
  final double activity;
  final Map<String, Object?> metadata;
  final OrbPhysics physics;

  SocialOrb copyWith({
    String? id,
    OrbType? type,
    String? title,
    String? imageUrl,
    InteractionScore? score,
    OrbPosition? position,
    OrbRelationship? relationship,
    double? activity,
    Map<String, Object?>? metadata,
    OrbPhysics? physics,
  }) {
    return SocialOrb(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      score: score ?? this.score,
      position: position ?? this.position,
      relationship: relationship ?? this.relationship,
      activity: activity ?? this.activity,
      metadata: metadata ?? this.metadata,
      physics: physics ?? this.physics,
    );
  }
}
