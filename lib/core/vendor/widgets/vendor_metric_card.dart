import 'package:flutter/material.dart';
import '../theme/vendor_theme.dart';
import 'premium_vendor_card.dart';

class VendorMetricCard extends StatelessWidget {
  const VendorMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.trend,
    this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final double? trend; // Positive for up, negative for down, null for neutral
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumVendorCard(
      padding: const EdgeInsets.all(VendorTheme.spacing20),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              if (icon != null)
                Icon(
                  icon,
                  size: 16,
                  color: VendorTheme.grey400,
                ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (trend != null) ...[
            const SizedBox(height: VendorTheme.spacing8),
            Row(
              children: [
                Icon(
                  trend! >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 14,
                  color: trend! >= 0 ? VendorTheme.success : VendorTheme.error,
                ),
                const SizedBox(width: VendorTheme.spacing4),
                Text(
                  '${trend! > 0 ? '+' : ''}${trend!.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: trend! >= 0 ? VendorTheme.success : VendorTheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: VendorTheme.spacing4),
                Text(
                  'vs yesterday',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: VendorTheme.grey500,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
