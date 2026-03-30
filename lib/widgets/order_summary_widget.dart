import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../providers/cart_provider.dart';
import '../theme.dart';

class OrderSummaryWidget extends StatelessWidget {
  const OrderSummaryWidget({
    super.key,
    required this.items,
  });

  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OrderItemCard(item: item),
            ),
          )
          .toList(),
    );
  }
}

class _OrderItemCard extends StatelessWidget {
  const _OrderItemCard({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = item.product.images.isNotEmpty ? item.product.images.first : '';
    final metaLabel = item.product.category.trim().isNotEmpty ? item.product.category : 'ABZORA Edit';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: imageUrl.isEmpty
                ? Container(
                    height: 92,
                    width: 88,
                    color: context.abzioMuted,
                    child: Icon(Icons.checkroom_outlined, color: context.abzioSecondaryText),
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 92,
                    width: 88,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: context.abzioMuted,
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: context.abzioMuted,
                      child: Icon(Icons.broken_image_outlined, color: context.abzioSecondaryText),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metaLabel.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(height: 1.2),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _InfoPill(label: 'Qty ${item.quantity}'),
                    if (item.size.trim().isNotEmpty) _InfoPill(label: 'Size ${item.size}'),
                    if (item.product.isCustomTailoring) const _InfoPill(label: 'Custom'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Rs ${(item.product.price * item.quantity).toStringAsFixed(0)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.abzioMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
