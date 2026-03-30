import 'package:flutter/material.dart';

import 'shimmer_widget.dart';

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius is BorderRadius ? (borderRadius as BorderRadius).topLeft.x : 0.0;
    return ShimmerWidget(
      width: width,
      height: height,
      radius: radius,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF222222) : const Color(0xFFE4E4E4),
          borderRadius: borderRadius ?? BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
