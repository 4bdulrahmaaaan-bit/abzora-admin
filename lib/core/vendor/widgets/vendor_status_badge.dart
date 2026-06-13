import 'package:flutter/material.dart';
import '../theme/vendor_theme.dart';

enum VendorBadgeType { success, warning, error, info, neutral }

class VendorStatusBadge extends StatelessWidget {
  const VendorStatusBadge({
    super.key,
    required this.label,
    this.type = VendorBadgeType.neutral,
    this.icon,
  });

  final String label;
  final VendorBadgeType type;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    switch (type) {
      case VendorBadgeType.success:
        backgroundColor = VendorTheme.success.withValues(alpha: 0.1);
        textColor = VendorTheme.success;
        break;
      case VendorBadgeType.warning:
        backgroundColor = VendorTheme.warning.withValues(alpha: 0.1);
        textColor = VendorTheme.warning;
        break;
      case VendorBadgeType.error:
        backgroundColor = VendorTheme.error.withValues(alpha: 0.1);
        textColor = VendorTheme.error;
        break;
      case VendorBadgeType.info:
        backgroundColor = VendorTheme.info.withValues(alpha: 0.1);
        textColor = VendorTheme.info;
        break;
      case VendorBadgeType.neutral:
        backgroundColor = VendorTheme.grey200;
        textColor = VendorTheme.grey700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VendorTheme.spacing12,
        vertical: VendorTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: VendorTheme.spacing4),
          ],
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
