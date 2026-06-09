import 'package:flutter/material.dart';
import '../theme/vendor_theme.dart';

class PremiumVendorCard extends StatelessWidget {
  const PremiumVendorCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(VendorTheme.spacing24),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.backgroundColor,
    this.hasBorder = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? VendorTheme.card,
        borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
        border: hasBorder ? Border.all(color: VendorTheme.grey200) : null,
        boxShadow: hasBorder ? null : VendorTheme.softShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return Padding(
        padding: margin,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
            hoverColor: VendorTheme.primary.withValues(alpha: 0.02),
            highlightColor: VendorTheme.primary.withValues(alpha: 0.04),
            splashColor: VendorTheme.primary.withValues(alpha: 0.06),
            child: Ink(
              decoration: BoxDecoration(
                color: backgroundColor ?? VendorTheme.card,
                borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
                border: hasBorder ? Border.all(color: VendorTheme.grey200) : null,
                boxShadow: hasBorder ? null : VendorTheme.softShadow,
              ),
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: margin,
      child: cardContent,
    );
  }
}
