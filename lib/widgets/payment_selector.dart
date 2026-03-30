import 'package:flutter/material.dart';

import '../theme.dart';

class PaymentSelector extends StatelessWidget {
  const PaymentSelector({
    super.key,
    required this.selectedMethod,
    required this.onChanged,
  });

  final String? selectedMethod;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PaymentOptionCard(
          icon: Icons.payments_outlined,
          title: 'Cash on Delivery',
          subtitle: 'Pay after your order arrives',
          value: 'COD',
          selectedValue: selectedMethod,
          onTap: onChanged,
        ),
        const SizedBox(height: 12),
        _PaymentOptionCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Razorpay',
          subtitle: 'UPI, cards and net banking',
          value: 'RAZORPAY',
          selectedValue: selectedMethod,
          onTap: onChanged,
        ),
      ],
    );
  }
}

class _PaymentOptionCard extends StatelessWidget {
  const _PaymentOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.selectedValue,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String? selectedValue;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = selectedValue == value;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AbzioTheme.accentColor : context.abzioBorder,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected ? context.abzioShadow : const [],
        ),
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: selected
                    ? AbzioTheme.accentColor.withValues(alpha: 0.16)
                    : context.abzioMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: selected ? AbzioTheme.accentColor : context.abzioSecondaryText,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.abzioSecondaryText,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 22,
              width: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AbzioTheme.accentColor : Colors.transparent,
                border: Border.all(
                  color: selected ? AbzioTheme.accentColor : context.abzioBorder,
                  width: 1.4,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
