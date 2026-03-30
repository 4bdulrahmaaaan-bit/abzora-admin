import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blurRate;
  final double opacity;
  final double borderRadius;
  final Border? border;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const GlassContainer({
    super.key,
    required this.child,
    this.blurRate = 18.0,
    this.opacity = 0.65,
    this.borderRadius = 24.0,
    this.border,
    this.padding = const EdgeInsets.all(0),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = color ?? (isDark ? Colors.black : Colors.white);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurRate, sigmaY: blurRate),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ?? Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
