import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/animated_wishlist_button.dart';
import '../../widgets/product_card.dart';
import '../../widgets/tap_scale.dart';
import '../../widgets/state_views.dart';
import 'ai_stylist_screen.dart';
import 'avatar_try_on_screen.dart';
import 'live_ar_try_on_screen.dart';
import 'trial_booking_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin {
  static final Map<String, Color> _accentColorCache = <String, Color>{};

  final _db = DatabaseService();
  final _picker = ImagePicker();
  String? _selectedSize;
  bool _descriptionExpanded = false;
  bool _loading = true;
  List<ReviewModel> _reviews = [];
  List<Product> _completeTheLook = [];
  Product? _resolvedProduct;
  late final PageController _imageController;
  late final AnimationController _cartFlightController;
  late final AnimationController _cartPulseController;
  late final Animation<double> _cartPulseScale;
  int _imageIndex = 0;
  final GlobalKey _heroImageKey = GlobalKey();
  final GlobalKey _cartIconKey = GlobalKey();
  Offset? _cartFlightStart;
  Offset? _cartFlightEnd;
  Size _cartFlightSize = const Size(88, 112);
  bool _showCartFlight = false;

  @override
  void initState() {
    super.initState();
    _imageController = PageController();
    _cartFlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _cartPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _cartPulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.16).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.16, end: 1).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 50,
      ),
    ]).animate(_cartPulseController);
    if (widget.product.images.isNotEmpty) {
      Future.microtask(() => _resolveAccentColor(widget.product.images));
    }
    Future.microtask(_loadData);
  }

  @override
  void dispose() {
    _imageController.dispose();
    _cartFlightController.dispose();
    _cartPulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final currentUser = context.read<AuthProvider>().user;
    await _db.recordProductView(widget.product, user: currentUser);
    final results = await Future.wait([
      _db.getProductReviews(widget.product.id),
      _db.getCompleteTheLook(widget.product),
    ]);
    if (!mounted) return;
    setState(() {
      _reviews = results[0] as List<ReviewModel>;
      _completeTheLook = results[1] as List<Product>;
      _resolvedProduct = widget.product;
      _loading = false;
    });
  }


  Product get _product => _resolvedProduct ?? widget.product;

  _DetailPricing get _pricing => _DetailPricing.fromProduct(_product);

  Color _heroAccentColor(Product product, List<String> images) {
    final seed = '${product.category}|${images.isEmpty ? product.id : images.first}';
    final hue = (seed.hashCode.abs() % 360).toDouble();
    return HSVColor.fromAHSV(1, hue, 0.48, 0.82).toColor();
  }


  String _heroTagFor(Product product, int index) =>
      'product-hero-${product.id}-$index';

  Future<void> _resolveAccentColor(List<String> images) async {
    final imageUrl = images.isEmpty ? null : images.first;
    if (imageUrl == null) {
      return;
    }
    if (_accentColorCache.containsKey(imageUrl)) {
      return;
    }

    try {
      final provider = CachedNetworkImageProvider(imageUrl);
      final stream = provider.resolve(const ImageConfiguration());
      final completer = Completer<ImageInfo>();
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, synchronousCall) {
          stream.removeListener(listener);
          if (!completer.isCompleted) {
            completer.complete(info);
          }
        },
        onError: (error, stackTrace) {
          stream.removeListener(listener);
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
      );
      stream.addListener(listener);

      final imageInfo = await completer.future.timeout(
        const Duration(seconds: 2),
      );
      final byteData = await imageInfo.image.toByteData(
        format: ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        return;
      }

      final pixels = byteData.buffer.asUint8List();
      final width = imageInfo.image.width;
      final height = imageInfo.image.height;
      final stepX = math.max(1, width ~/ 24).toInt();
      final stepY = math.max(1, height ~/ 24).toInt();
      double red = 0;
      double green = 0;
      double blue = 0;
      int samples = 0;

      for (var y = 0; y < height; y += stepY) {
        for (var x = 0; x < width; x += stepX) {
          final index = (y * width + x) * 4;
          if (index + 3 >= pixels.length) {
            continue;
          }
          final alpha = pixels[index + 3];
          if (alpha < 24) {
            continue;
          }
          final pixelRed = pixels[index];
          final pixelGreen = pixels[index + 1];
          final pixelBlue = pixels[index + 2];
          final brightness =
              (pixelRed + pixelGreen + pixelBlue) / (3 * 255.0);
          if (brightness < 0.1 || brightness > 0.96) {
            continue;
          }
          red += pixelRed;
          green += pixelGreen;
          blue += pixelBlue;
          samples++;
        }
      }

      final fallback = _heroAccentColor(widget.product, images);
      final averaged = samples == 0
          ? fallback
          : Color.fromARGB(
              255,
              (red / samples).round().clamp(0, 255),
              (green / samples).round().clamp(0, 255),
              (blue / samples).round().clamp(0, 255),
            );
      final hsl = HSLColor.fromColor(averaged);
      final refined = hsl
          .withSaturation(hsl.saturation.clamp(0.35, 0.78))
          .withLightness(hsl.lightness.clamp(0.42, 0.62))
          .toColor();
      _accentColorCache[imageUrl] = refined;
    } catch (_) {
      // Fallback remains in use if extraction fails.
    }
  }

  Future<void> _openReviewSheet([ReviewModel? existing]) async {
    final auth = context.read<AuthProvider>();
    final commentController = TextEditingController(text: existing?.comment ?? '');
    double rating = existing?.rating ?? 5;
    String? imagePath = existing?.imagePath;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'Write Review' : 'Edit Review', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text('Rating: ${rating.toStringAsFixed(1)}'),
              Slider(
                value: rating,
                min: 1,
                max: 5,
                divisions: 8,
                onChanged: (value) => setModalState(() => rating = value),
              ),
              TextField(controller: commentController, maxLines: 4, decoration: const InputDecoration(hintText: 'Tell others what stood out')),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final file = await _picker.pickImage(source: ImageSource.gallery);
                      if (file != null) {
                        setModalState(() => imagePath = file.path);
                      }
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('ADD IMAGE'),
                  ),
                  const SizedBox(width: 12),
                  if (imagePath != null) Expanded(child: Text(File(imagePath!).uri.pathSegments.last, overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final currentUser = auth.user;
                      if (currentUser == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text('Sign in to leave a review.'),
                          ),
                        );
                        return;
                      }
                      final review = ReviewModel(
                        id: existing?.id ?? '',
                        userId: currentUser.id,
                        userName: currentUser.name,
                        targetId: widget.product.id,
                        targetType: 'product',
                        rating: rating,
                      comment: commentController.text.trim(),
                      imagePath: imagePath,
                      createdAt: DateTime.now(),
                    );
                    try {
                      await _db.saveReview(review);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text(error.toString().replaceFirst('Bad state: ', '')),
                          ),
                        );
                      }
                      return;
                    }
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: const Text('SAVE REVIEW'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    commentController.dispose();
    if (saved == true) {
      await _loadData();
    }
  }

  Future<void> _deleteReview(ReviewModel review) async {
    try {
      await _db.deleteReview(review.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
      return;
    }
    await _loadData();
  }

  String _resolveDeliverySummary(AuthProvider auth) {
    if (auth.user == null) {
      return 'Add your address for delivery updates';
    }
    final address = [
      (auth.user!.address ?? '').trim(),
      (auth.user!.city ?? '').trim(),
    ].where((part) => part.isNotEmpty).join(', ').trim();
    return address.isEmpty ? 'Add your address for delivery updates' : address;
  }

  String _recommendedSizeFor(Product product) {
    final sizes = product.sizes
        .map((size) => size.trim().toUpperCase())
        .where((size) => size.isNotEmpty)
        .toList();
    if (_selectedSize != null && _selectedSize!.trim().isNotEmpty) {
      return _selectedSize!.trim().toUpperCase();
    }
    if (sizes.contains('M')) {
      return 'M';
    }
    if (sizes.isNotEmpty) {
      return sizes.first;
    }
    return 'M';
  }

  Future<void> _openPerfectFitExperience(Product product) async {
    final address = _resolveDeliverySummary(context.read<AuthProvider>());
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrialBookingScreen(
          availableItems: _completeTheLook,
          recommendedItems: _completeTheLook,
          seedProduct: product,
          addressLabel: address,
          recommendedSize: _recommendedSizeFor(product),
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _openTrialFeedback(Product product) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _TrialFitFeedbackSheet(
        product: product,
        onCustomTailoringTap: () {
          Navigator.of(sheetContext).pop();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiStylistScreen()),
          );
        },
      ),
    );
  }


  Future<void> _openLiveTryOn(Product product, Color accentColor) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LiveArTryOnScreen(product: product, accentColor: accentColor),
      ),
    );
  }

  Future<void> _openAvatarTryOn(Product product, Color accentColor) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AvatarTryOnScreen(product: product, accentColor: accentColor),
      ),
    );
  }

  Widget _buildHeroSliver(
    BuildContext context,
    Product product,
    List<String> images,
    bool isWishlisted,
    bool isWishlistPending,
    WishlistProvider wishlist,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final heroHeight = (mediaQuery.size.height * 0.48).clamp(380.0, 500.0);
    return SliverToBoxAdapter(
      child: SizedBox(
        height: heroHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(color: Colors.white),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
                child: GestureDetector(
                  key: _heroImageKey,
                  onTap: _openGallery,
                  onLongPress: _openGallery,
                  child: PageView.builder(
                    controller: _imageController,
                    itemCount: images.length,
                    onPageChanged: (value) {
                      setState(() => _imageIndex = value);
                    },
                    itemBuilder: (context, index) => Hero(
                      tag: _heroTagFor(product, index),
                      child: AbzioNetworkImage(
                        imageUrl: images[index],
                        fallbackLabel: product.name,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (images.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    images.length,
                    (dotIndex) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _imageIndex == dotIndex ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _imageIndex == dotIndex
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedTopHeader(
    BuildContext context,
    Product product,
    bool isWishlisted,
    bool isWishlistPending,
    WishlistProvider wishlist,
  ) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(top: topInset),
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Row(
            children: [
              _HeroIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
                color: const Color(0xFF1A1A1A),
              ),
              const SizedBox(width: 6),
              Expanded(child: _buildHeaderSearchBar(context, true)),
              const SizedBox(width: 8),
              AnimatedWishlistButton(
                isSelected: isWishlisted,
                isLoading: isWishlistPending,
                size: 38,
                iconSize: 18,
                backgroundColor: Colors.transparent,
                selectedColor: const Color(0xFFC8A44D),
                unselectedColor: const Color(0xFF1A1A1A),
                onTap: () async {
                  try {
                    await wishlist.toggleWishlist(product);
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          error.toString().replaceFirst('Bad state: ', ''),
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 2),
              AnimatedBuilder(
                animation: _cartPulseScale,
                builder: (context, child) => Transform.scale(
                  scale: _cartPulseScale.value,
                  child: child,
                ),
                child: _HeroIconButton(
                  key: _cartIconKey,
                  icon: Icons.shopping_bag_outlined,
                  onTap: () => Navigator.pushNamed(context, '/cart'),
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSearchBar(BuildContext context, bool isCollapsed) {
    final bg = isCollapsed ? const Color(0xFFF3F3F3) : Colors.white.withValues(alpha: 0.88);
    final fg = isCollapsed ? const Color(0xFF4A4A4A) : const Color(0xFF3E3E3E);
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: fg),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Search in ABZORA',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    Product product,
    _DetailPricing pricing,
    List<String> images,
    String description,
    String? suggestedSize,
    String deliverySummary,
    String estimatedDelivery,
    Color accentColor,
  ) {
    final brandLabel = product.brand.trim().isNotEmpty
        ? product.brand.trim()
        : product.category.trim();
    final shortDescription = description.trim().isNotEmpty
        ? description.trim()
        : 'Premium finish with a refined fit and a clean, elevated silhouette.';
    final _ = images;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          if (brandLabel.isNotEmpty)
            Text(
              brandLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF777777),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
            ),
          const SizedBox(height: 6),
          Text(
            product.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 26,
                  height: 1.15,
                  color: const Color(0xFF111111),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                pricing.currentLabel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111111),
                    ),
              ),
              const SizedBox(width: 10),
              if (pricing.originalLabel != null)
                Text(
                  pricing.originalLabel!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF9B9B9B),
                        decoration: TextDecoration.lineThrough,
                        fontWeight: FontWeight.w600,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            shortDescription,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF666666),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select size',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF111111),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: product.sizes.map((size) {
              final selected = _selectedSize == size;
              final soldOut = product.stock <= 0;
              return ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 64),
                child: TapScale(
                  scale: 0.98,
                  onTap: soldOut ? null : () => setState(() => _selectedSize = size),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: soldOut
                          ? const Color(0xFFF5F5F5)
                          : selected
                              ? const Color(0xFFF7F4ED)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: soldOut
                            ? const Color(0xFFE0E0E0)
                            : selected
                                ? const Color(0xFF111111)
                                : const Color(0xFFE5E5E5),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      size,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: soldOut ? const Color(0xFF9B9B9B) : const Color(0xFF111111),
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        decoration: soldOut ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (suggestedSize != null) ...[
            const SizedBox(height: 8),
            Text(
              'Recommended: Size $suggestedSize',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF666666),
                    fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F7F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8E1D6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Try before you buy',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF111111),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try before you pay',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF666666),
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _TrustMiniBadge(label: 'Free returns'),
                    _TrustMiniBadge(label: 'No questions asked'),
                    _TrustMiniBadge(label: 'AI-selected size'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Try Experience',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF111111),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                _buildExperienceRow(
                  icon: Icons.view_in_ar_rounded,
                  title: 'Try Live (AR)',
                  onTap: () => _openLiveTryOn(product, accentColor),
                ),
                const SizedBox(height: 12),
                _buildExperienceRow(
                  icon: Icons.accessibility_new_rounded,
                  title: 'Try 3D Avatar',
                  onTap: () => _openAvatarTryOn(product, accentColor),
                ),
                const SizedBox(height: 12),
                _buildExperienceRow(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Ask AI Stylist',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiStylistScreen(
                        product: product,
                        initialPrompt: 'How should I style this?',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Trust',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF111111),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildOutlineChip('Verified Store', icon: Icons.verified_rounded),
              _buildOutlineChip('Fast Delivery', icon: Icons.local_shipping_outlined),
              _buildOutlineChip('Secure Payment', icon: Icons.lock_outline_rounded),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Delivery',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF111111),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          _buildSimpleBullet(
            icon: Icons.location_on_outlined,
            label: deliverySummary,
          ),
          const SizedBox(height: 8),
          _buildSimpleBullet(
            icon: Icons.local_shipping_outlined,
            label: 'Delivery by $estimatedDelivery',
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Description',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF111111),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              TextButton(
                onPressed: () => setState(
                  () => _descriptionExpanded = !_descriptionExpanded,
                ),
                child: Text(_descriptionExpanded ? 'Read less' : 'Read more'),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: Text(
              description,
              maxLines: _descriptionExpanded ? null : 3,
              overflow: _descriptionExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.55,
                    color: const Color(0xFF666666),
                  ),
            ),
          ),
        ],
    );
  }

  Widget _buildExperienceRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return TapScale(
      scale: 0.98,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6E0D6)),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF111111)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111111),
                  ),
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Color(0xFF888888),
          ),
        ],
      ),
    );
  }

  Widget _buildOutlineChip(String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: const Color(0xFF111111)),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF666666),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleBullet({
    required IconData icon,
    required String label,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF111111)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF666666),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompleteTheLookSection(
    BuildContext context,
    double lookCardWidth,
  ) {
    if (_completeTheLook.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Complete the Look',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 236,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _completeTheLook.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = _completeTheLook[index];
              return SizedBox(
                width: lookCardWidth.clamp(150.0, 170.0),
                child: ProductCard(
                  product: item,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(product: item),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection(
    BuildContext context,
    AuthProvider auth,
    ReviewModel? myReview,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reviews & Ratings',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            TextButton(
              onPressed: () => _openReviewSheet(myReview),
              child: Text(
                myReview == null ? 'WRITE REVIEW' : 'EDIT YOUR REVIEW',
              ),
            ),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: AbzioLoadingView(
              title: 'Loading reviews',
              subtitle:
                  'Fetching ratings and styling feedback for this piece.',
            ),
          )
        else if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No reviews yet',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Share your experience and help other shoppers decide with confidence.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF666666),
                      ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => _openReviewSheet(myReview),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  ),
                  child: const Text('Be the first to review'),
                ),
              ],
            ),
          )
        else
          ..._reviews.map(
            (review) => Container(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFEAEAEA)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          review.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(DateFormat('dd MMM').format(review.createdAt)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(
                      5,
                      (index) => Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: index < review.rating.round()
                            ? Colors.amber
                            : context.abzioBorder,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(review.comment),
                  if (review.imagePath != null &&
                      review.imagePath!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: review.imagePath!.startsWith('http')
                          ? SizedBox(
                              height: 140,
                              width: double.infinity,
                              child: AbzioNetworkImage(
                                imageUrl: review.imagePath!,
                                fallbackLabel: 'REVIEW',
                              ),
                            )
                          : Image.file(
                              File(review.imagePath!),
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ],
                  if (auth.user != null && review.userId == auth.user!.id)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _deleteReview(review),
                        child: const Text('DELETE'),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    Product product,
  ) {
    final cart = context.watch<CartProvider>();
    final hasSelectedSize = _selectedSize != null && _selectedSize!.trim().isNotEmpty;
    final isInCart = cart.items.any((item) => item.product.id == product.id);
    const primaryGold = Color(0xFFC8A96A);
    final canAddToBag = isInCart || hasSelectedSize;
    const addToBagLabel = 'Add to Bag';

    void showSelectSizeHint() {
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select size first')));
    }

    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: const Offset(0, 1), end: Offset.zero),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, offset, child) => Transform.translate(
        offset: Offset(0, offset.dy * 32),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 280),
          opacity: 1,
          child: child,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              top: BorderSide(color: Color(0xFFEAEAEA)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: _BottomActionButton(
                        label: 'Try at Home',
                        icon: Icons.auto_awesome_rounded,
                        onTap: hasSelectedSize
                            ? () {
                                HapticFeedback.lightImpact();
                                _openPerfectFitExperience(product);
                              }
                            : showSelectSizeHint,
                        outlined: false,
                        accentColor: primaryGold,
                        enabled: hasSelectedSize,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: _BottomActionButton(
                        label: addToBagLabel,
                        icon: Icons.shopping_bag_outlined,
                        onTap: isInCart
                            ? () {
                                HapticFeedback.lightImpact();
                                Navigator.pushNamed(context, '/cart');
                              }
                            : (canAddToBag
                                  ? () {
                                      HapticFeedback.lightImpact();
                                      _handleAddToCartPress();
                                    }
                                  : showSelectSizeHint),
                        outlined: true,
                        accentColor: primaryGold,
                        enabled: isInCart || canAddToBag,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartFlightOverlay(Product product, List<String> images) {
    if (!_showCartFlight ||
        _cartFlightStart == null ||
        _cartFlightEnd == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _cartFlightController,
      child: Material(
        elevation: 8,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: _cartFlightSize.width,
            height: _cartFlightSize.height,
            child: AbzioNetworkImage(
              imageUrl: images.first,
              fallbackLabel: product.name,
            ),
          ),
        ),
      ),
      builder: (context, child) {
        final progress = _cartFlightController.value;
        final curved = Curves.easeInOutCubic.transform(progress);
        final current = Offset.lerp(
          _cartFlightStart,
          _cartFlightEnd,
          curved,
        )!;
        final scale = lerpDouble(1, 0.28, curved)!;
        final opacity = lerpDouble(
          1,
          0.0,
          Curves.easeIn.transform(progress),
        )!;
        return Positioned(
          left: current.dx,
          top: current.dy,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFixedScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final lookCardWidth = width < 380 ? 140.0 : 160.0;
    final contentBottomSpacing = (width < 360 ? 184.0 : 144.0) + bottomInset;
    const screenBackground = Colors.white;
    const primaryGold = Color(0xFFC8A96A);
    final auth = context.watch<AuthProvider>();
    final wishlist = context.watch<WishlistProvider>();
    final product = _product;
    final images = product.images.isEmpty
        ? const ['https://via.placeholder.com/600x750']
        : product.images;
    final isWishlisted = wishlist.isWishlisted(widget.product.id);
    final isWishlistPending = wishlist.isPending(widget.product.id);
    final pricing = _pricing;
    final description = product.description.trim();
    final accentColor = primaryGold;
    final suggestedSize = _selectedSize ??
        (product.sizes.contains('M')
            ? 'M'
            : (product.sizes.isNotEmpty
                ? product.sizes[product.sizes.length ~/ 2]
                : null));
    final fixedHeaderHeight = MediaQuery.of(context).padding.top + 52;
    final deliverySummary = _resolveDeliverySummary(auth);
    final estimatedDelivery = DateFormat(
      'EEE, dd MMM',
    ).format(DateTime.now().add(const Duration(days: 3)));

    ReviewModel? myReview;
    for (final review in _reviews) {
      if (auth.user != null && review.userId == auth.user!.id) {
        myReview = review;
        break;
      }
    }

    return AbzioThemeScope.light(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: screenBackground,
        bottomNavigationBar: _buildBottomActionBar(
          context,
          product,
        ),
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: fixedHeaderHeight),
                ),
                _buildHeroSliver(
                  context,
                  product,
                  images,
                  isWishlisted,
                  isWishlistPending,
                  wishlist,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoCard(
                          context,
                          product,
                          pricing,
                          images,
                          description,
                          suggestedSize,
                          deliverySummary,
                          estimatedDelivery,
                          accentColor,
                        ),
                        const SizedBox(height: 24),
                        _buildCompleteTheLookSection(
                          context,
                          lookCardWidth,
                        ),
                        if (_completeTheLook.isNotEmpty)
                          const SizedBox(height: 24),
                        _buildReviewsSection(context, auth, myReview),
                        SizedBox(height: contentBottomSpacing),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildFixedTopHeader(
                context,
                product,
                isWishlisted,
                isWishlistPending,
                wishlist,
              ),
            ),
            _buildCartFlightOverlay(product, images),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _buildFixedScreen(context);

/*
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final lookCardWidth = width < 380 ? 140.0 : 160.0;
    final auth = context.watch<AuthProvider>();
    final wishlist = context.watch<WishlistProvider>();
    final product = _product;
    final images = product.images.isEmpty
        ? const ['https://via.placeholder.com/600x750']
        : product.images;
    final isWishlisted = wishlist.isWishlisted(widget.product.id);
    final isWishlistPending = wishlist.isPending(widget.product.id);
    final pricing = _pricing;
    final description = product.description.trim();
    final accentColor = _effectiveAccentColor(product, images);
    final suggestedSize = _selectedSize ??
        (product.sizes.contains('M')
            ? 'M'
            : (product.sizes.isNotEmpty
                ? product.sizes[product.sizes.length ~/ 2]
                : null));
    final deliveryAddress =
        auth.user == null
            ? 'Add your address for delivery updates'
            : [
                auth.user!.address.trim(),
                auth.user!.city.trim(),
              ].where((part) => part.isNotEmpty).join(', ').trim();
    final deliverySummary =
        deliveryAddress.isEmpty
            ? 'Add your address for delivery updates'
            : deliveryAddress;
    final estimatedDelivery =
        DateFormat('EEE, dd MMM').format(
          DateTime.now().add(const Duration(days: 3)),
        );
    ReviewModel? myReview;
    for (final review in _reviews) {
      if (auth.user != null && review.userId == auth.user!.id) {
        myReview = review;
        break;
      }
    }

    return AbzioThemeScope.light(
      child: Scaffold(
      backgroundColor: const Color(0xFFFAF8F3),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 132),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 352,
                  child: Stack(
                    children: [
                      GestureDetector(
                        key: _heroImageKey,
                        onTap: _openGallery,
                        onLongPress: _openGallery,
                        child: PageView.builder(
                          controller: _imageController,
                          onPageChanged: (value) => setState(() => _imageIndex = value),
                          itemCount: images.length,
                          itemBuilder: (context, index) => AbzioNetworkImage(
                            imageUrl: images[index],
                            fallbackLabel: product.name,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.12),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.36),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: SafeArea(
                          top: true,
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Row(
                              children: [
                                _HeroIconButton(
                                  icon: Icons.arrow_back_ios_new_rounded,
                                  onTap: () => Navigator.pop(context),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.22),
                                    ),
                                  ),
                                  child: Text(
                                    '${_imageIndex + 1}/${images.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                AnimatedWishlistButton(
                                  isSelected: isWishlisted,
                                  isLoading: isWishlistPending,
                                  size: 42,
                                  iconSize: 20,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.88),
                                  unselectedColor:
                                      Theme.of(context).colorScheme.onSurface,
                                  onTap: () async {
                                    try {
                                      await wishlist.toggleWishlist(product);
                                    } catch (error) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
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
                                const SizedBox(width: 10),
                                AnimatedBuilder(
                                  animation: _cartPulseScale,
                                  builder: (context, child) => Transform.scale(
                                    scale: _cartPulseScale.value,
                                    child: child,
                                  ),
                                  child: _HeroIconButton(
                                    key: _cartIconKey,
                                    icon: Icons.shopping_bag_outlined,
                                    onTap: () =>
                                        Navigator.pushNamed(context, '/cart'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (images.length > 1)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 18,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              images.length,
                              (dotIndex) => AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                width: _imageIndex == dotIndex ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _imageIndex == dotIndex
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.48),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                      Text(
                        product.category.toUpperCase(),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AbzioTheme.accentColor,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(fontSize: 28, height: 1.1),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          Text(
                            pricing.currentLabel,
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 30),
                          ),
                          if (pricing.originalLabel != null)
                            Text(
                              pricing.originalLabel!,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: context.abzioSecondaryText,
                                    decoration: TextDecoration.lineThrough,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          if (pricing.discountPercent > 0)
                            Text(
                              '${pricing.discountPercent}% OFF',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFF218B5B),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF5D8),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _averageRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${_reviews.length} reviews',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: context.abzioSecondaryText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F4F2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAD9A2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.local_shipping_outlined,
                                color: AbzioTheme.accentColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Premium packaging, fast delivery, and easy returns',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: context.abzioSecondaryText,
                                      height: 1.4,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Colours & finishes',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 76,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final selected = _imageIndex == index;
                            return InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () async {
                                setState(() => _imageIndex = index);
                                await _imageController.animateToPage(
                                  index,
                                  duration:
                                      const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 180),
                                width: 68,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: selected
                                        ? AbzioTheme.accentColor
                                        : context.abzioBorder,
                                    width: selected ? 2 : 1,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: AbzioTheme.accentColor
                                                .withValues(alpha: 0.18),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: AbzioNetworkImage(
                                    imageUrl: images[index],
                                    fallbackLabel: product.name,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select size',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          TextButton(
                            onPressed: () async {
                              final messenger =
                                  ScaffoldMessenger.of(context);
                              final recommendation =
                                  await Navigator.push<
                                      SizeRecommendationOutcome>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SizeRecommendationScreen(
                                    product: product,
                                  ),
                                ),
                              );
                              if (!mounted || recommendation == null) {
                                return;
                              }
                              setState(() {
                                _selectedSize =
                                    recommendation.recommendedSize;
                              });
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Recommended size ${recommendation.recommendedSize} selected for this product.',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Size Chart >'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 72,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: product.sizes.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final size = product.sizes[index];
                            final selected = _selectedSize == size;
                            final soldOut = product.stock <= 0;
                            final lowStock =
                                product.isLimitedStock && !soldOut;
                            return InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: soldOut
                                  ? null
                                  : () => setState(
                                        () => _selectedSize = size,
                                      ),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: soldOut
                                      ? const Color(0xFFF1F1F1)
                                      : selected
                                      ? AbzioTheme.accentColor
                                      : Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(22),
                                  border: Border.all(
                                    color: soldOut
                                        ? const Color(0xFFD9D9D9)
                                        : selected
                                        ? AbzioTheme.accentColor
                                        : context.abzioBorder,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: AbzioTheme.accentColor
                                                .withValues(alpha: 0.25),
                                            blurRadius: 14,
                                            offset: const Offset(0, 6),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      size,
                                      style: TextStyle(
                                        color: soldOut
                                            ? context.abzioSecondaryText
                                            : selected
                                                ? Colors.white
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                        fontWeight: FontWeight.w700,
                                        decoration: soldOut
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      pricing.currentLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: soldOut
                                            ? context.abzioSecondaryText
                                            : selected
                                                ? Colors.white
                                                    .withValues(alpha: 0.84)
                                                : context.abzioSecondaryText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (lowStock)
                                      Text(
                                        '${product.stock} left',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: selected
                                              ? Colors.white
                                                  .withValues(alpha: 0.92)
                                              : const Color(0xFFB54708),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F2E3),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFE7D39A),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAD9A2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.straighten_rounded,
                                color: AbzioTheme.accentColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    suggestedSize == null
                                        ? 'Find your recommended size'
                                        : 'We suggest size $suggestedSize',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  TextButton(
                                    onPressed: () async {
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      final recommendation =
                                          await Navigator.push<
                                              SizeRecommendationOutcome>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              SizeRecommendationScreen(
                                            product: product,
                                          ),
                                        ),
                                      );
                                      if (!mounted ||
                                          recommendation == null) {
                                        return;
                                      }
                                      setState(() {
                                        _selectedSize = recommendation
                                            .recommendedSize;
                                      });
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Recommended size ${recommendation.recommendedSize} selected for this product.',
                                          ),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      alignment: Alignment.centerLeft,
                                    ),
                                    child: const Text('Why this size?'),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: context.abzioBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F2E3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.location_on_outlined,
                                    size: 18,
                                    color: AbzioTheme.accentColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        deliverySummary,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(
                                            'Delivery by $estimatedDelivery',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: context
                                                      .abzioSecondaryText,
                                                ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            'Free',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                TextButton(
                                  onPressed: () {},
                                  child: const Text('Change'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _ServiceBullet(
                              icon: Icons.payments_outlined,
                              label: 'Cash on Delivery available',
                            ),
                            const SizedBox(height: 8),
                            _ServiceBullet(
                              icon: Icons.cached_rounded,
                              label: '14-day return & exchange',
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: const [
                                _TrustBadge(
                                  icon: Icons.verified_user_outlined,
                                  label: 'Genuine Product',
                                ),
                                _TrustBadge(
                                  icon: Icons.fact_check_outlined,
                                  label: 'Quality Checked',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AiStylistScreen(
                              product: product,
                              initialPrompt: 'How should I style this?',
                            ),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFE6D6A3),
                            ),
                            color: const Color(0xFFFFFBF2),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                '✨',
                                style: TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Ask AI Stylist about this look',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: AbzioTheme.accentColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Description',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          TextButton(
                            onPressed: () => setState(
                              () => _descriptionExpanded =
                                  !_descriptionExpanded,
                            ),
                            child: Text(
                              _descriptionExpanded
                                  ? 'Read less'
                                  : 'Read more',
                            ),
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        child: Text(
                          description,
                          maxLines: _descriptionExpanded ? null : 3,
                          overflow: _descriptionExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.55),
                        ),
                      ),
                      const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      if (_completeTheLook.isNotEmpty) ...[
                        Text(
                          'Complete the Look',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 236,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _completeTheLook.length,
                            itemBuilder: (context, index) {
                              final item = _completeTheLook[index];
                              return SizedBox(
                                width: lookCardWidth,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: ClipRRect(
                                                borderRadius: const BorderRadius.vertical(
                                                  top: Radius.circular(20),
                                                ),
                                                child: SizedBox(
                                                  width: double.infinity,
                                                  child: AbzioNetworkImage(
                                                    imageUrl: item.images.first,
                                                    fallbackLabel: item.name,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              left: 10,
                                              right: 10,
                                              bottom: 10,
                                              child: SizedBox(
                                                height: 36,
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    final result = context.read<CartProvider>().addToCart(item, item.sizes.first);
                                                    final message = result == CartAddResult.storeConflict
                                                        ? 'Your bag already contains products from another store.'
                                                        : '${item.name} added to your bag.';
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text(message)),
                                                    );
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.white,
                                                    foregroundColor: Colors.black,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                  ),
                                                  child: const Text('Quick Add'),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _currencyFormatter.format(item.price),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Reviews & Ratings', style: Theme.of(context).textTheme.labelMedium),
                          TextButton(
                            onPressed: () => _openReviewSheet(myReview),
                            child: Text(myReview == null ? 'WRITE REVIEW' : 'EDIT YOUR REVIEW'),
                          ),
                        ],
                      ),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: AbzioLoadingView(
                            title: 'Loading reviews',
                            subtitle: 'Fetching ratings and styling feedback for this piece.',
                          ),
                        )
                      else if (_reviews.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: AbzioEmptyCard(
                            title: 'No reviews yet',
                            subtitle: 'Be the first to review this piece and help other shoppers decide with confidence.',
                          ),
                        )
                      else
                        ..._reviews.map(
                          (review) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(review.userName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text(DateFormat('dd MMM').format(review.createdAt)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: List.generate(
                                      5,
                                      (index) => Icon(
                                        Icons.star_rounded,
                                        size: 16,
                                        color: index < review.rating.round() ? Colors.amber : context.abzioBorder,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(review.comment),
                                  if (review.imagePath != null && review.imagePath!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: review.imagePath!.startsWith('http')
                                          ? SizedBox(
                                              height: 140,
                                              width: double.infinity,
                                              child: AbzioNetworkImage(
                                                imageUrl: review.imagePath!,
                                                fallbackLabel: 'REVIEW',
                                              ),
                                            )
                                          : Image.file(File(review.imagePath!), height: 140, width: double.infinity, fit: BoxFit.cover),
                                    ),
                                  ],
                                  if (auth.user != null && review.userId == auth.user!.id)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => _deleteReview(review),
                                        child: const Text('DELETE'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  width < 360 ? 14 : 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: width < 360
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _BottomPriceBlock(
                            pricing: pricing,
                            isLimitedStock: product.isLimitedStock,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _handleAddToCartPress,
                              child: const Text('Add to Cart'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _buyNow,
                              child: const Text('Buy Now'),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _BottomPriceBlock(
                              pricing: pricing,
                              isLimitedStock: product.isLimitedStock,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _handleAddToCartPress,
                                      child: const Text('Add to Cart'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: _buyNow,
                                      child: const Text('Buy Now'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          if (_showCartFlight && _cartFlightStart != null && _cartFlightEnd != null)
            AnimatedBuilder(
              animation: _cartFlightController,
              child: Material(
                elevation: 8,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    width: _cartFlightSize.width,
                    height: _cartFlightSize.height,
                    child: AbzioNetworkImage(
                      imageUrl: images.first,
                      fallbackLabel: product.name,
                    ),
                  ),
                ),
              ),
              builder: (context, child) {
                final progress = _cartFlightController.value;
                final curved = Curves.easeInOutCubic.transform(progress);
                final current = Offset.lerp(_cartFlightStart, _cartFlightEnd, curved)!;
                final scale = lerpDouble(1, 0.28, curved)!;
                final opacity = lerpDouble(1, 0.0, Curves.easeIn.transform(progress))!;
                return Positioned(
                  left: current.dx,
                  top: current.dy,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: child,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      ),
    );
  }

*/
  bool _addToBag() {
    if (_selectedSize == null) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a size.')));
      return false;
    }
    final result = context.read<CartProvider>().addToCart(_product, _selectedSize!);
    if (result == CartAddResult.storeConflict) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your bag can contain items from one store at a time. Please clear it or checkout first.')),
      );
      return false;
    }
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result == CartAddResult.updated ? 'Cart quantity updated.' : 'Added to cart.')),
    );
    return true;
  }

  Future<void> _handleAddToCartPress() async {
    final added = _addToBag();
    if (!added) {
      return;
    }
    await _runCartFlightAnimation();
  }

  Future<void> _runCartFlightAnimation() async {
    final imageContext = _heroImageKey.currentContext;
    final cartContext = _cartIconKey.currentContext;
    if (imageContext == null || cartContext == null) {
      return;
    }

    final imageBox = imageContext.findRenderObject() as RenderBox?;
    final cartBox = cartContext.findRenderObject() as RenderBox?;
    if (imageBox == null || cartBox == null) {
      return;
    }

    final imageTopLeft = imageBox.localToGlobal(Offset.zero);
    final cartTopLeft = cartBox.localToGlobal(Offset.zero);
    final startSize = Size(
      (imageBox.size.width * 0.22).clamp(82.0, 104.0),
      (imageBox.size.height * 0.22).clamp(106.0, 128.0),
    );

    setState(() {
      _cartFlightSize = startSize;
      _cartFlightStart = Offset(
        imageTopLeft.dx + (imageBox.size.width - startSize.width) / 2,
        imageTopLeft.dy + imageBox.size.height * 0.34,
      );
      _cartFlightEnd = Offset(
        cartTopLeft.dx + (cartBox.size.width / 2) - (startSize.width * 0.28) / 2,
        cartTopLeft.dy + (cartBox.size.height / 2) - (startSize.height * 0.28) / 2,
      );
      _showCartFlight = true;
    });

    _cartPulseController.forward(from: 0);
    await _cartFlightController.forward(from: 0);
    if (!mounted) {
      return;
    }
    setState(() {
      _showCartFlight = false;
    });
  }

  Future<void> _openGallery() async {
    final images = widget.product.images.isEmpty
        ? const ['https://via.placeholder.com/600x750']
        : widget.product.images;
    final selectedIndex = await Navigator.of(context).push<int>(
      PageRouteBuilder<int>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: _ProductImageViewerScreen(
            product: widget.product,
            images: images,
            initialIndex: _imageIndex,
          ),
        ),
      ),
    );
    if (!mounted || selectedIndex == null || selectedIndex == _imageIndex) {
      return;
    }
    setState(() => _imageIndex = selectedIndex);
    if (_imageController.hasClients) {
      _imageController.jumpToPage(selectedIndex);
    }
  }
}

