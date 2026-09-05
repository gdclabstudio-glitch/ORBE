import 'package:flutter/material.dart';

import '../../../theme/la_bomba_design_system.dart';

class UniverseBackdropPainter extends CustomPainter {
  const UniverseBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    for (int index = 0; index < 18; index++) {
      final seed = (index * 47 + 19) % 97;
      final point = Offset(
        (seed * 7.31) % size.width,
        (seed * 11.17) % size.height,
      );
      final distance = (point - center).distance;
      final alpha = (0.025 + (distance / size.longestSide) * 0.035)
          .clamp(0.02, 0.06)
          .toDouble();
      paint.color = (index.isEven
              ? LaBombaColors.digitalBlue
              : LaBombaColors.primary)
          .withValues(alpha: alpha);
      canvas.drawCircle(point, index.isEven ? 1.1 : 0.75, paint);
    }
  }

  @override
  bool shouldRepaint(covariant UniverseBackdropPainter oldDelegate) => false;
}
