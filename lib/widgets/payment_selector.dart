import 'package:flutter/material.dart';

import '../theme.dart';
import 'abzio_motion.dart';

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
          icon: Icons.qr_code_2_rounded,
          title: 'UPI',
          subtitle: 'Google Pay, PhonePe, Paytm, BHIM',
          badge: 'Recommended',
          value: 'UPI',
          selectedValue: selectedMethod,
          onTap: onChanged,
        ),
        const SizedBox(height: 12),
        _PaymentOptionCard(
          icon: Icons.credit_card_rounded,
          title: 'Credit / Debit Card',
          subtitle: 'Visa \u2022 Mastercard \u2022 RuPay',
          value: 'CARDS',
          selectedValue: selectedMethod,
          onTap: onChanged,
        ),
        const SizedBox(height: 12),
        _PaymentOptionCard(
          icon: Icons.payments_outlined,
          title: 'Cash on Delivery',
          subtitle: 'Pay when your order arrives.',
          value: 'COD',
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
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String? selectedValue;
  final String? badge;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = selectedValue == value;

    return Semantics(
      button: true,
      selected: selected,
      label: '$title, $subtitle${badge != null ? ', $badge' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(value),
          borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
          child: AnimatedContainer(
            duration: AbzioMotion.medium,
            curve: AbzioMotion.curve,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFCDAE58), Color(0xFFB88D31)],
                    )
                  : null,
              color: selected ? null : Colors.white,
              borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
              border: Border.all(
                color: selected
                    ? const Color(0xFFE1C97F)
                    : const Color(0xFFE9E1D2),
              ),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? const Color(0xFFB88D31).withValues(alpha: 0.16)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: selected ? 22 : 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 52,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.16)
                        : const Color(0xFFF6F1E4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? Colors.white : AbzioTheme.accentColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: selected
                                        ? Colors.white
                                        : AbzioTheme.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white.withValues(alpha: 0.18)
                                    : AbzioTheme.accentColor.withValues(
                                        alpha: 0.09,
                                      ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badge!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: selected
                                          ? Colors.white
                                          : AbzioTheme.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.90)
                              : context.abzioSecondaryText,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.arrow_forward_ios_rounded,
                  size: selected ? 20 : 16,
                  color: selected ? Colors.white : AbzioTheme.accentColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
