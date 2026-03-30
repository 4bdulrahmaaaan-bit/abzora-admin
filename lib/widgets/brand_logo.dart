import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  final double radius;
  final Color backgroundColor;
  final EdgeInsets padding;
  final List<BoxShadow> shadows;
  final Gradient? gradient;
  final String assetPath;

  const BrandLogo({
    super.key,
    this.size = 88,
    this.radius = 24,
    this.backgroundColor = Colors.transparent,
    this.padding = const EdgeInsets.all(4),
    this.shadows = const [],
    this.gradient,
    this.assetPath = 'assets/branding/abzora_customer_icon.png',
  });

  const BrandLogo.hero({
    super.key,
    this.size = 144,
    this.radius = 34,
    this.backgroundColor = const Color(0xFF050505),
    this.padding = const EdgeInsets.all(5),
    this.shadows = const [
      BoxShadow(
        color: Color(0x33D4AF37),
        blurRadius: 28,
        spreadRadius: 1,
        offset: Offset(0, 12),
      ),
      BoxShadow(
        color: Color(0x14000000),
        blurRadius: 18,
        offset: Offset(0, 6),
      ),
    ],
    this.gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0E0E0E),
        Color(0xFF030303),
      ],
    ),
    this.assetPath = 'assets/branding/abzora_customer_icon.png',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? backgroundColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
