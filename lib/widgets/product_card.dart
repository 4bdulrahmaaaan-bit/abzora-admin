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
    final product = widget.product;
    final displayName = _displayName(product);
    final brandLabel = _brandName(product);
    final imageUrl = product.images.isEmpty ? '' : product.images.first;
    final pricing = _pricingFor(product);
    final hasArTryOn =
        (product.model3d ?? '').trim().isNotEmpty || product.arAsset.isNotEmpty;
    final theme = Theme.of(context);

    return Consumer<WishlistProvider>(
      builder: (context, wishlist, child) {
        final isWishlisted = wishlist.isWishlisted(product.id);
        final isPending = wishlist.isPending(product.id);

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
                borderRadius: BorderRadius.circular(22),
                child: Ink(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDF9),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFEEE6D8)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E1405).withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                DecoratedBox(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFF6F1E7),
                                        Color(0xFFEDE4D3),
                                      ],
                                    ),
                                  ),
                                  child: imageUrl.isEmpty
                                      ? _ProductFallbackImage(
                                          label: displayName,
                                          theme: theme,
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          fadeInDuration:
                                              const Duration(milliseconds: 260),
                                          placeholder: (context, url) =>
                                              const ShimmerBox(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(18),
                                                ),
                                              ),
                                          errorWidget: (context, url, error) =>
                                              _ProductFallbackImage(
                                                label: displayName,
                                                theme: theme,
                                              ),
                                        ),
                                ),
                                if (pricing.discountPercent > 0)
                                  Positioned(
                                    left: 10,
                                    top: 10,
                                    child: _FloatingPill(
                                      backgroundColor:
                                          const Color(0xFF10281D).withValues(
                                        alpha: 0.92,
                                      ),
                                      foregroundColor:
                                          const Color(0xFFF5F2E9),
                                      label:
                                          '${pricing.discountPercent}% OFF',
                                    ),
                                  ),
                                if (hasArTryOn)
                                  const Positioned(
                                    left: 10,
                                    bottom: 10,
                                    child: _FloatingPill(
                                      backgroundColor: Color(0xFFC8A95B),
                                      foregroundColor: Color(0xFF23180C),
                                      label: 'TRY ON',
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
                                        await wishlist.toggleWishlist(product);
                                      } catch (error) {
                                        if (!context.mounted) {
                                          return;
                                        }
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              error
                                                  .toString()
                                                  .replaceFirst(
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
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (brandLabel.isNotEmpty)
                          Text(
                            brandLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10.5,
                              color: const Color(0xFF8C6A12),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.45,
                            ),
                          ),
                        if (brandLabel.isNotEmpty) const SizedBox(height: 4),
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13.5,
                            color: const Color(0xFF16120D),
                            height: 1.18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _productMetaChips(product)
                              .map((label) => _MetaChip(label: label))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                _currency(product.effectivePrice),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 15,
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
                                    color: const Color(0xFF9B9385),
                                    decoration: TextDecoration.lineThrough,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (pricing.discountPercent > 0) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${pricing.discountPercent}% OFF',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF0D8A43),
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

class _ProductFallbackImage extends StatelessWidget {
  const _ProductFallbackImage({
    required this.label,
    required this.theme,
  });

  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3ECDF),
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF2B2116),
        ),
      ),
    );
  }
}

class _FloatingPill extends StatelessWidget {
  const _FloatingPill({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.label,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFE2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: const Color(0xFF6F5A2B),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

String _brandName(Product product) {
  final raw = product.brand.trim();
  if (raw.isEmpty) {
    return '';
  }
  return raw
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map(
        (part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

List<String> _productMetaChips(Product product) {
  final category = product.category.trim();
  final fit = product.outfitType?.trim() ?? '';
  final chips = <String>[
    if (category.isNotEmpty) category,
    if (fit.isNotEmpty) fit,
  ];
  if (chips.isEmpty) {
    chips.addAll(const ['Verified seller', 'Easy returns']);
  } else if (chips.length == 1) {
    chips.add('Easy returns');
  }
  return chips.take(2).toList();
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
