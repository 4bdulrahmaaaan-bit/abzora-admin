import 'package:flutter/material.dart';

/// Cinematic metallic sweep that moves across the logo to simulate reflection.
class LogoShimmerSweep extends StatelessWidget {
  const LogoShimmerSweep({
    super.key,
    required this.progress,
    required this.size,
    this.borderRadius = 28,
  });

  final double progress;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final sweep = Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Transform.translate(
          offset: Offset((sweep * 2 - 1) * size, 0),
          child: Container(
            width: size * 0.9,
            height: size,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Color(0x11FFE2A9),
                  Color(0x99FFD57A),
                  Color(0x11FFE2A9),
                  Colors.transparent,
                ],
                stops: [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
