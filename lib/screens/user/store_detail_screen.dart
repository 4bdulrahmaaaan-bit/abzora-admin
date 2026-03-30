import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/product_card.dart';
import '../../widgets/state_views.dart';

class StoreDetailScreen extends StatefulWidget {
  final Store store;

  const StoreDetailScreen({super.key, required this.store});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  final _db = DatabaseService();
  List<Product> _products = [];
  List<ReviewModel> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadData);
  }

  Future<void> _loadData() async {
    try {
      final products = await context.read<ProductProvider>().getStoreProducts(widget.store.id);
      final reviews = await _db.getStoreReviews(widget.store.id);
      if (!mounted) return;
      setState(() {
        _products = products;
        _reviews = reviews;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _rating {
    if (_reviews.isEmpty) return widget.store.rating;
    final total = _reviews.fold<double>(0, (sum, review) => sum + review.rating);
    return total / _reviews.length;
  }

  double get _distanceKm {
    final seed = widget.store.id.codeUnits.fold<int>(0, (sum, value) => sum + value);
    return ((seed % 25) / 10) + 0.8;
  }

  Future<void> _writeStoreReview([ReviewModel? existing]) async {
    final auth = context.read<AuthProvider>();
    final controller = TextEditingController(text: existing?.comment ?? '');
    double rating = existing?.rating ?? 5;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(existing == null ? 'Rate Store' : 'Edit Store Review', style: Theme.of(context).textTheme.titleLarge),
              Slider(value: rating, min: 1, max: 5, divisions: 8, onChanged: (value) => setModalState(() => rating = value)),
              TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(hintText: 'Share your store experience')),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final currentUser = auth.user;
                    if (currentUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text('Sign in to rate this store.'),
                        ),
                      );
                      return;
                    }
                    await _db.saveReview(
                      ReviewModel(
                        id: existing?.id ?? '',
                        userId: currentUser.id,
                        userName: currentUser.name,
                        targetId: widget.store.id,
                        targetType: 'store',
                        rating: rating,
                        comment: controller.text.trim(),
                        createdAt: DateTime.now(),
                      ),
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text('SAVE REVIEW'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (saved == true) await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    ReviewModel? myReview;
    for (final review in _reviews) {
      if (auth.user != null && review.userId == auth.user!.id) {
        myReview = review;
        break;
      }
    }

    return AbzioThemeScope.light(
      child: Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AbzioTheme.lightTextPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AbzioNetworkImage(
                    imageUrl: widget.store.bannerImageUrl.isNotEmpty ? widget.store.bannerImageUrl : widget.store.imageUrl,
                    fallbackLabel: widget.store.name,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Theme.of(context).cardColor,
                          child: ClipOval(
                            child: AbzioNetworkImage(
                              imageUrl: widget.store.logoUrl.isNotEmpty ? widget.store.logoUrl : widget.store.imageUrl,
                              fallbackLabel: widget.store.name,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.store.name, style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.white)),
                              if (widget.store.tagline.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(widget.store.tagline, style: const TextStyle(color: Colors.white70)),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                '⭐ ${_rating.toStringAsFixed(1)}  •  ${_distanceKm.toStringAsFixed(1)} km  •  ${_reviews.length} reviews',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _loading
                  ? const AbzioLoadingView(
                      title: 'Loading store',
                      subtitle: 'Pulling the latest products, reviews, and store details.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.abzioBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.store_mall_directory_outlined, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${widget.store.name} is showing only products from this local store.',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _products
                                    .map((product) => product.category.toUpperCase())
                                    .toSet()
                                    .take(6)
                                    .map(
                                      (category) => Chip(
                                        label: Text(category),
                                        backgroundColor: Theme.of(context).cardColor,
                                        side: BorderSide(color: context.abzioBorder),
                                      ),
                                    )
                                    .toList(),
                              ),
                              if (widget.store.tagline.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(widget.store.tagline, style: Theme.of(context).textTheme.titleMedium),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Featured Collection', style: Theme.of(context).textTheme.labelMedium),
                            TextButton(onPressed: () => _writeStoreReview(myReview), child: Text(myReview == null ? 'RATE STORE' : 'EDIT REVIEW')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_products.isEmpty)
                          const AbzioEmptyCard(
                            title: 'Collection coming soon',
                            subtitle: 'This storefront is live, but its first product edit is still being prepared.',
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 20,
                              childAspectRatio: 0.62,
                            ),
                            itemCount: _products.length,
                            itemBuilder: (context, index) => ProductCard(product: _products[index]),
                          ),
                        const SizedBox(height: 24),
                        Text('Store Reviews', style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 12),
                        if (_reviews.isEmpty)
                          const AbzioEmptyCard(
                            title: 'No store reviews yet',
                            subtitle: 'Once customers review this store, ratings and feedback will appear here.',
                          )
                        else
                          ..._reviews.map(
                            (review) => Card(
                              child: ListTile(
                                title: Text(review.userName),
                                subtitle: Text(review.comment),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(review.rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text(
                                      DateFormat('dd MMM').format(review.createdAt),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.abzioSecondaryText),
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
    );
  }
}
