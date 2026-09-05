import 'orb_position.dart';

class OrbPhysics {
  const OrbPhysics({
    this.attraction = 0,
    this.repulsion = 0,
    this.collision = 0,
    this.damping = 0.9,
    this.spring = 0,
    this.velocityX = 0,
    this.velocityY = 0,
    this.targetPosition = const OrbPosition(),
  });

  final double attraction;
  final double repulsion;
  final double collision;
  final double damping;
  final double spring;
  final double velocityX;
  final double velocityY;
  final OrbPosition targetPosition;

  OrbPhysics copyWith({
    double? attraction,
    double? repulsion,
    double? collision,
    double? damping,
    double? spring,
    double? velocityX,
    double? velocityY,
    OrbPosition? targetPosition,
  }) {
    return OrbPhysics(
      attraction: attraction ?? this.attraction,
      repulsion: repulsion ?? this.repulsion,
      collision: collision ?? this.collision,
      damping: damping ?? this.damping,
      spring: spring ?? this.spring,
      velocityX: velocityX ?? this.velocityX,
      velocityY: velocityY ?? this.velocityY,
      targetPosition: targetPosition ?? this.targetPosition,
    );
  }
}
