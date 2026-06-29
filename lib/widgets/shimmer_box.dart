import 'package:flutter/material.dart';

import 'shimmer_widget.dart';

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration period;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
    this.period = const Duration(milliseconds: 1350),
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius is BorderRadius
        ? (borderRadius as BorderRadius).topLeft.x
        : 0.0;
    return ShimmerWidget(
      width: width,
      height: height,
      radius: radius,
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: period,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor ??
              (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF222222)
                  : const Color(0xFFECE8E1)),
          borderRadius: borderRadius ?? BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
