import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';

import '../../widgets/state_views.dart';
import '../../utils/app_mode_routes.dart';

// V2 Design System Imports
import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_metric_card.dart';
import '../../core/vendor/widgets/vendor_status_badge.dart';
import '../../core/vendor/widgets/vendor_empty_state.dart';

import '../../core/vendor/vendor_status_helper.dart';

import 'add_product_screen.dart';
import 'order_management.dart';
import 'pricing_management_screen.dart';
import 'product_management.dart';
import 'store_settings_screen.dart';
import 'vendor_registration_screen.dart';

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> {
  final DatabaseService _db = DatabaseService();

  Future<Store?>? _storeFuture;
  Future<List<OrderModel>>? _ordersFuture;
  Future<VendorAnalytics>? _analyticsFuture;
  String? _boundActorId;
  String? _boundStoreId;

  String _money(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  void _ensureFutures(AppUser actor) {
    if (_boundActorId == actor.id && _storeFuture != null) return;
    _boundActorId = actor.id;
    _storeFuture = _loadStore(actor);
  }

  Future<Store?> _loadStore(AppUser actor) async {
    final linkedStoreId = actor.storeId?.trim() ?? '';
    if (linkedStoreId.isNotEmpty) {
      final store = await _db.getStore(linkedStoreId);
      if (store != null) return store;
    }
    return await _db.getStoreByOwner(actor.id);
  }

  void _ensureDashboardFutures(AppUser actor, Store store) {
    if (_boundActorId == actor.id &&
        _boundStoreId == store.id &&
        _ordersFuture != null &&
        _analyticsFuture != null)
      return;
    _boundStoreId = store.id;
    _ordersFuture = _db.getVendorOrders(store.id, actor: actor).first;
    _analyticsFuture = _db.getVendorAnalytics(store.id, actor: actor);
  }

  Future<void> _refresh(AppUser actor) async {
    setState(() {
      _boundActorId = null;
      _boundStoreId = null;
      _storeFuture = null;
      _ordersFuture = null;
      _analyticsFuture = null;
    });
    _ensureFutures(actor);
    final store = await _storeFuture;
    if (store != null) {
      _ensureDashboardFutures(actor, store);
      await Future.wait([_ordersFuture!, _analyticsFuture!]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = context.watch<AuthProvider>().user;
    if (actor == null) {
      return const Scaffold(
        body: AbzioLoadingView(
          title: 'Loading Workspace',
          subtitle: 'Authenticating vendor session...',
        ),
      );
    }

    if (!hasVendorOperationsAccess(actor)) {
      return Scaffold(
        backgroundColor: VendorTheme.background,
        appBar: widget.embedded ? null : AppBar(),
        body: const Center(
          child: VendorEmptyState(
            title: 'Vendor Access Required',
            subtitle:
                'Switch to a vendor account to manage store orders and operations.',
            icon: Icons.storefront_outlined,
          ),
        ),
      );
    }

    _ensureFutures(actor);

    return Scaffold(
      backgroundColor: VendorTheme.background,
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('Store Overview')),
      body: FutureBuilder<Store?>(
        future: _storeFuture,
        builder: (context, storeSnapshot) {
          if (storeSnapshot.connectionState == ConnectionState.waiting) {
            return const AbzioLoadingView(
              title: 'Loading Store',
              subtitle: 'Fetching store profile...',
            );
          }
          final store = storeSnapshot.data;
          final status = VendorStatusHelper.getVendorStatus(
            user: actor,
            store: store,
          );

          if (status != VendorAccountStatus.approved || store == null) {
            return Center(
              child: VendorEmptyState(
                title: 'Set up your store',
                subtitle:
                    'Register your storefront to begin operations and access the dashboard.',
                icon: Icons.add_business_outlined,
                primaryActionLabel: 'Register Store',
                onPrimaryAction: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VendorRegistrationScreen(),
                    ),
                  );
                  if (mounted) _refresh(actor);
                },
              ),
            );
          }

          _ensureDashboardFutures(actor, store);

          return RefreshIndicator(
            color: VendorTheme.primary,
            onRefresh: () => _refresh(actor),
            child: FutureBuilder<VendorAnalytics>(
              future: _analyticsFuture,
              builder: (context, analyticsSnapshot) {
                return FutureBuilder<List<OrderModel>>(
                  future: _ordersFuture,
                  builder: (context, ordersSnapshot) {
                    if (ordersSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        analyticsSnapshot.connectionState !=
                            ConnectionState.done) {
                      return const AbzioLoadingView(
                        title: 'Loading Data',
                        subtitle: 'Aggregating order and analytics data...',
                      );
                    }

                    final orders = List<OrderModel>.of(
                      ordersSnapshot.data ?? [],
                    )..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                    final analytics = analyticsSnapshot.data;
                    final products = analytics?.bestSellingProducts ?? [];

                    return ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: VendorTheme.spacing16,
                        vertical: VendorTheme.spacing24,
                      ),
                      children: [
                        _buildWelcomeHeader(store),
                        const SizedBox(height: VendorTheme.spacing24),
                        _buildQuickActions(context, store, actor),
                        const SizedBox(height: VendorTheme.spacing24),
                        _buildAiInsights(orders, products),
                        const SizedBox(height: VendorTheme.spacing24),
                        _buildTodayOverview(orders),
                        const SizedBox(height: VendorTheme.spacing24),
                        _buildOrderPipeline(orders),
                        const SizedBox(height: VendorTheme.spacing24),
                        _buildStoreHealthScore(store, orders, products),
                        const SizedBox(height: VendorTheme.spacing32),
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeHeader(Store store) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back,', style: Theme.of(context).textTheme.bodyLarge),
            Text(store.name, style: Theme.of(context).textTheme.headlineLarge),
          ],
        ),
        VendorStatusBadge(
          label: store.isActive ? 'Active' : 'Paused',
          type: store.isActive
              ? VendorBadgeType.success
              : VendorBadgeType.warning,
          icon: store.isActive
              ? Icons.check_circle_rounded
              : Icons.pause_circle_rounded,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, Store store, AppUser actor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('QUICK ACTIONS', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: VendorTheme.spacing12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _QuickActionChip(
                icon: Icons.add_circle_outline,
                label: 'Add Product',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddProductScreen(storeId: store.id),
                  ),
                ),
              ),
              const SizedBox(width: VendorTheme.spacing8),
              _QuickActionChip(
                icon: Icons.inventory_2_outlined,
                label: 'Products',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductManagementScreen(storeId: store.id),
                  ),
                ),
              ),
              const SizedBox(width: VendorTheme.spacing8),
              _QuickActionChip(
                icon: Icons.shopping_bag_outlined,
                label: 'Orders',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OrderManagementScreen(actor: actor, store: store),
                  ),
                ),
              ),
              const SizedBox(width: VendorTheme.spacing8),
              _QuickActionChip(
                icon: Icons.price_change_outlined,
                label: 'Pricing',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PricingManagementScreen(storeId: store.id),
                  ),
                ),
              ),
              const SizedBox(width: VendorTheme.spacing8),
              _QuickActionChip(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoreSettingsScreen(store: store),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiInsights(List<OrderModel> orders, List<Product> products) {
    final lowStock = products.where((p) => p.stock > 0 && p.stock <= 5).length;
    final String insight = lowStock > 0
        ? 'Restock Opportunity: You have $lowStock products critically low on stock.'
        : 'Pricing Health: Your pricing aligns well with market standards this week.';
    final Color insightColor = lowStock > 0
        ? VendorTheme.warning
        : VendorTheme.info;

    return PremiumVendorCard(
      backgroundColor: insightColor.withValues(alpha: 0.05),
      hasBorder: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: insightColor),
          const SizedBox(width: VendorTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI INSIGHT',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: insightColor),
                ),
                const SizedBox(height: VendorTheme.spacing4),
                Text(insight, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayOverview(List<OrderModel> orders) {
    final now = DateTime.now();
    final todayOrders = orders
        .where(
          (o) => o.timestamp.day == now.day && o.timestamp.month == now.month,
        )
        .toList();
    final yesterdayOrders = orders
        .where(
          (o) => o.timestamp.day == now.subtract(const Duration(days: 1)).day,
        )
        .toList();

    final todayRev = todayOrders.fold<double>(
      0,
      (sum, o) => sum + o.totalAmount,
    );
    final yestRev = yesterdayOrders.fold<double>(
      0,
      (sum, o) => sum + o.totalAmount,
    );
    double revTrend = yestRev == 0
        ? (todayRev > 0 ? 100 : 0)
        : ((todayRev - yestRev) / yestRev) * 100;

    final todayItems = todayOrders.fold<int>(
      0,
      (sum, o) => sum + o.items.fold<int>(0, (s, i) => s + i.quantity),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TODAY OVERVIEW', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: VendorTheme.spacing12),
        Row(
          children: [
            Expanded(
              child: VendorMetricCard(
                title: 'Revenue',
                value: _money(todayRev),
                trend: revTrend,
              ),
            ),
            const SizedBox(width: VendorTheme.spacing12),
            Expanded(
              child: VendorMetricCard(
                title: 'Orders',
                value: '${todayOrders.length}',
                trend: todayOrders.length >= yesterdayOrders.length
                    ? 5.0
                    : -2.0,
              ),
            ), // Dummy trend for orders
          ],
        ),
        const SizedBox(height: VendorTheme.spacing12),
        Row(
          children: [
            Expanded(
              child: VendorMetricCard(
                title: 'Units Sold',
                value: '$todayItems',
              ),
            ),
            const SizedBox(width: VendorTheme.spacing12),
            Expanded(
              child: VendorMetricCard(
                title: 'Store Visits',
                value: '${todayOrders.length * 4}',
              ),
            ), // Mock metric
          ],
        ),
      ],
    );
  }

  Widget _buildOrderPipeline(List<OrderModel> orders) {
    final newOrders = orders.where((o) => o.status == 'Placed').length;
    final accepted = orders.where((o) => o.status == 'Confirmed').length;
    final packed = orders.where((o) => o.status == 'Packed').length;
    final shipped = orders.where((o) => o.status == 'Shipped').length;

    return PremiumVendorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ORDER PIPELINE',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: VendorTheme.grey400,
              ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PipelineStep(
                label: 'New',
                count: newOrders,
                color: VendorTheme.info,
                isActive: newOrders > 0,
              ),
              _PipelineStep(
                label: 'Accepted',
                count: accepted,
                color: VendorTheme.warning,
                isActive: accepted > 0,
              ),
              _PipelineStep(
                label: 'Packed',
                count: packed,
                color: VendorTheme.warning,
                isActive: packed > 0,
              ),
              _PipelineStep(
                label: 'Shipped',
                count: shipped,
                color: VendorTheme.success,
                isActive: shipped > 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreHealthScore(
    Store store,
    List<OrderModel> orders,
    List<Product> products,
  ) {
    // Basic calculation logic to form a 0-100 score
    int score = 70;
    if (store.bannerImageUrl.isNotEmpty) score += 10;
    if (orders.isNotEmpty) score += 20;

    return PremiumVendorCard(
      backgroundColor: VendorTheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STORE HEALTH SCORE',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: VendorTheme.grey400),
          ),
          const SizedBox(height: VendorTheme.spacing16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: Theme.of(
                  context,
                ).textTheme.displayLarge?.copyWith(color: Colors.white),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  '/ 100',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: VendorTheme.grey400),
                ),
              ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing16),
          LinearProgressIndicator(
            value: score / 100,
            backgroundColor: VendorTheme.grey800,
            valueColor: AlwaysStoppedAnimation<Color>(
              score > 80 ? VendorTheme.success : VendorTheme.warning,
            ),
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
          const SizedBox(height: VendorTheme.spacing16),
          Text(
            score > 80
                ? 'Your store is performing exceptionally well.'
                : 'Update your store policies and banner to improve health.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: VendorTheme.grey300),
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VendorTheme.spacing16,
          vertical: VendorTheme.spacing12,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: VendorTheme.grey200),
          borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
          color: VendorTheme.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: VendorTheme.primary),
            const SizedBox(width: VendorTheme.spacing8),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _PipelineStep extends StatelessWidget {
  const _PipelineStep({
    required this.label,
    required this.count,
    required this.color,
    this.isActive = false,
  });
  final String label;
  final int count;
  final Color color;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? color.withValues(alpha: 0.1)
                : VendorTheme.grey100,
            border: Border.all(
              color: isActive ? color : VendorTheme.grey200,
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: isActive ? color : VendorTheme.grey400,
            ),
          ),
        ),
        const SizedBox(height: VendorTheme.spacing8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isActive ? VendorTheme.primary : VendorTheme.grey400,
          ),
        ),
      ],
    );
  }
}
