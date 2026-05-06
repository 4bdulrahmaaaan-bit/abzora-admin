import 'package:flutter/material.dart';

class PremiumPriceRow extends StatelessWidget {
  const PremiumPriceRow({
    super.key,
    required this.currentPriceLabel,
    this.originalPriceLabel,
    this.discountPercent = 0,
    this.compact = false,
    this.showLimitedOffer = true,
  });

  final String currentPriceLabel;
  final String? originalPriceLabel;
  final int discountPercent;
  final bool compact;
  final bool showLimitedOffer;

  @override
  Widget build(BuildContext context) {
    final currentSize = compact ? 20.0 : 31.0;
    final oldStyle = (compact
            ? Theme.of(context).textTheme.bodySmall
            : Theme.of(context).textTheme.bodyMedium)
        ?.copyWith(
          color: const Color(0xFFA8A8A8),
          decoration: TextDecoration.lineThrough,
          fontWeight: FontWeight.w500,
        );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: compact ? 6 : 8,
      runSpacing: 6,
      children: [
        Text(
          currentPriceLabel,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontSize: currentSize,
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
        if (originalPriceLabel != null)
          Text(originalPriceLabel!, style: oldStyle),
        if (discountPercent > 0)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 7 : 9,
              vertical: compact ? 3 : 4,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF3E3),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$discountPercent% off',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFFC6A96B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (showLimitedOffer && discountPercent > 40)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 3 : 4,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF6EAD2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Limited Offer',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF9C7A3C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

