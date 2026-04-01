import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/wishlist_provider.dart';
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
    final displayName = _displayName(widget.product);
    final imageUrl = widget.product.images.isEmpty
        ? ''
        : widget.product.images[0];
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
          child: RepaintBoundary(
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
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                DecoratedBox(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF5F5F5),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    fadeInDuration:
                                        const Duration(milliseconds: 260),
                                    placeholder: (context, url) =>
                                        const ShimmerBox(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(14),
                                          ),
                                        ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: const Color(0xFFF5F5F5),
                                          padding: const EdgeInsets.all(16),
                                          alignment: Alignment.center,
                                          child: Text(
                                            displayName,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                  ),
                                ),
                                if (pricing.discountPercent > 0)
                                  Positioned(
                                    left: 10,
                                    top: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.92,
                                        ),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '${pricing.discountPercent}% OFF',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF159947),
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
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.94,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.08,
                                          ),
                                          blurRadius: 14,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: AnimatedWishlistButton(
                                      isSelected: isWishlisted,
                                      isLoading: isPending,
                                      onTap: () async {
                                        try {
                                          await wishlist.toggleWishlist(
                                            widget.product,
                                          );
                                        } catch (error) {
                                          if (!context.mounted) {
                                            return;
                                          }
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                error.toString().replaceFirst(
                                                  'Bad state: ',
                                                  '',
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _brandName(widget.product),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8A8A8A),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.45,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF161616),
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _currency(widget.product.price),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF121212),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (pricing.originalPrice != null)
                              Flexible(
                                child: Text(
                                  _currency(pricing.originalPrice!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF9A9A9A),
                                    decoration: TextDecoration.lineThrough,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (pricing.discountPercent > 0)
                              Flexible(
                                child: Text(
                                  '${pricing.discountPercent}% OFF',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF159947),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            if (widget.product.rating > 0) ...[
                              if (pricing.discountPercent > 0)
                                const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F4F4),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: Color(0xFFC9A74E),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.product.rating.toStringAsFixed(1),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFF1A1A1A),
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (widget.product.isLimitedStock) ...[
                              const Spacer(),
                              Flexible(
                                child: Text(
                                  'LIMITED',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFFB54708),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
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
  final raw = product.brand.trim();
  if (raw.isEmpty) {
    return 'ABZORA';
  }
  return raw
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

String _displayName(Product product) {
  final name = product.name.trim();
  return name.isEmpty ? 'Product' : name;
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