class _ProductImageViewerScreen extends StatefulWidget {
  const _ProductImageViewerScreen({
    required this.product,
    required this.images,
    required this.initialIndex,
  });

  final Product product;
  final List<String> images;
  final int initialIndex;

  @override
  State<_ProductImageViewerScreen> createState() =>
      _ProductImageViewerScreenState();
}

class _ProductImageViewerScreenState extends State<_ProductImageViewerScreen> {
  static const double _thumbnailExtent = 82;
  late final PageController _pageController;
  late final ScrollController _thumbnailController;
  final Map<int, TransformationController> _zoomControllers = {};
  TapDownDetails? _doubleTapDetails;
  late int _currentIndex;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailController = ScrollController();
    _attachZoomListener(_currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheAround(_currentIndex);
      _scrollToThumbnail(_currentIndex, animate: false);
    });
  }

  @override
  void dispose() {
    for (final controller in _zoomControllers.values) {
      controller.dispose();
    }
    _pageController.dispose();
    _thumbnailController.dispose();
    super.dispose();
  }

  TransformationController _controllerFor(int index) {
    return _zoomControllers.putIfAbsent(
      index,
      () => TransformationController(),
    );
  }

  void _attachZoomListener(int index) {
    final controller = _controllerFor(index);
    controller.removeListener(_handleZoomChanged);
    controller.addListener(_handleZoomChanged);
  }

  void _detachZoomListener(int index) {
    final controller = _controllerFor(index);
    controller.removeListener(_handleZoomChanged);
  }

  void _handleZoomChanged() {
    final controller = _controllerFor(_currentIndex);
    final scale = controller.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.02;
    if (zoomed != _isZoomed) {
      setState(() => _isZoomed = zoomed);
    }
  }

  void _resetZoom(int index) {
    final controller = _controllerFor(index);
    controller.value = Matrix4.identity();
  }

  void _precacheAround(int index) {
    for (final offset in const [-1, 0, 1]) {
      final preloadIndex = index + offset;
      if (preloadIndex < 0 || preloadIndex >= widget.images.length) {
        continue;
      }
      final imageUrl = widget.images[preloadIndex];
      precacheImage(CachedNetworkImageProvider(imageUrl), context);
    }
  }

  void _scrollToThumbnail(int index, {bool animate = true}) {
    if (!_thumbnailController.hasClients) {
      return;
    }
    final viewport = _thumbnailController.position.viewportDimension;
    final targetOffset =
        (index * _thumbnailExtent) - ((viewport - _thumbnailExtent) / 2);
    final clampedOffset = targetOffset.clamp(
      0.0,
      _thumbnailController.position.maxScrollExtent,
    );
    if (animate) {
      _thumbnailController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } else {
      _thumbnailController.jumpTo(clampedOffset);
    }
  }

  Future<void> _jumpToIndex(int index) async {
    if (index < 0 || index >= widget.images.length || index == _currentIndex) {
      return;
    }
    _resetZoom(_currentIndex);
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleDoubleTap(int index) {
    final controller = _controllerFor(index);
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    final isCurrentlyZoomed = controller.value.getMaxScaleOnAxis() > 1.02;
    if (isCurrentlyZoomed) {
      controller.value = Matrix4.identity();
      return;
    }
    final scale = 2.6;
    final x = -position.dx * (scale - 1);
    final y = -position.dy * (scale - 1);
    controller.value = Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  Future<void> _shareCurrentImage() async {
    final imageUrl = widget.images[_currentIndex];
    final price = widget.product.price <= 0
        ? ''
        : ' for ${NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(widget.product.price)}';
    final message =
        'Check out ${widget.product.name}$price on ABZORA.\n$imageUrl';
    await Share.share(message, subject: widget.product.name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wishlist = context.watch<WishlistProvider>();
    final isWishlisted = wishlist.isWishlisted(widget.product.id);
    final isWishlistPending = wishlist.isPending(widget.product.id);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                physics: _isZoomed
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                itemCount: widget.images.length,
                onPageChanged: (index) {
                  _detachZoomListener(_currentIndex);
                  _resetZoom(_currentIndex);
                  setState(() => _currentIndex = index);
                  _attachZoomListener(index);
                  _precacheAround(index);
                  _scrollToThumbnail(index);
                },
                itemBuilder: (context, index) {
                  final controller = _controllerFor(index);
                  return GestureDetector(
                    onDoubleTapDown: (details) =>
                        _doubleTapDetails = details,
                    onDoubleTap: () => _handleDoubleTap(index),
                    child: InteractiveViewer(
                      transformationController: controller,
                      minScale: 1.0,
                      maxScale: 3.6,
                      panEnabled: true,
                      scaleEnabled: true,
                      child: Center(
                        child: Hero(
                          tag: 'product-hero-${widget.product.id}-$index',
                          child: CachedNetworkImage(
                            imageUrl: widget.images[index],
                            fit: BoxFit.contain,
                            fadeInDuration: const Duration(milliseconds: 220),
                            placeholder: (context, url) => Container(
                              color: Colors.black,
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFC9A74E),
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.black,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                widget.product.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const SizedBox(height: 124),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isZoomed ? 0.6 : 1.0,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _ViewerControlButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).pop(_currentIndex),
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(scale: animation, child: child),
                        ),
                        child: Container(
                          key: ValueKey<int>(_currentIndex),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Text(
                            '${_currentIndex + 1}/${widget.images.length}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      _ViewerControlButton(
                        icon: Icons.ios_share_rounded,
                        onTap: _shareCurrentImage,
                      ),
                      const SizedBox(width: 10),
                      AnimatedWishlistButton(
                        isSelected: isWishlisted,
                        isLoading: isWishlistPending,
                        size: 42,
                        iconSize: 20,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        unselectedColor: Colors.white,
                        selectedColor: const Color(0xFFC8A44D),
                        onTap: () async {
                          try {
                            await wishlist.toggleWishlist(widget.product);
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  error
                                      .toString()
                                      .replaceFirst('Bad state: ', ''),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.images.length > 1) ...[
              Positioned(
                left: 12,
                top: 0,
                bottom: 122,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _currentIndex == 0 ? 0.0 : 1.0,
                    child: IgnorePointer(
                      ignoring: _currentIndex == 0,
                      child: _ViewerControlButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => _jumpToIndex(_currentIndex - 1),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 0,
                bottom: 122,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity:
                        _currentIndex == widget.images.length - 1 ? 0.0 : 1.0,
                    child: IgnorePointer(
                      ignoring: _currentIndex == widget.images.length - 1,
                      child: _ViewerControlButton(
                        icon: Icons.arrow_forward_ios_rounded,
                        onTap: () => _jumpToIndex(_currentIndex + 1),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isZoomed ? 0.6 : 1.0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 84,
                        child: ListView.separated(
                          controller: _thumbnailController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.images.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final isSelected = index == _currentIndex;
                            return GestureDetector(
                              onTap: () => _jumpToIndex(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: 72,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFC9A74E)
                                        : Colors.white.withValues(alpha: 0.12),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFC9A74E)
                                                .withValues(alpha: 0.22),
                                            blurRadius: 18,
                                            offset: const Offset(0, 8),
                                          ),
                                        ]
                                      : const [],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: CachedNetworkImage(
                                    imageUrl: widget.images[index],
                                    fit: BoxFit.cover,
                                    memCacheWidth: 240,
                                    placeholder: (context, url) => Container(
                                      color: Colors.white12,
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color: Colors.white10,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.image_not_supported_outlined,
                                        color: Colors.white54,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Swipe through all ${widget.images.length} product photos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.76),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    const fill = Color.fromRGBO(255, 255, 255, 0.6);
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 22,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ViewerControlButton extends StatelessWidget {
  const _ViewerControlButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}


class _BottomActionButton extends StatelessWidget {
  const _BottomActionButton({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.outlined,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final bool outlined;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = outlined
        ? (enabled ? const Color(0xFF111111) : const Color(0xFF9B9B9B))
        : (enabled ? Colors.black : const Color(0xFF9B9B9B));
    final background = outlined
        ? Colors.white
        : (enabled ? accentColor : const Color(0xFFE5E1D8));
    final borderColor =
        outlined ? const Color(0xFFE5E5E5) : Colors.transparent;

    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _TrialAtHomeButton extends StatelessWidget {
  const _TrialAtHomeButton({
    required this.onTap,
    required this.recommendedSize,
  });

  final VoidCallback onTap;
  final String recommendedSize;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF16120D),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Try at Home',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try before you pay � Perfect fit guaranteed',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const _TrustMiniBadge(label: 'Free returns', dark: true),
                      const _TrustMiniBadge(label: 'No questions asked', dark: true),
                      _TrustMiniBadge(
                        label: 'AI-selected size: $recommendedSize',
                        dark: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFFC8A96A),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustMiniBadge extends StatelessWidget {
  const _TrustMiniBadge({required this.label, this.dark = false});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFF3E8D2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: dark ? Colors.white : const Color(0xFF6F5226),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _PerfectFitExperienceSheet extends StatefulWidget {
  const _PerfectFitExperienceSheet({
    required this.product,
    required this.suggestedItems,
    required this.recommendedSize,
    required this.addressLabel,
  });

  final Product product;
  final List<Product> suggestedItems;
  final String recommendedSize;
  final String addressLabel;

  @override
  State<_PerfectFitExperienceSheet> createState() =>
      _PerfectFitExperienceSheetState();
}

class _PerfectFitExperienceSheetState extends State<_PerfectFitExperienceSheet> {
  int _step = 0;
  late final List<Product> _selectedItems;
  late final List<Product> _styleSuggestions;
  String _slot = 'Tomorrow � 6 PM to 9 PM';
  String _experienceType = 'premium';

  @override
  void initState() {
    super.initState();
    _selectedItems = <Product>[widget.product];
    _styleSuggestions = widget.suggestedItems.take(4).toList();
  }

  void _toggleItem(Product product) {
    setState(() {
      if (_selectedItems.any((item) => item.id == product.id)) {
        if (product.id != widget.product.id) {
          _selectedItems.removeWhere((item) => item.id == product.id);
        }
      } else if (_selectedItems.length < 5) {
        _selectedItems.add(product);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFCFAF6),
              Color(0xFFF7F1E7),
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D0C2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: List.generate(5, (index) {
                  final active = index <= _step;
                  return Expanded(
                    child: Container(
                      height: 6,
                      margin: EdgeInsets.only(right: index == 4 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFFC8A96A)
                            : const Color(0xFFE9E2D8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF18120C),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Perfect Fit Experience at Home',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Personal stylist, trial room, and tailor brought directly to your door.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFC8A96A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildStep(context),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step -= 1),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          side: const BorderSide(color: Color(0xFFE4DACA)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (_step == 4) {
                          Navigator.of(context).pop(true);
                          return;
                        }
                        setState(() => _step += 1);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC8A96A),
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _step == 4 ? 'Book Experience' : 'Continue',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        final items = [widget.product, ...widget.suggestedItems.take(4)];
        return _TrialStepShell(
          key: const ValueKey('select'),
          stepLabel: 'STEP 1',
          title: 'Choose items to try at home',
          subtitle: 'Select up to 5 pieces for your Perfect Fit Experience.',
          child: Column(
            children: items.map((product) {
              final selected = _selectedItems.any((item) => item.id == product.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TrialSelectableCard(
                  product: product,
                  selected: selected,
                  recommendedSize: widget.recommendedSize,
                  onTap: () => _toggleItem(product),
                ),
              );
            }).toList(),
          ),
        );
      case 1:
        return _TrialStepShell(
          key: const ValueKey('styled'),
          stepLabel: 'STEP 2',
          title: 'Complete your look',
          subtitle: 'AI-styled additions that work with your body and taste.',
          child: Column(
            children: _styleSuggestions.map((product) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TrialStyledCard(
                  product: product,
                  onTap: () => _toggleItem(product),
                ),
              );
            }).toList(),
          ),
        );
      case 2:
        final slots = [
          'Today � 7 PM to 10 PM',
          'Tomorrow � 6 PM to 9 PM',
          'Weekend � 11 AM to 2 PM',
        ];
        return _TrialStepShell(
          key: const ValueKey('slot'),
          stepLabel: 'STEP 3',
          title: 'Pick your trial time',
          subtitle: 'Delivered in 24 hours with premium packaging.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...slots.map((slot) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SelectionRowCard(
                      title: slot,
                      subtitle: 'Delivered in 24 hours',
                      selected: _slot == slot,
                      onTap: () => setState(() => _slot = slot),
                    ),
                  )),
              const SizedBox(height: 8),
              _SelectionRowCard(
                title: 'Deliver to',
                subtitle: widget.addressLabel,
                selected: true,
                onTap: () {},
              ),
            ],
          ),
        );
      case 3:
        return _TrialStepShell(
          key: const ValueKey('experience'),
          stepLabel: 'STEP 4',
          title: 'Choose your experience',
          subtitle: 'Luxury comfort at home, with or without styling support.',
          child: Column(
            children: [
              _SelectionRowCard(
                title: 'Standard Trial',
                subtitle: 'Try at home at your convenience',
                selected: _experienceType == 'standard',
                onTap: () => setState(() => _experienceType = 'standard'),
              ),
              const SizedBox(height: 12),
              _SelectionRowCard(
                title: 'Premium Stylist',
                subtitle: 'Get a stylist to assist your look',
                selected: _experienceType == 'premium',
                highlighted: true,
                badge: 'Recommended',
                onTap: () => setState(() => _experienceType = 'premium'),
              ),
            ],
          ),
        );
      default:
        return _TrialStepShell(
          key: const ValueKey('confirm'),
          stepLabel: 'STEP 5',
          title: 'Your Perfect Fit Experience is booked',
          subtitle: 'You only pay for what you keep.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SelectionRowCard(
                title: _slot,
                subtitle: 'Trial Fee: \u20B999 refundable',
                selected: true,
                onTap: () {},
              ),
              const SizedBox(height: 12),
              ..._selectedItems.map((product) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MiniSelectionCard(product: product),
                  )),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step = 2),
                      child: const Text('Modify'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }
}

class _TrialFitFeedbackSheet extends StatefulWidget {
  const _TrialFitFeedbackSheet({
    required this.product,
    required this.onCustomTailoringTap,
  });

  final Product product;
  final VoidCallback onCustomTailoringTap;

  @override
  State<_TrialFitFeedbackSheet> createState() => _TrialFitFeedbackSheetState();
}

class _TrialFitFeedbackSheetState extends State<_TrialFitFeedbackSheet> {
  String _fitResponse = 'perfect';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFAF7F2),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D0C2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'How did it fit?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us about ${widget.product.name} so we can sharpen every future recommendation.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF666666),
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 16),
            _SelectionRowCard(
              title: 'Perfect',
              subtitle: 'Exactly how I wanted it to feel',
              selected: _fitResponse == 'perfect',
              onTap: () => setState(() => _fitResponse = 'perfect'),
            ),
            const SizedBox(height: 10),
            _SelectionRowCard(
              title: 'Too tight',
              subtitle: 'Needs a little more room',
              selected: _fitResponse == 'tight',
              onTap: () => setState(() => _fitResponse = 'tight'),
            ),
            const SizedBox(height: 10),
            _SelectionRowCard(
              title: 'Too loose',
              subtitle: 'Needs a cleaner, sharper fit',
              selected: _fitResponse == 'loose',
              onTap: () => setState(() => _fitResponse = 'loose'),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _fitResponse == 'perfect'
                  ? Container(
                      key: const ValueKey('perfect-note'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5EBD8),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'Perfect. We’ll use this fit outcome to sharpen your future recommendations.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF7B5B27),
                              fontWeight: FontWeight.w700,
                              height: 1.45,
                            ),
                      ),
                    )
                  : Container(
                      key: const ValueKey('tailoring-note'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Adjust with custom tailoring',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'We can refine this piece so it fits like it was made only for you.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF666666),
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Make this perfect for you',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _AdjustmentChip(label: 'Tighten fit'),
                      _AdjustmentChip(label: 'Adjust length'),
                      _AdjustmentChip(label: 'Custom stitch'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: widget.onCustomTailoringTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC8A96A),
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Make this perfect for you',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrialStepShell extends StatelessWidget {
  const _TrialStepShell({
    super.key,
    required this.stepLabel,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String stepLabel;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stepLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFFC39A4E),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111111),
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF666666),
                height: 1.45,
              ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

class _TrialSelectableCard extends StatelessWidget {
  const _TrialSelectableCard({
    required this.product,
    required this.selected,
    required this.recommendedSize,
    required this.onTap,
  });

  final Product product;
  final bool selected;
  final String recommendedSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = product.images.isNotEmpty ? product.images.first : '';
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5EBD8) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFC8A96A) : const Color(0xFFE7E0D7),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 72,
                height: 88,
                child: AbzioNetworkImage(
                  imageUrl: image,
                  fallbackLabel: product.name,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _LightChip(label: 'Recommended for your body'),
                      _LightChip(label: '92% fit match'),
                      _LightChip(label: 'Size $recommendedSize'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? const Color(0xFFC8A96A) : const Color(0xFF9E968A),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrialStyledCard extends StatelessWidget {
  const _TrialStyledCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _LightChip(label: 'Styled for you'),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete the look with a more polished at-home edit.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF666666),
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF5EBD8),
                foregroundColor: const Color(0xFF7B5B27),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionRowCard extends StatelessWidget {
  const _SelectionRowCard({
    required this.title,
    required this.subtitle,
    this.selected = false,
    this.highlighted = false,
    this.badge,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool highlighted;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: highlighted
              ? const Color(0xFF16120D)
              : (selected ? const Color(0xFFF7F1E7) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFFC8A96A)
                : const Color(0xFFE7E0D7),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: highlighted ? Colors.white : const Color(0xFF111111),
                              ),
                        ),
                      ),
                      if (badge != null)
                        _LightChip(
                          label: badge!,
                          dark: highlighted,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: highlighted
                              ? Colors.white.withValues(alpha: 0.78)
                              : const Color(0xFF666666),
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? const Color(0xFFC8A96A) : const Color(0xFF9E968A),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniSelectionCard extends StatelessWidget {
  const _MiniSelectionCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            NumberFormat.currency(
              locale: 'en_IN',
              symbol: '₹',
              decimalDigits: 0,
            ).format(product.effectivePrice),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _LightChip extends StatelessWidget {
  const _LightChip({required this.label, this.dark = false});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFF4E8D0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: dark ? Colors.white : const Color(0xFF7B5B27),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _AdjustmentChip extends StatelessWidget {
  const _AdjustmentChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EBD8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF7B5B27),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DetailPricing {
  const _DetailPricing({
    required this.currentLabel,
    this.originalLabel,
    this.discountPercent = 0,
  });

  final String currentLabel;
  final String? originalLabel;
  final int discountPercent;

  static _DetailPricing fromProduct(Product product) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final currentPrice = product.effectivePrice;
    final originalPrice =
        (product.basePrice != null && product.basePrice! > currentPrice)
            ? product.basePrice
            : product.originalPrice;
    final discountPercent = originalPrice == null || originalPrice <= currentPrice
        ? 0
        : (((originalPrice - currentPrice) / originalPrice) * 100).round();

    return _DetailPricing(
      currentLabel: formatter.format(currentPrice),
      originalLabel: originalPrice == null ? null : formatter.format(originalPrice),
      discountPercent: discountPercent,
    );
  }
}
