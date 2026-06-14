import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_empty_state.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../models/models.dart';

class AnalyticsProductTab extends StatefulWidget {
  const AnalyticsProductTab({super.key});

  @override
  State<AnalyticsProductTab> createState() => _AnalyticsProductTabState();
}

class _AnalyticsProductTabState extends State<AnalyticsProductTab> {
  VendorAnalytics? _analytics;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) _loadData();
  }

  Future<void> _loadData() async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) return;
    try {
      final storeId = actor.storeId;
      if (storeId != null) {
        final analytics = await DatabaseService().getVendorAnalytics(storeId, actor: actor);
        if (mounted) {
          setState(() {
            _analytics = analytics;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _money(double value) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
          .format(value);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: VendorTheme.primary));
    }

    if (_analytics == null || _analytics!.bestSellingProducts.isEmpty) {
      return const VendorEmptyState(
        title: 'No Product Data',
        subtitle: 'Product analytics will appear here once you make some sales.',
        icon: Icons.trending_up_outlined,
      );
    }

    final topProducts = _analytics!.bestSellingProducts;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Performing Products',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: VendorTheme.spacing16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topProducts.length,
            separatorBuilder: (context, index) => const SizedBox(height: VendorTheme.spacing16),
            itemBuilder: (context, index) {
              final product = topProducts[index];
              return PremiumVendorCard(
                padding: const EdgeInsets.all(VendorTheme.spacing16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 80,
                            height: 80,
                            color: VendorTheme.grey800,
                            child: product.images.isNotEmpty
                                ? Image.network(product.images.first, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, color: VendorTheme.grey400))
                                : const Icon(Icons.image, color: VendorTheme.grey400),
                          ),
                        ),
                        Positioned(
                          top: -8,
                          left: -8,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: index == 0 ? VendorTheme.primary : (index == 1 ? VendorTheme.grey300 : VendorTheme.warning),
                            child: Text(
                              '#${index + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: VendorTheme.spacing16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Price',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VendorTheme.grey400),
                                  ),
                                  Text(
                                    _money(product.price),
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Remaining Stock',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VendorTheme.grey400),
                                  ),
                                  Text(
                                    '${product.stock}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: product.stock < 10 ? VendorTheme.warning : VendorTheme.success,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
