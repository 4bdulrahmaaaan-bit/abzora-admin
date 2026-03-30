import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/animated_wishlist_button.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/state_views.dart';
import 'ai_stylist_screen.dart';
import 'size_recommendation_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin {
  final _db = DatabaseService();
  final _picker = ImagePicker();
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  String? _selectedSize;
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
    final dynamicProduct = await _db.getDynamicPrice(
      widget.product,
      user: currentUser,
    );
    final results = await Future.wait([
      _db.getProductReviews(widget.product.id),
      _db.getCompleteTheLook(widget.product),
    ]);
    if (!mounted) return;
    setState(() {
      _reviews = results[0] as List<ReviewModel>;
      _completeTheLook = results[1] as List<Product>;
      _resolvedProduct = dynamicProduct;
      _loading = false;
    });
  }

  double get _averageRating {
    if (_reviews.isEmpty) return widget.product.rating;
    final total = _reviews.fold<double>(0, (sum, review) => sum + review.rating);
    return total / _reviews.length;
  }

  Product get _product => _resolvedProduct ?? widget.product;

  _DetailPricing get _pricing => _DetailPricing.fromProduct(_product);

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
                    await _db.saveReview(review);
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
    await _db.deleteReview(review.id);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final lookCardWidth = width < 380 ? 140.0 : 160.0;
    final auth = context.watch<AuthProvider>();
    final wishlist = context.watch<WishlistProvider>();
    final isWishlisted = wishlist.isWishlisted(widget.product.id);
    final isWishlistPending = wishlist.isPending(widget.product.id);
    final pricing = _pricing;
    ReviewModel? myReview;
    for (final review in _reviews) {
      if (auth.user != null && review.userId == auth.user!.id) {
        myReview = review;
        break;
      }
    }

    return AbzioThemeScope.light(
      child: Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 420,
                  child: Stack(
                    children: [
                      GestureDetector(
                        key: _heroImageKey,
                        onTap: _openGallery,
                        onLongPress: _openGallery,
                        child: PageView.builder(
                          controller: _imageController,
                          onPageChanged: (value) => setState(() => _imageIndex = value),
                          itemCount: widget.product.images.isEmpty ? 1 : widget.product.images.length,
                          itemBuilder: (context, index) => AbzioNetworkImage(
                            imageUrl: widget.product.images.isEmpty ? 'https://via.placeholder.com/600x750' : widget.product.images[index],
                            fallbackLabel: widget.product.name,
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
                                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.14),
                                  Colors.transparent,
                                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.28),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.product.images.length > 1)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 18,
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    widget.product.images.length,
                                    (dotIndex) => AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      width: _imageIndex == dotIndex ? 18 : 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: _imageIndex == dotIndex ? Colors.white : Colors.white.withValues(alpha: 0.54),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  '${_imageIndex + 1}/${widget.product.images.length}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.product.category.toUpperCase(), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AbzioTheme.accentColor)),
                                const SizedBox(height: 8),
                                Text(widget.product.name, style: Theme.of(context).textTheme.displayMedium),
                              ],
                            ),
                          ),
                          AnimatedWishlistButton(
                            isSelected: isWishlisted,
                            isLoading: isWishlistPending,
                            size: 44,
                            iconSize: 24,
                            backgroundColor: Colors.transparent,
                            unselectedColor: Theme.of(context).colorScheme.onSurface,
                            onTap: () async {
                              try {
                                await wishlist.toggleWishlist(_product);
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text('${_averageRating.toStringAsFixed(1)} (${_reviews.length} reviews)'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_shipping_outlined, color: AbzioTheme.accentColor, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Premium packaging, quick checkout, and concierge-ready support for every order.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: context.abzioSecondaryText,
                                      height: 1.4,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isWishlistPending
                              ? null
                              : () async {
                                  try {
                                    await wishlist.toggleWishlist(_product);
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
                                    );
                                  }
                                },
                          icon: Icon(isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isWishlisted ? Colors.redAccent : null),
                          label: Text(isWishlisted ? 'Saved to Wishlist' : 'Save to Wishlist'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final recommendation = await Navigator.push<SizeRecommendationOutcome>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SizeRecommendationScreen(
                                  product: _product,
                                ),
                              ),
                            );
                            if (!mounted || recommendation == null) {
                              return;
                            }
                            setState(() {
                              _selectedSize = recommendation.recommendedSize;
                            });
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Recommended size ${recommendation.recommendedSize} selected for this product.',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.straighten_rounded),
                          label: const Text('Find my perfect size'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AiStylistScreen(
                                product: _product,
                                initialPrompt: 'How should I style this?',
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Ask AI Stylist about this look'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified_outlined, color: Theme.of(context).colorScheme.onSurface, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Quick add, size advice, and review flow are all available on this screen.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Select size', style: Theme.of(context).textTheme.labelMedium),
                          TextButton(
                            onPressed: () async {
                              final size = await Navigator.push(context, MaterialPageRoute(builder: (_) => const SizeRecommendationScreen()));
                              if (size != null && mounted) setState(() => _selectedSize = size as String);
                            },
                            child: const Text('FIND MY SIZE'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        children: widget.product.sizes.map((size) {
                          final selected = _selectedSize == size;
                          return ChoiceChip(
                            label: Text(size),
                            selected: selected,
                            onSelected: (_) => setState(() => _selectedSize = size),
                            selectedColor: Theme.of(context).colorScheme.onSurface,
                            backgroundColor: Theme.of(context).cardColor,
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              color: selected ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.onSurface,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Text('Description', style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 8),
                      Text(widget.product.description, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 24),
                      if (_completeTheLook.isNotEmpty) ...[
                        Text('Complete the Look', style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _completeTheLook.length,
                            itemBuilder: (context, index) {
                              final item = _completeTheLook[index];
                              return Container(
                                width: lookCardWidth,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: context.abzioBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: SizedBox(
                                        height: 110,
                                        width: double.infinity,
                                        child: AbzioNetworkImage(
                                          imageUrl: item.images.first,
                                          fallbackLabel: item.name,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 6),
                                          Text(
                                            _currencyFormatter.format(item.price),
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(height: 8),
                                          ElevatedButton(
                                            onPressed: () {
                                              final result = context.read<CartProvider>().addToCart(item, item.sizes.first);
                                              final message = result == CartAddResult.storeConflict
                                                  ? 'Your bag already contains products from another store.'
                                                  : '${item.name} added to your bag.';
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(message)),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(38)),
                                            child: const Text('QUICK ADD'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
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
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GlassContainer(
                      borderRadius: 99,
                      padding: const EdgeInsets.all(2),
                      blurRate: 24,
                      child: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
                    ),
                    GlassContainer(
                      borderRadius: 99,
                      padding: const EdgeInsets.all(2),
                      blurRate: 24,
                      child: AnimatedBuilder(
                        animation: _cartPulseScale,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _cartPulseScale.value,
                            child: child,
                          );
                        },
                        child: IconButton(
                          key: _cartIconKey,
                          icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                          onPressed: () => Navigator.pushNamed(context, '/cart'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GlassContainer(
                  borderRadius: 24,
                  blurRate: 40,
                  opacity: 0.85,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      child: width < 360
                          ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _BottomPriceBlock(
                              pricing: pricing,
                              isLimitedStock: _product.isLimitedStock,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _handleAddToCartPress, child: const Text('Add to Cart')),
                            const SizedBox(height: 8),
                            OutlinedButton(onPressed: _buyNow, child: const Text('Buy Now')),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _BottomPriceBlock(
                                pricing: pricing,
                                isLimitedStock: _product.isLimitedStock,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _handleAddToCartPress,
                                      child: const Text('Add to Cart'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _buyNow,
                                      child: const Text('Buy Now'),
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
          ),
          if (_showCartFlight && _cartFlightStart != null && _cartFlightEnd != null)
            IgnorePointer(
              child: AnimatedBuilder(
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
                        imageUrl: widget.product.images.isEmpty
                            ? 'https://via.placeholder.com/600x750'
                            : widget.product.images.first,
                        fallbackLabel: widget.product.name,
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
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      ),
    );
  }

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

  void _buyNow() {
    _handleBuyNow();
  }

  Future<void> _handleBuyNow() async {
    final added = _addToBag();
    if (!added) {
      return;
    }
    await _runCartFlightAnimation();
    if (!mounted) {
      return;
    }
    Navigator.pushNamed(context, '/checkout');
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
    final images = widget.product.images.isEmpty ? const ['https://via.placeholder.com/600x750'] : widget.product.images;
    await showDialog<void>(
      context: context,
      builder: (context) {
        var current = _imageIndex;
        return StatefulBuilder(
          builder: (context, setModalState) => Dialog(
            insetPadding: const EdgeInsets.all(10),
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 0.72,
                  child: PageView.builder(
                    controller: PageController(initialPage: _imageIndex),
                    onPageChanged: (value) => setModalState(() => current = value),
                    itemCount: images.length,
                    itemBuilder: (context, index) => InteractiveViewer(
                      child: AbzioNetworkImage(
                        imageUrl: images[index],
                        fit: BoxFit.contain,
                        fallbackLabel: widget.product.name,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
                if (images.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            images.length,
                            (dotIndex) => AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: current == dotIndex ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: current == dotIndex ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Swipe through all ${images.length} product photos',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.abzioSecondaryText),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BottomPriceBlock extends StatelessWidget {
  const _BottomPriceBlock({
    required this.pricing,
    required this.isLimitedStock,
  });

  final _DetailPricing pricing;
  final bool isLimitedStock;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          pricing.currentLabel,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        if (pricing.originalLabel != null || pricing.discountPercent > 0) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (pricing.originalLabel != null)
                Text(
                  pricing.originalLabel!,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (pricing.discountPercent > 0)
                Text(
                  '${pricing.discountPercent}% OFF',
                  style: const TextStyle(
                    color: Color(0xFF218B5B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ],
        if (isLimitedStock) ...[
          const SizedBox(height: 6),
          const Text(
            'Limited stock',
            style: TextStyle(
              color: Color(0xFFB54708),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
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
