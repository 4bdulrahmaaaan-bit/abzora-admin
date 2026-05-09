import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RiderGlowButton extends StatelessWidget {
  const RiderGlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B00).withValues(alpha: 0.38),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: const Color(0xFFFF6B00),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fade(duration: 900.ms, begin: 0.86, end: 1);
  }
}
