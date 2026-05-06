import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/wishlist_provider.dart';
import '../utils/app_error_text.dart';
import '../utils/soft_auth_gate.dart';
import 'animated_wishlist_button.dart';
import 'premium_price_row.dart';
import 'shimmer_box.dart';

class ProductCard extends StatefulWidget {
  const ProductCard({super.key, required this.product, this.onTap});

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
    final productTags = _productMetaChips(product);
    final primaryTag = productTags.isEmpty ? null : productTags.first;

    return Consumer<WishlistProvider>(
      builder: (context, wishlist, child) {
        final isWishlisted = wishlist.isWishlisted(product.id);
        final isPending = wishlist.isPending(product.id);

        return AnimatedScale(
          scale: _pressed ? 0.97 : 1,
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
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                imageUrl.isEmpty
                                    ? AnimatedScale(
                                        scale: _pressed ? 1.03 : 1,
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        child: _ProductFallbackImage(
                                          label: displayName,
                                          theme: theme,
                                        ),
                                      )
                                    : AnimatedScale(
                                        scale: _pressed ? 1.03 : 1,
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        child: CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          fadeInDuration: const Duration(
                                            milliseconds: 260,
                                          ),
                                          placeholder: (context, url) =>
                                              const ShimmerBox(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(16),
                                                ),
                                              ),
                                          errorWidget: (context, url, error) =>
                                              _ProductFallbackImage(
                                                label: displayName,
                                                theme: theme,
                                              ),
                                        ),
                                      ),
                                if (hasArTryOn)
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(
                                              alpha: 0.45,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                if (hasArTryOn)
                                  Positioned(
                                    left: 10,
                                    bottom: 10,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 6,
                                          sigmaY: 6,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.32,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.18,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            'TRY ON',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.5,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Opacity(
                                    opacity: 0.8,
                                    child: AnimatedWishlistButton(
                                      isSelected: isWishlisted,
                                      isLoading: isPending,
                                      usePremiumIntentAnimation: true,
                                      size: 28,
                                      iconSize: 17,
                                      backgroundColor: null,
                                      onTap: () async {
                                        final isAllowed =
                                            await SoftAuthGate.ensureAuthenticated(
                                              context,
                                              intentLabel: 'Save to wishlist',
                                              trigger:
                                                  AuthPromptTrigger.wishlist,
                                              productId: product.id,
                                              productPreview:
                                                  AuthPromptProductPreview(
                                                    name: product.name,
                                                    imageUrl:
                                                        product.images.isEmpty
                                                        ? null
                                                        : product.images.first,
                                                  ),
                                              promptStyle:
                                                  AuthPromptStyle.softSheet,
                                            );
                                        if (!isAllowed || !context.mounted) {
                                          return;
                                        }
                                        try {
                                          final wasWishlisted = wishlist
                                              .isWishlisted(product.id);
                                          await wishlist.toggleWishlist(
                                            product,
                                          );
                                          if (!context.mounted) {
                                            return;
                                          }
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              content: Text(
                                                wasWishlisted
                                                    ? 'Removed from Wishlist'
                                                    : 'Added to Wishlist',
                                              ),
                                              duration: const Duration(
                                                milliseconds: 1300,
                                              ),
                                            ),
                                          );
                                        } catch (error) {
                                          if (!context.mounted) {
                                            return;
                                          }
                                          if (_isAuthSessionError(error)) {
                                            await context.read<AuthProvider>().logout();
                                            if (!context.mounted) {
                                              return;
                                            }
                                            await SoftAuthGate.ensureAuthenticated(
                                              context,
                                              intentLabel: 'Save to wishlist',
                                              trigger: AuthPromptTrigger.wishlist,
                                              productId: product.id,
                                              productPreview: AuthPromptProductPreview(
                                                name: product.name,
                                                imageUrl: product.images.isEmpty
                                                    ? null
                                                    : product.images.first,
                                              ),
                                              promptStyle: AuthPromptStyle.softSheet,
                                            );
                                            return;
                                          }
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                AppErrorText.from(error),
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
                        const SizedBox(height: 8),
                        if (brandLabel.isNotEmpty)
                          Text(
                            brandLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: const Color(0xFF8A8A8A),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.15,
                            ),
                          )
                        else
                          const SizedBox(height: 14),
                        const SizedBox(height: 3),
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14.5,
                            color: const Color(0xFF111111),
                            height: 1.18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        PremiumPriceRow(
                          currentPriceLabel: _currency(product.effectivePrice),
                          originalPriceLabel: pricing.originalPrice == null
                              ? null
                              : _currency(pricing.originalPrice!),
                          discountPercent: pricing.discountPercent,
                          compact: true,
                          showLimitedOffer: false,
                        ),
                        const SizedBox(height: 6),
                        if (primaryTag != null)
                          _MetaChip(label: primaryTag)
                        else
                          const SizedBox(height: 20),
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
  const _ProductFallbackImage({required this.label, required this.theme});

  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF111111),
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
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10,
          color: const Color(0xFF8D8D8D),
          fontWeight: FontWeight.w500,
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
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
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

  const _ProductPricing({this.originalPrice, this.discountPercent = 0});
}
  bool _isAuthSessionError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('unauthorized') ||
        message.contains('session expired') ||
        message.contains('sign in again') ||
        message.contains('too many authentication requests');
  }


