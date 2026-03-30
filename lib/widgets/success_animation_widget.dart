import 'package:flutter/material.dart';

import '../theme.dart';

class SuccessAnimationWidget extends StatefulWidget {
  const SuccessAnimationWidget({super.key});

  @override
  State<SuccessAnimationWidget> createState() => _SuccessAnimationWidgetState();
}

class _SuccessAnimationWidgetState extends State<SuccessAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _checkScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.85, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      width: 170,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              ..._particles(),
              Opacity(
                opacity: _fade.value,
                child: Transform.scale(
                  scale: 0.86 + (_scale.value * 0.14),
                  child: Container(
                    height: 152,
                    width: 152,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AbzioTheme.accentColor.withValues(alpha: 0.18),
                          AbzioTheme.accentColor.withValues(alpha: 0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: _scale.value,
                child: Container(
                  height: 112,
                  width: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AbzioTheme.accentColor,
                    boxShadow: [
                      BoxShadow(
                        color: AbzioTheme.accentColor.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Transform.scale(
                      scale: _checkScale.value,
                      child: const Icon(
                        Icons.check_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _particles() {
    const specs = [
      _ParticleSpec(top: 14, left: 48, size: 10, dx: -6, dy: -10),
      _ParticleSpec(top: 24, right: 26, size: 8, dx: 8, dy: -8),
      _ParticleSpec(bottom: 28, left: 20, size: 7, dx: -8, dy: 8),
      _ParticleSpec(bottom: 18, right: 38, size: 12, dx: 10, dy: 12),
    ];

    return specs
        .map(
          (spec) => Positioned(
            top: spec.top,
            left: spec.left,
            right: spec.right,
            bottom: spec.bottom,
            child: Opacity(
              opacity: _fade.value,
              child: Transform.translate(
                offset: Offset(spec.dx * (1 - _fade.value), spec.dy * (1 - _fade.value)),
                child: Container(
                  height: spec.size,
                  width: spec.size,
                  decoration: BoxDecoration(
                    color: AbzioTheme.accentColor.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        )
        .toList();
  }
}

class _ParticleSpec {
  const _ParticleSpec({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.dx,
    required this.dy,
  });

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final double dx;
  final double dy;
}
