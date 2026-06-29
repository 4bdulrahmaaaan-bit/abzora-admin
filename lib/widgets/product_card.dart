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
import 'shimmer_box.dart';

class ProductCard extends StatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.storeLabel,
    this.badgeLabel,
  });

  final Product product;
  final VoidCallback? onTap;
  final String? storeLabel;
  final String? badgeLabel;

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
    final hasArTryOn = product.tryOnAvailable;
    final theme = Theme.of(context);
    final ratingOverlayLabel = _ratingLabel(product.rating);
    final deliveryLabel = _deliveryLabel(product);
    final badgeLabel = widget.badgeLabel?.trim() ?? '';

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
                borderRadius: BorderRadius.circular(24),
                child: Ink(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFB89A57).withValues(alpha: 0.18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.028),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 9,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
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
                                                  Radius.circular(20),
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
                                              alpha: 0.16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  left: 8,
                                  top: 8,
                                  child: _GlassRatingPill(
                                    label: ratingOverlayLabel,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.12,
                                          ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: AnimatedWishlistButton(
                                      isSelected: isWishlisted,
                                      isLoading: isPending,
                                      usePremiumIntentAnimation: true,
                                      size: 32,
                                      iconSize: 18,
                                      backgroundColor: null,
                                      selectedColor: const Color(0xFFC8A44D),
                                      unselectedColor: Colors.white,
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
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
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
                                            await context
                                                .read<AuthProvider>()
                                                .logout();
                                            if (!context.mounted) {
                                              return;
                                            }
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
                                if (hasArTryOn)
                                  Positioned(
                                    left: 10,
                                    bottom: 10,
                                    child: _GlassTryOnPill(
                                      label: badgeLabel.isNotEmpty
                                          ? badgeLabel.toUpperCase()
                                          : 'TRY ON',
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
                              fontSize: 12,
                              color: const Color(0xFF766B5D),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.02,
                            ),
                          )
                        else
                          const SizedBox(height: 12),
                        const SizedBox(height: 4),
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 17,
                            color: const Color(0xFF14110E),
                            height: 1.16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.05,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _PriceBlock(
                          currentPriceLabel: _currency(product.effectivePrice),
                          originalPriceLabel: pricing.originalPrice == null
                              ? null
                              : _currency(pricing.originalPrice!),
                          discountPercent: pricing.discountPercent,
                        ),
                        const SizedBox(height: 8),
                        _ServiceBadge(
                          label: deliveryLabel,
                          icon: Icons.local_shipping_rounded,
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

class _ServiceBadge extends StatelessWidget {
  const _ServiceBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7EF),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFB89A57).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF7B5B27)),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF6B5A3A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassRatingPill extends StatelessWidget {
  const _GlassRatingPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star_rounded,
                size: 12,
                color: Color(0xFFC2A15E),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF111111),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassTryOnPill extends StatelessWidget {
  const _GlassTryOnPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt_rounded,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({
    required this.currentPriceLabel,
    this.originalPriceLabel,
    this.discountPercent = 0,
  });

  final String currentPriceLabel;
  final String? originalPriceLabel;
  final int discountPercent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          currentPriceLabel,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 21,
            height: 1.0,
            color: const Color(0xFF111111),
            fontWeight: FontWeight.w800,
          ),
        ),
        if (originalPriceLabel != null)
          Text(
            originalPriceLabel!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF9C9C9C),
              decoration: TextDecoration.lineThrough,
              fontWeight: FontWeight.w500,
            ),
          ),
        if (discountPercent > 0)
          Text(
            '$discountPercent% OFF',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFFC2A15E),
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
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

String _displayName(Product product) {
  final name = product.name.trim();
  return name.isEmpty ? 'Product' : name;
}

String _ratingLabel(double rating) {
  final safeRating = rating > 0 ? rating : 4.7;
  return safeRating.toStringAsFixed(1);
}

String _deliveryLabel(Product product) {
  final delivery = product.deliveryInfo;
  final sameDay =
      _boolFrom(delivery['sameDayAvailable']) ||
      _boolFrom(delivery['sameDayEligible']) ||
      _boolFrom(product.sameDayAvailable);
  if (sameDay) {
    return '? Same Day';
  }
  final tryAtHome =
      _boolFrom(delivery['tryAtHomeAvailable']) ||
      _boolFrom(delivery['tryAtHomeEligible']) ||
      _boolFrom(product.tryAtHomeAvailable);
  if (tryAtHome) {
    return '📍 Nearby Store';
  }
  final eta =
      delivery['etaHours'] ?? delivery['eta'] ?? delivery['deliveryEta'];
  if (eta is num && eta > 0) {
    final hours = eta.round();
    return hours == 1 ? '⚡ 1-Hour Delivery' : '⚡ $hours-Hour Delivery';
  }
  if (eta is String && eta.trim().isNotEmpty) {
    return eta.trim();
  }
  return '📍 Nearby Store';
}

bool _boolFrom(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == 'yes' || normalized == '1';
  }
  return false;
}

String _currency(double value) {
  final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20B9',
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
