import 'package:flutter/material.dart';
import '../theme/vendor_theme.dart';

class VendorPrimaryButton extends StatelessWidget {
  const VendorPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: VendorTheme.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: VendorTheme.grey300,
        disabledForegroundColor: VendorTheme.grey500,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: VendorTheme.spacing24,
          vertical: VendorTheme.spacing16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: VendorTheme.spacing8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class VendorSecondaryButton extends StatelessWidget {
  const VendorSecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: VendorTheme.grey100,
        foregroundColor: VendorTheme.primary,
        disabledBackgroundColor: VendorTheme.grey100,
        disabledForegroundColor: VendorTheme.grey400,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: VendorTheme.spacing24,
          vertical: VendorTheme.spacing16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(VendorTheme.primary),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: VendorTheme.spacing8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class VendorOutlinedButton extends StatelessWidget {
  const VendorOutlinedButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: isLoading ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: VendorTheme.primary,
        side: const BorderSide(color: VendorTheme.grey300, width: 1.5),
        disabledForegroundColor: VendorTheme.grey400,
        padding: const EdgeInsets.symmetric(
          horizontal: VendorTheme.spacing24,
          vertical: VendorTheme.spacing16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(VendorTheme.primary),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: VendorTheme.spacing8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
