import 'dart:math' as math;

class OrbPosition {
  const OrbPosition({
    this.x = 0,
    this.y = 0,
    this.radius = 0,
    this.depth = 0,
    this.scale = 1,
    this.angle = 0,
    this.distanceFromCenter = 0,
  });

  final double x;
  final double y;
  final double radius;
  final double depth;
  final double scale;
  final double angle;
  final double distanceFromCenter;

  OrbPosition copyWith({
    double? x,
    double? y,
    double? radius,
    double? depth,
    double? scale,
    double? angle,
    double? distanceFromCenter,
  }) {
    return OrbPosition(
      x: x ?? this.x,
      y: y ?? this.y,
      radius: radius ?? this.radius,
      depth: depth ?? this.depth,
      scale: scale ?? this.scale,
      angle: angle ?? this.angle,
      distanceFromCenter: distanceFromCenter ?? this.distanceFromCenter,
    );
  }

  double get distance => math.sqrt(x * x + y * y);
}
