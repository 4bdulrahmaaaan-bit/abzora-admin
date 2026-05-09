import 'dart:math' as math;

import 'package:flutter/material.dart';

class RiderParticleBackground extends StatelessWidget {
  const RiderParticleBackground({super.key, required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ParticlePainter(progress),
      size: Size.infinite,
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (int i = 0; i < 55; i++) {
      final t = i / 55;
      final x = (t * size.width + math.sin(progress * 5 + i) * 16) % size.width;
      final y = ((1 - t) * size.height + progress * (20 + i % 8)) % size.height;
      p.color = const Color(
        0xFFFF6B00,
      ).withValues(alpha: 0.05 + (i % 5) * 0.015);
      canvas.drawCircle(Offset(x, y), 1.2 + (i % 3), p);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
