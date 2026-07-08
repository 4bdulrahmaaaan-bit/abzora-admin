import '../../services/app_config.dart';
﻿import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/state_views.dart';

// V2 Design System Imports
import '../../core/vendor/theme/vendor_theme.dart';
import '../../widgets/lazy_indexed_tab_view.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_metric_card.dart';
import '../../core/vendor/widgets/vendor_status_badge.dart';
import '../../core/vendor/widgets/vendor_empty_state.dart';

import '../../widgets/vendor_orders_tab.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({
    super.key,
    required this.actor,
    required this.store,
  });
  final AppUser actor;
  final Store store;

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final ScrollController _newOrdersScrollController = ScrollController();
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  int _lastNewOrdersCount = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _newOrdersScrollController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _money(double amount) => '\u20B9${amount.toStringAsFixed(0)}';

  void _handleNewOrderArrival(int newCount) {
    final hasNewOrder = newCount > _lastNewOrdersCount;
    _lastNewOrdersCount = newCount;
    if (!hasNewOrder) return;
    SystemSound.play(SystemSoundType.alert);
    if (_tabController.index == 0 && _newOrdersScrollController.hasClients) {
      _newOrdersScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  List<OrderModel> _filterOrders(List<OrderModel> all) {
    if (_searchQuery.isEmpty) return all;
    return all.where((o) {
      final matchId =
          o.id.toLowerCase().contains(_searchQuery) ||
          o.invoiceNumber.toLowerCase().contains(_searchQuery);
      final matchName = o.shippingLabel.toLowerCase().contains(_searchQuery);
      return matchId || matchName;
    }).toList();
  }

  List<OrderModel> _newOrders(List<OrderModel> all) =>
      all.where((o) => o.status == 'Placed').toList();
  List<OrderModel> _processingOrders(List<OrderModel> all) => all
      .where((o) => o.status == 'Confirmed' || o.status == 'Packed')
      .toList();
  List<OrderModel> _readyOrders(List<OrderModel> all) =>
      all.where((o) => o.status == 'Ready for pickup').toList();
  List<OrderModel> _completedOrders(List<OrderModel> all) => all
      .where(
        (o) =>
            o.status == 'Delivered' ||
            o.status == 'Out for delivery' ||
            o.status == 'Picked up',
      )
      .toList();

  Future<void> _updateOrderStatus(OrderModel order, String status) async {
    await _db.updateOrderStatus(order.id, status, actor: widget.actor);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Order updated to $status.'),
      ),
    );
  }

  int _calculateHealthScore(List<OrderModel> all) {
    if (all.isEmpty) return 100; // No orders, perfect score
    final placed = all.where((o) => o.status == 'Placed').length;
    final total = all.length;
    // Simple mock logic for order health
    double score = 100 - ((placed / total) * 30);
    return score.toInt().clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VendorTheme.background,
      appBar: AppBar(
        title: const Text('Order Operations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () {},
            tooltip: 'Print Documents',
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () {},
            tooltip: 'Export CSV',
          ),
        ],
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _db.getVendorOrders(widget.store.id, actor: widget.actor),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AbzioLoadingView(
              title: 'Loading orders',
              subtitle: 'Preparing your live order queue and actions.',
            );
          }

          final allOrders = List<OrderModel>.of(
            snapshot.data ?? const <OrderModel>[],
          )..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          final filteredOrders = _filterOrders(allOrders);

          final newOrders = _newOrders(filteredOrders);
          final processingOrders = _processingOrders(filteredOrders);
          final readyOrders = _readyOrders(filteredOrders);
          final completedOrders = _completedOrders(filteredOrders);

          _handleNewOrderArrival(_newOrders(allOrders).length);

          return Column(
            children: [
              _buildAnalyticsHeader(allOrders),
              _buildSmartFilterBar(),
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: VendorTheme.spacing16,
                  vertical: VendorTheme.spacing8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
                  border: Border.all(color: VendorTheme.grey200),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: VendorTheme.primary,
                  unselectedLabelColor: VendorTheme.grey700,
                  indicator: BoxDecoration(
                    color: VendorTheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      VendorTheme.radiusSmall,
                    ),
                    border: Border(
                      bottom: BorderSide(color: VendorTheme.primary, width: 2),
                    ),
                  ),
                  tabs: [
                    Tab(text: 'New (${newOrders.length})'),
                    Tab(text: 'Process (${processingOrders.length})'),
                    Tab(text: 'Ready (${readyOrders.length})'),
                    Tab(text: 'Done (${completedOrders.length})'),
                  ],
                ),
              ),
              Expanded(
                child: LazyIndexedTabView(
                  controller: _tabController,
                  length: 4,
                  itemBuilder: (context, index) {
                    switch (index) {
                      case 0:
                        return _buildOrderList(
                          newOrders,
                          'No new orders',
                          'Incoming orders will appear here.',
                          _newOrdersScrollController,
                          canAccept: true,
                          canReject: true,
                        );
                      case 1:
                        return _buildOrderList(
                          processingOrders,
                          'No processing orders',
                          'Accepted and packed orders appear here.',
                          null,
                          canPack: true,
                          canReady: true,
                        );
                      case 2:
                        return _buildOrderList(
                          readyOrders,
                          'No ready orders',
                          AppConfig.enableLocalRiderDelivery ? 'Orders ready for rider pickup appear here.' : 'Orders ready for courier pickup appear here.',
                          null,
                        );
                      case 3:
                        return _buildOrderList(
                          completedOrders,
                          'No completed orders',
                          'Delivered and in-flight orders appear here.',
                          null,
                        );
                      default:
                        return const SizedBox.shrink();
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsHeader(List<OrderModel> allOrders) {
    final today = DateTime.now();
    final todayOrders = allOrders
        .where(
          (o) =>
              o.timestamp.day == today.day &&
              o.timestamp.month == today.month &&
              o.timestamp.year == today.year,
        )
        .toList();
    final todayRevenue = todayOrders.fold<double>(
      0,
      (sum, o) => sum + o.vendorEarnings,
    );
    final healthScore = _calculateHealthScore(allOrders);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VendorTheme.spacing16,
        VendorTheme.spacing16,
        VendorTheme.spacing16,
        0,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: VendorMetricCard(
                  title: 'Orders Today',
                  value: '${todayOrders.length}',
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
              const SizedBox(width: VendorTheme.spacing12),
              Expanded(
                child: VendorMetricCard(
                  title: 'Today Revenue',
                  value: _money(todayRevenue),
                  icon: Icons.payments_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing12),
          PremiumVendorCard(
            padding: const EdgeInsets.all(VendorTheme.spacing16),
            backgroundColor: VendorTheme.primary,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fulfillment Health',
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: VendorTheme.spacing4),
                    Text(
                      '$healthScore / 100',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
                VendorStatusBadge(
                  label: healthScore >= 80
                      ? 'Excellent'
                      : healthScore >= 50
                      ? 'Needs Attention'
                      : 'Critical',
                  type: healthScore >= 80
                      ? VendorBadgeType.success
                      : healthScore >= 50
                      ? VendorBadgeType.warning
                      : VendorBadgeType.error,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VendorTheme.spacing16,
        VendorTheme.spacing16,
        VendorTheme.spacing16,
        VendorTheme.spacing8,
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search Order ID or Customer Name',
          prefixIcon: const Icon(Icons.search_rounded),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
            borderSide: BorderSide(color: VendorTheme.grey200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
            borderSide: BorderSide(color: VendorTheme.grey200),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildOrderList(
    List<OrderModel> orders,
    String emptyTitle,
    String emptySubtitle,
    ScrollController? controller, {
    bool canAccept = false,
    bool canReject = false,
    bool canPack = false,
    bool canReady = false,
  }) {
    if (orders.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(VendorTheme.spacing16),
        children: [
          VendorEmptyState(
            title: emptyTitle,
            subtitle: emptySubtitle,
            icon: Icons.inbox_outlined,
          ),
        ],
      );
    }
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(
        VendorTheme.spacing16,
        VendorTheme.spacing8,
        VendorTheme.spacing16,
        VendorTheme.spacing24,
      ),
      children: [
        VendorOrdersTab(
          orders: orders,
          emptyTitle: emptyTitle,
          emptySubtitle: emptySubtitle,
          onConfirm: (order) => _updateOrderStatus(order, 'Confirmed'),
          onPacked: (order) => _updateOrderStatus(order, 'Packed'),
          onReadyForPickup: (order) =>
              _updateOrderStatus(order, 'Ready for pickup'),
          onReject: (order) => _updateOrderStatus(order, 'Cancelled'),
          formatCurrency: _money,
        ),
      ],
    );
  }
}


