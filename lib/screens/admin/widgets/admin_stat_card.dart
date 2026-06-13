import 'package:flutter/material.dart';
import '../../../theme.dart';

class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.trend,
    this.trendUp = true,
  });

  final String title;
  final String value;
  final IconData? icon;
  final String? trend;
  final bool trendUp;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AbzioTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: context.abzioText.labelMedium?.copyWith(
                      color: context.abzioSecondaryText,
                    ),
                  ),
                ),
                if (icon != null)
                  Icon(icon, size: 20, color: AbzioTheme.accentColor),
              ],
            ),
            const SizedBox(height: AbzioTheme.spacing12),
            Text(
              value,
              style: context.abzioText.headlineLarge,
            ),
            if (trend != null) ...[
              const SizedBox(height: AbzioTheme.spacing8),
              Row(
                children: [
                  Icon(
                    trendUp ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: trendUp ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trend!,
                    style: context.abzioText.bodySmall?.copyWith(
                      color: trendUp ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}
