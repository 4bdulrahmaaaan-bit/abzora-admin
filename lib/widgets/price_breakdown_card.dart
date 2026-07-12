import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

class PriceBreakdownCard extends StatelessWidget {
  const PriceBreakdownCard({
    super.key,
    required this.originalSubtotal,
    required this.dynamicSubtotal,
    required this.discount,
    required this.tax,
    required this.shippingCharge,
    required this.customCharge,
    required this.walletCredit,
    required this.total,
    required this.formatter,
    this.taxRate = 0,
    this.isLegacyOrder = false,
  });

  final double originalSubtotal;
  final double dynamicSubtotal;
  final double discount;
  final double tax;
  final double shippingCharge;
  final double customCharge;
  final double walletCredit;
  final double total;
  final NumberFormat formatter;
  final double taxRate;
  final bool isLegacyOrder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Column(
        children: [
          PriceLine(
            label: 'Base Price',
            value: formatter.format(originalSubtotal),
          ),
          if ((dynamicSubtotal - originalSubtotal).abs() > 0.01) ...[
            const SizedBox(height: 6),
            PriceLine(
              label: 'Dynamic Price',
              value: formatter.format(dynamicSubtotal),
              valueColor: dynamicSubtotal < originalSubtotal
                  ? const Color(0xFF218B5B)
                  : null,
            ),
          ],
          if ((dynamicSubtotal - originalSubtotal).abs() <= 0.01) ...[
            const SizedBox(height: 6),
            PriceLine(
              label: 'Subtotal',
              value: formatter.format(dynamicSubtotal),
            ),
          ],
          const SizedBox(height: 6),
          PriceLine(
            label: 'Delivery fee',
            value: shippingCharge > 0 ? formatter.format(shippingCharge) : 'Free',
          ),
          if (customCharge > 0) ...[
            const SizedBox(height: 6),
            PriceLine(
              label: 'Custom fit service',
              value: formatter.format(customCharge),
            ),
          ],
          if (discount > 0) ...[
            const SizedBox(height: 6),
            PriceLine(
              label: 'Discount',
              value: '- ${formatter.format(discount)}',
              valueColor: const Color(0xFF218B5B),
            ),
          ],
          if (walletCredit > 0) ...[
            const SizedBox(height: 6),
            PriceLine(
              label: 'Abianzo Credits',
              value: '- ${formatter.format(walletCredit)}',
              valueColor: const Color(0xFF218B5B),
            ),
          ],
          const SizedBox(height: 6),
          if (isLegacyOrder)
            _LegacyTaxNotice()
          else
            PriceLine(
              label: taxRate > 0
                  ? 'GST (${taxRate % 1 == 0 ? taxRate.toInt().toString() : taxRate.toStringAsFixed(1)}%) included'
                  : 'Tax included',
              value: formatter.format(tax),
              isInformational: true,
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          PriceLine(
            label: 'Total amount',
            value: formatter.format(total),
            isTotal: true,
          ),
        ],
      ),
    );
  }
}

class PriceLine extends StatelessWidget {
  const PriceLine({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.isTotal = false,
    this.isInformational = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isTotal;
  final bool isInformational;

  @override
  Widget build(BuildContext context) {
    final style = isTotal
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w800)
        : isInformational
            ? Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: context.abzioSecondaryText,
                )
            : Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style?.copyWith(color: valueColor),
        ),
      ],
    );
  }
}

class _LegacyTaxNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.info_outline, size: 14, color: context.abzioSecondaryText),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Tax breakdown unavailable for this order',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: context.abzioSecondaryText,
                ),
          ),
        ),
      ],
    );
  }
}
