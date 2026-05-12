import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints lightweight floating gold dust particles for the cinematic background.
class GoldDustParticleLayer extends StatefulWidget {
  const GoldDustParticleLayer({
    super.key,
    required this.progress,
    this.density = 70,
  });

  final double progress;
  final int density;

  @override
  State<GoldDustParticleLayer> createState() => _GoldDustParticleLayerState();
}

class _GoldDustParticleLayerState extends State<GoldDustParticleLayer> {
  late final List<_ParticleSeed> _particles;

  @override
  void initState() {
    super.initState();
    final random = math.Random(42);
    _particles = List<_ParticleSeed>.generate(
      widget.density,
      (index) => _ParticleSeed(
        x: random.nextDouble(),
        y: random.nextDouble(),
        radius: 0.6 + random.nextDouble() * 1.8,
        speed: 0.12 + random.nextDouble() * 0.45,
        drift: (random.nextDouble() - 0.5) * 0.09,
        twinkle: random.nextDouble() * math.pi * 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _GoldDustPainter(
          progress: widget.progress,
          particles: _particles,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _GoldDustPainter extends CustomPainter {
  _GoldDustPainter({required this.progress, required this.particles});

  final double progress;
  final List<_ParticleSeed> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final reveal = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));

    for (final particle in particles) {
      final yTravel =
          ((particle.y + progress * particle.speed) % 1.0) * size.height;
      final xWave =
          math.sin((progress * 2.8) + particle.twinkle) *
          (size.width * particle.drift);
      final x = particle.x * size.width + xWave;
      final twinkle =
          0.55 + (math.sin(progress * 10 + particle.twinkle) * 0.45);
      final alpha = (85 * reveal * twinkle).clamp(0, 255).toInt();

      paint.color = Color.fromARGB(alpha, 241, 200, 112);
      canvas.drawCircle(Offset(x, yTravel), particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GoldDustPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.particles != particles;
  }
}

class _ParticleSeed {
  const _ParticleSeed({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.drift,
    required this.twinkle,
  });

  final double x;
  final double y;
  final double radius;
  final double speed;
  final double drift;
  final double twinkle;
}
