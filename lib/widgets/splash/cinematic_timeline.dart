import 'package:flutter/material.dart';

/// Helper methods for readable stagger intervals and phase-based easing.
class SplashTimeline {
  const SplashTimeline._();

  static Animation<double> segment({
    required Animation<double> parent,
    required double begin,
    required double end,
    Curve curve = Curves.easeInOutCubic,
  }) {
    return CurvedAnimation(
      parent: parent,
      curve: Interval(begin, end, curve: curve),
    );
  }

  static double value(
    Animation<double> animation,
    double begin,
    double end, {
    Curve curve = Curves.easeInOutCubic,
  }) {
    final t = ((animation.value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(t);
  }
}

class CinematicVignette extends StatelessWidget {
  const CinematicVignette({super.key, this.opacity = 0.55});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.95,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: opacity * 0.38),
              Colors.black.withValues(alpha: opacity),
            ],
            stops: const [0.45, 0.78, 1.0],
          ),
        ),
      ),
    );
  }
}
