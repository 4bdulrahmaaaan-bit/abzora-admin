import 'package:flutter/material.dart';

class PremiumButton extends StatelessWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = true,
    this.isLoading = false,
    this.disabled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool isLoading;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: disabled || isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: filled ? const Color(0xFFC9A55A) : Colors.white,
        foregroundColor: filled ? Colors.white : const Color(0xFF111111),
        elevation: 0,
        minimumSize: const Size(double.infinity, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: filled ? Colors.transparent : const Color(0xFFE5E5E5),
            width: 1.5,
          ),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
    );
  }
}
