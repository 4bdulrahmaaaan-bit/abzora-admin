import 'dart:ui';

import 'package:flutter/material.dart';

/// Reusable glow halo used for logo bloom and center spark atmosphere.
class PulsingGoldGlow extends StatelessWidget {
  const PulsingGoldGlow({
    super.key,
    required this.radius,
    required this.opacity,
    this.scale = 1,
  });

  final double radius;
  final double opacity;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.scale(
        scale: scale,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: radius * 0.16,
            sigmaY: radius * 0.16,
          ),
          child: Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0xFFD6A65D).withValues(alpha: 0.34 * opacity),
                  Color(0xFFC89343).withValues(alpha: 0.2 * opacity),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
