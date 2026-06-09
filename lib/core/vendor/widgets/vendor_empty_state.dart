import 'package:flutter/material.dart';
import '../theme/vendor_theme.dart';
import 'vendor_buttons.dart';

class VendorEmptyState extends StatelessWidget {
  const VendorEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: VendorTheme.spacing24,
        vertical: VendorTheme.spacing32 * 1.5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(VendorTheme.spacing20),
            decoration: BoxDecoration(
              color: VendorTheme.grey100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: VendorTheme.grey400,
            ),
          ),
          const SizedBox(height: VendorTheme.spacing24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: VendorTheme.spacing8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VendorTheme.spacing24),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: VendorTheme.grey500,
                  ),
            ),
          ),
          if (primaryActionLabel != null || secondaryActionLabel != null) ...[
            const SizedBox(height: VendorTheme.spacing32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (secondaryActionLabel != null) ...[
                  VendorSecondaryButton(
                    label: secondaryActionLabel!,
                    onTap: onSecondaryAction,
                  ),
                  const SizedBox(width: VendorTheme.spacing12),
                ],
                if (primaryActionLabel != null)
                  VendorPrimaryButton(
                    label: primaryActionLabel!,
                    onTap: onPrimaryAction,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
