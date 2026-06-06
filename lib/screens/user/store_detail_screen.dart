import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../utils/app_error_text.dart';
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
                    try {
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
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text(AppErrorText.from(error)),
                          ),
                        );
                      }
                      return;
                    }
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text('Save review'),
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
            expandedHeight: 260,
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
                      title: 'Loading boutique',
                      subtitle: 'Pulling the latest pieces, reviews, and store details.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFCF8),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFE6D6BE)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFB8963F).withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.store_mall_directory_outlined,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${widget.store.name} is presented as a private boutique edit, with craft, tailoring, and collection depth highlighted first.',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _StoreStoryChip(
                                    label:
                                        '${widget.store.customVendorProfile.experienceYears}+ years',
                                  ),
                                  _StoreStoryChip(
                                    label:
                                        widget.store.customVendorProfile.productionTimeDays > 0
                                        ? '${widget.store.customVendorProfile.productionTimeDays} day production'
                                        : 'Curated production',
                                  ),
                                  _StoreStoryChip(
                                    label: widget
                                        .store.customVendorProfile
                                        .supportsAlterations
                                        ? 'Alterations supported'
                                        : 'Selected tailoring only',
                                  ),
                                  if (widget.store.vendorRank > 0)
                                    _StoreStoryChip(
                                      label: 'Rank #${widget.store.vendorRank}',
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
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
                                        backgroundColor: const Color(0xFFFFF4D8),
                                        side: const BorderSide(color: Color(0xFFF0DFC0)),
                                      ),
                                    )
                                    .toList(),
                              ),
                              if (widget.store.vendorHighlights.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: widget.store.vendorHighlights
                                      .take(4)
                                      .map(
                                        (highlight) => _StoreStoryChip(
                                          label: highlight,
                                          muted: true,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                              if (widget.store.tagline.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  widget.store.tagline,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Curated Edit', style: Theme.of(context).textTheme.labelMedium),
                            TextButton(onPressed: () => _writeStoreReview(myReview), child: Text(myReview == null ? 'RATE STORE' : 'EDIT REVIEW')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_products.isEmpty)
                          const AbzioEmptyCard(
                            title: 'Curated edit coming soon',
                            subtitle: 'This storefront is live, but its first selection is still being prepared.',
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: true,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 20,
                              childAspectRatio: 0.62,
                            ),
                            itemCount: _products.length,
                            itemBuilder: (context, index) => ProductCard(
                              product: _products[index],
                              storeLabel: widget.store.name,
                            ),
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
                              color: const Color(0xFFFFFDF8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: const BorderSide(color: Color(0xFFF0E3C5)),
                              ),
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

class _StoreStoryChip extends StatelessWidget {
  const _StoreStoryChip({
    required this.label,
    this.muted = false,
  });

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: muted ? Colors.white : const Color(0xFFFFF4D8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: muted ? const Color(0xFFE9E1D1) : const Color(0xFFF0DFC0),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFF5F4A1A),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
