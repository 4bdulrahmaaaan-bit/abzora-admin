import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/wishlist_provider.dart';
import '../theme.dart';
import 'animated_wishlist_button.dart';
import 'shimmer_box.dart';

class ProductCard extends StatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  final Product product;
  final VoidCallback? onTap;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.product.images.isEmpty ? '' : widget.product.images.first;
    final pricing = _pricingFor(widget.product);
    final theme = Theme.of(context);

    return Consumer<WishlistProvider>(
      builder: (context, wishlist, child) {
        final isWishlisted = wishlist.isWishlisted(widget.product.id);
        final isPending = wishlist.isPending(widget.product.id);

        return AnimatedScale(
          scale: _pressed ? 0.985 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (value) {
                if (_pressed == value) {
                  return;
                }
                setState(() => _pressed = value);
              },
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.abzioBorder.withValues(alpha: 0.8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 0.9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  border: Border.all(color: context.abzioBorder.withValues(alpha: 0.4)),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  fadeInDuration: const Duration(milliseconds: 260),
                                  placeholder: (context, url) => const ShimmerBox(
                                    borderRadius: BorderRadius.all(Radius.circular(16)),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: theme.cardColor,
                                    padding: const EdgeInsets.all(16),
                                    alignment: Alignment.center,
                                    child: Text(
                                      widget.product.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                              ),
                              if (pricing.discountPercent > 0)
                                Positioned(
                                  left: 10,
                                  top: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE64553),
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFE64553).withValues(alpha: 0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '-${pricing.discountPercent}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: AnimatedWishlistButton(
                                  isSelected: isWishlisted,
                                  isLoading: isPending,
                                  onTap: () async {
                                    try {
                                      await wishlist.toggleWishlist(widget.product);
                                    } catch (error) {
                                      if (!context.mounted) {
                                        return;
                                      }
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _brandName(widget.product),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF191919),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF666666),
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            _currency(widget.product.effectivePrice),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF121212),
                            ),
                          ),
                          if (pricing.originalPrice != null)
                            Text(
                              _currency(pricing.originalPrice!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF8A8A8A),
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (pricing.discountPercent > 0)
                            Text(
                              '${pricing.discountPercent}% OFF',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF218B5B),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          if (widget.product.isLimitedStock)
                            Text(
                              'LIMITED STOCK',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFB54708),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _brandName(Product product) {
  final raw = product.storeId.replaceAll('_', ' ').trim();
  if (raw.isEmpty) {
    return 'ABZORA';
  }
  return raw
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

String _currency(double value) {
  final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  return formatter.format(value);
}

_ProductPricing _pricingFor(Product product) {
  final currentPrice = product.effectivePrice;
  final originalPrice =
      (product.basePrice != null && product.basePrice! > currentPrice)
          ? product.basePrice
          : product.originalPrice;
  if (originalPrice == null || originalPrice <= currentPrice) {
    return const _ProductPricing();
  }
  final discountPercent =
      (((originalPrice - currentPrice) / originalPrice) * 100).round();
  return _ProductPricing(
    originalPrice: originalPrice,
    discountPercent: discountPercent,
  );
}

class _ProductPricing {
  final double? originalPrice;
  final int discountPercent;

  const _ProductPricing({
    this.originalPrice,
    this.discountPercent = 0,
  });
}
