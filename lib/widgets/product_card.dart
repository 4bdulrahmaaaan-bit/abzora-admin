import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../models/delivery_serviceability.dart';
import '../providers/auth_provider.dart';
import '../providers/wishlist_provider.dart';
import '../services/delivery_service.dart';
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
    this.deliveryAddress,
  });

  final Product product;
  final VoidCallback? onTap;
  final String? storeLabel;
  final String? badgeLabel;
  final UserAddress? deliveryAddress;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  static final Map<String, String> _deliveryLabelCache = <String, String>{};
  static final Map<String, Future<String>> _deliveryLabelFlightCache =
      <String, Future<String>>{};
  static final DeliveryService _deliveryService = DeliveryService();

  bool _pressed = false;
  String _deliveryLabel = '';
  String _deliveryContextSignature = '';
  int _deliveryResolveSerial = 0;

  @override
  void initState() {
    super.initState();
    _refreshDeliveryLabel();
  }

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_productSignature(oldWidget.product) != _productSignature(widget.product) ||
        _addressSignature(oldWidget.deliveryAddress) !=
            _addressSignature(widget.deliveryAddress)) {
      _refreshDeliveryLabel();
    }
  }

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
    final deliveryLabel = _deliveryLabel.isNotEmpty
        ? _deliveryLabel
        : _deliveryFallbackLabel(product);
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
                                            _wishlistSnackBar(
                                              wasWishlisted
                                                  ? 'Removed from wishlist'
                                                  : 'Added to wishlist',
                                              backgroundColor:
                                                  const Color(0xFF15110D),
                                              icon: wasWishlisted
                                                  ? Icons.favorite_border_rounded
                                                  : Icons.favorite_rounded,
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
                                            _wishlistSnackBar(
                                              "Couldn't update wishlist. Please try again.",
                                              backgroundColor:
                                                  const Color(0xFF2A1918),
                                              icon: Icons.error_outline_rounded,
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
                        if (deliveryLabel.isNotEmpty)
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

  Future<void> _refreshDeliveryLabel() async {
    final product = widget.product;
    final address = widget.deliveryAddress;
    final fallback = _deliveryFallbackLabel(product);
    final signature = _deliveryContextSignatureFor(product.id, address);

    _deliveryContextSignature = signature;
    if (address == null) {
      if (!mounted) {
        return;
      }
      setState(() => _deliveryLabel = fallback);
      return;
    }

    final cachedLabel = _deliveryLabelCache[signature];
    if (cachedLabel != null) {
      if (!mounted) {
        return;
      }
      setState(() => _deliveryLabel = cachedLabel);
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() => _deliveryLabel = fallback);

    final labelFuture = _deliveryLabelFlightCache.putIfAbsent(signature, () {
      return _resolveDeliveryLabel(product, address, fallback, signature);
    });
    final serial = ++_deliveryResolveSerial;
    final label = await labelFuture;
    if (!mounted ||
        serial != _deliveryResolveSerial ||
        _deliveryContextSignature != signature) {
      return;
    }
    setState(() => _deliveryLabel = label);
  }

  Future<String> _resolveDeliveryLabel(
    Product product,
    UserAddress address,
    String fallback,
    String signature,
  ) async {
    try {
      final serviceability = await _deliveryService.getServiceability(
        product: product,
        address: address,
      );
      final resolved = _labelForServiceability(
        serviceability,
        fallback: fallback,
      );
      _deliveryLabelCache[signature] = resolved;
      return resolved;
    } catch (_) {
      _deliveryLabelCache[signature] = fallback;
      return fallback;
    } finally {
      _deliveryLabelFlightCache.remove(signature);
    }
  }

  String _deliveryFallbackLabel(Product product) {
    final delivery = product.deliveryInfo;
    if (_boolFrom(delivery['supportsInstantDelivery'])) {
      final instantTime =
          delivery['estimatedInstantDeliveryTime']?.toString().trim() ?? '';
      if (instantTime.isNotEmpty) {
        return 'Get It Today - $instantTime';
      }
      return 'Get It Today';
    }
    if (_boolFrom(delivery['supportsCourierDelivery'])) {
      final eta = delivery['estimatedDeliveryDate']?.toString().trim() ?? '';
      final partner = delivery['deliveryPartner']?.toString().trim() ?? '';
      if (eta.isNotEmpty && partner.isNotEmpty) {
        return 'Courier Delivery - $partner - $eta';
      }
      if (eta.isNotEmpty) {
        return 'Courier Delivery - $eta';
      }
      if (partner.isNotEmpty) {
        return 'Courier Delivery - $partner';
      }
      return 'Courier Delivery';
    }
    return '';
  }

  String _labelForServiceability(
    ProductServiceability serviceability, {
    required String fallback,
  }) {
    if (serviceability.canGetItToday) {
      return 'Get It Today';
    }
    if (serviceability.canCourier) {
      return 'Courier Delivery';
    }
    if (serviceability.isDeliverable) {
      return 'Delivery available';
    }
    if (fallback.trim().isNotEmpty && fallback != 'Check availability') {
      return fallback;
    }
    return '';
  }

  String _deliveryContextSignatureFor(String productId, UserAddress? address) {
    if (address == null) {
      return '$productId|none';
    }
    return [
      productId,
      address.id,
      address.userId,
      address.addressLine.trim(),
      address.locality.trim(),
      address.city.trim(),
      address.state.trim(),
      address.pincode.trim(),
      address.latitude?.toStringAsFixed(5) ?? 'na',
      address.longitude?.toStringAsFixed(5) ?? 'na',
    ].join('|');
  }

  String _addressSignature(UserAddress? address) {
    if (address == null) {
      return 'none';
    }
    return _deliveryContextSignatureFor('', address);
  }

  String _productSignature(Product product) {
    return [
      product.id,
      product.stock.toString(),
      product.deliveryInfo.toString(),
    ].join('|');
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

SnackBar _wishlistSnackBar(
  String message, {
  required Color backgroundColor,
  required IconData icon,
}) {
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: backgroundColor,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: Colors.white.withValues(alpha: 0.08),
      ),
    ),
    duration: const Duration(milliseconds: 1300),
    content: Row(
      children: [
        Icon(icon, color: const Color(0xFFC8A44D), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
