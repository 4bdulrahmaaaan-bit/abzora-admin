import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/state_views.dart';
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
  int _lastNewOrdersCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _newOrdersScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String _money(double amount) {
    return '\u20B9${amount.toStringAsFixed(0)}';
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F4),
      appBar: AppBar(
        title: Text(
          'Vendor Orders',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
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

          final orders = List<OrderModel>.of(snapshot.data ?? const <OrderModel>[])
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (orders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: AbzioEmptyCard(
                  title: 'No orders yet',
                  subtitle: 'New customer orders will appear here instantly.',
                ),
              ),
            );
          }

          final newOrders = _newOrders(orders);
          final processingOrders = _processingOrders(orders);
          final readyOrders = _readyOrders(orders);
          final completedOrders = _completedOrders(orders);
          _handleNewOrderArrival(newOrders.length);

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: const Color(0xFF2A241B),
                  unselectedLabelColor: const Color(0xFF8E8A84),
                  labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  indicator: BoxDecoration(
                    color: const Color(0xFFEEDAA4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  tabs: [
                    Tab(text: 'New (${newOrders.length})'),
                    Tab(text: 'Processing (${processingOrders.length})'),
                    Tab(text: 'Ready (${readyOrders.length})'),
                    Tab(text: 'Completed (${completedOrders.length})'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    ListView(
                      controller: _newOrdersScrollController,
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                      children: [
                        VendorOrdersTab(
                          orders: newOrders,
                          emptyTitle: 'No new orders',
                          emptySubtitle: 'Incoming orders will appear here.',
                          onConfirm: (order) => _updateOrderStatus(order, 'Confirmed'),
                          onPacked: (order) => _updateOrderStatus(order, 'Packed'),
                          onReject: (order) => _updateOrderStatus(order, 'Cancelled'),
                          formatCurrency: _money,
                        ),
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                      children: [
                        VendorOrdersTab(
                          orders: processingOrders,
                          emptyTitle: 'No processing orders',
                          emptySubtitle: 'Accepted and packed orders appear here.',
                          onConfirm: (order) => _updateOrderStatus(order, 'Confirmed'),
                          onPacked: (order) => _updateOrderStatus(order, 'Packed'),
                          onReadyForPickup: (order) =>
                              _updateOrderStatus(order, 'Ready for pickup'),
                          formatCurrency: _money,
                        ),
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                      children: [
                        VendorOrdersTab(
                          orders: readyOrders,
                          emptyTitle: 'No ready orders',
                          emptySubtitle: 'Orders ready for rider pickup appear here.',
                          onConfirm: (order) => _updateOrderStatus(order, 'Confirmed'),
                          onPacked: (order) => _updateOrderStatus(order, 'Packed'),
                          formatCurrency: _money,
                        ),
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                      children: [
                        VendorOrdersTab(
                          orders: completedOrders,
                          emptyTitle: 'No completed orders',
                          emptySubtitle: 'Delivered and in-flight orders appear here.',
                          onConfirm: (order) => _updateOrderStatus(order, 'Confirmed'),
                          onPacked: (order) => _updateOrderStatus(order, 'Packed'),
                          formatCurrency: _money,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
