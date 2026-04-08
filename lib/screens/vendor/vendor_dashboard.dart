import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/payout_account_dialog.dart';
import '../../widgets/state_views.dart';
import '../../widgets/vendor_orders_tab.dart';
import '../../widgets/vendor_quick_actions.dart';
import '../../widgets/vendor_summary_cards.dart';
import 'add_product_screen.dart';
import 'order_management.dart';
import 'product_management.dart';
import 'store_settings_screen.dart';
import 'vendor_registration_screen.dart';

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _earningsSectionKey = GlobalKey();
  late final TabController _tabController;

  Future<Store?>? _storeFuture;
  String? _boundActorId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<Store?> _loadStore(AppUser actor) async {
    final ownStore = await _db.getStoreByOwner(actor.id);
    if (ownStore != null) {
      return ownStore;
    }
    final linkedStoreId = actor.storeId?.trim() ?? '';
    if (linkedStoreId.isEmpty) {
      return null;
    }
    final stores = await _db.getStores();
    for (final store in stores) {
      if (store.id == linkedStoreId || store.storeId == linkedStoreId) {
        return store;
      }
    }
    return null;
  }

  void _ensureFutures(AppUser actor) {
    if (_boundActorId == actor.id && _storeFuture != null) {
      return;
    }
    _boundActorId = actor.id;
    _storeFuture = _loadStore(actor);
  }

  Future<void> _refresh(AppUser actor) async {
    setState(() {
      _boundActorId = null;
      _storeFuture = null;
    });
    _ensureFutures(actor);
    await _storeFuture;
  }

  String _money(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'Rs ',
      decimalDigits: 0,
    ).format(amount);
  }

  int _todayOrderCount(List<OrderModel> orders) {
    final now = DateTime.now();
    return orders.where((order) {
      final time = order.timestamp;
      return time.year == now.year && time.month == now.month && time.day == now.day;
    }).length;
  }

  double _todayRevenue(List<OrderModel> orders) {
    final now = DateTime.now();
    return orders
        .where((order) => order.timestamp.year == now.year && order.timestamp.month == now.month && order.timestamp.day == now.day)
        .fold<double>(0, (sum, order) => sum + order.totalAmount);
  }

  double _weeklyRevenue(List<OrderModel> orders) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return orders.where((order) => !order.timestamp.isBefore(start)).fold<double>(0, (sum, order) => sum + order.vendorEarnings);
  }

  List<String> _buildAlerts(List<OrderModel> orders) {
    final alerts = <String>[];
    final newOrders = orders.where((order) => order.status == 'Placed').length;
    final confirmedOrders = orders.where((order) => order.status == 'Confirmed').length;
    final readyPickup = orders.where((order) => order.status == 'Ready for pickup').length;
    final paymentsToday = orders.where((order) => order.isPaymentVerified).length;

    if (newOrders > 0) {
      alerts.add('$newOrders new order${newOrders == 1 ? '' : 's'} waiting for acceptance');
    }
    if (confirmedOrders > 0) {
      alerts.add('$confirmedOrders confirmed order${confirmedOrders == 1 ? '' : 's'} should be packed next');
    }
    if (readyPickup > 0) {
      alerts.add('$readyPickup pickup${readyPickup == 1 ? '' : 's'} are ready for riders');
    }
    if (paymentsToday > 0) {
      alerts.add('$paymentsToday payment${paymentsToday == 1 ? '' : 's'} verified recently');
    }
    return alerts;
  }

  Future<void> _handleStatusUpdate(OrderModel order, String status, AppUser actor) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _db.updateOrderStatus(order.id, status, actor: actor);
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Order ${order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber} updated to $status.'),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _openAddProduct(AppUser actor) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final store = await _db.getStoreByOwner(actor.id);
    if (!mounted) {
      return;
    }
    if (store == null) {
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Complete your store registration before adding products.'),
        ),
      );
      await navigator.push(
        MaterialPageRoute(builder: (_) => const VendorRegistrationScreen()),
      );
      if (!mounted) {
        return;
      }
      await _refresh(actor);
      return;
    }
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => AddProductScreen(storeId: store.id),
      ),
    );
    if (!mounted) {
      return;
    }
    await _refresh(actor);
  }

  Future<void> _toggleAcceptingOrders(Store store, bool value, AppUser actor) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _db.saveStore(store.copyWith(isActive: value), actor: actor);
      if (!mounted) {
        return;
      }
      setState(() {
        _storeFuture = Future<Store?>.value(store.copyWith(isActive: value));
      });
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(value ? 'Store is now accepting new orders.' : 'Store is now paused for new orders.'),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _scrollToEarnings() async {
    final earningsContext = _earningsSectionKey.currentContext;
    if (earningsContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      earningsContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
  }

  Future<void> _requestVendorWithdrawal(AppUser actor) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request withdrawal'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount (Rs)',
            hintText: '500',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, double.tryParse(controller.text.trim())),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || amount <= 0 || !mounted) {
      return;
    }
    try {
      await _db.requestVendorWithdraw(amount: amount, actor: actor);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Withdrawal request submitted.'),
        ),
      );
      await _refresh(actor);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _manageVendorPayoutAccount(
    AppUser actor,
    PayoutProfileSummary profile,
  ) async {
    final formValue = await showPayoutAccountDialog(
      context: context,
      title: 'Vendor payout account',
      initialValue: profile,
    );
    if (formValue == null || !mounted) {
      return;
    }
    try {
      await _db.saveVendorPayoutProfile(
        actor: actor,
        methodType: formValue.methodType,
        accountHolderName: formValue.accountHolderName,
        upiId: formValue.upiId,
        bankAccountNumber: formValue.bankAccountNumber,
        bankIfsc: formValue.bankIfsc,
        bankName: formValue.bankName,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Payout account saved successfully.'),
        ),
      );
      await _refresh(actor);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            error.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = context.watch<AuthProvider>().user;
    if (actor == null) {
      return _buildRoot(
        context,
        const AbzioLoadingView(
          title: 'Loading vendor workspace',
          subtitle: 'Preparing your store controls and live order queue.',
        ),
      );
    }
    if (actor.role != 'vendor') {
      return _buildRoot(
        context,
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: AbzioEmptyCard(
              title: 'Vendor access only',
              subtitle: 'Switch to a vendor account to manage store orders, products, and earnings.',
            ),
          ),
        ),
      );
    }

    _ensureFutures(actor);

    return _buildRoot(
      context,
      FutureBuilder<Store?>(
        future: _storeFuture,
        builder: (context, storeSnapshot) {
          if (storeSnapshot.connectionState != ConnectionState.done) {
            return const AbzioLoadingView(
              title: 'Loading your dashboard',
              subtitle: 'Fetching store details, sales metrics, and pending tasks.',
            );
          }

          final store = storeSnapshot.data;
          if (store == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AbzioEmptyCard(
                  title: 'Set up your store first',
                  subtitle: 'Create your storefront to start accepting orders, publishing products, and tracking revenue.',
                  ctaLabel: 'REGISTER STORE',
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const VendorRegistrationScreen()),
                    );
                    if (!mounted) {
                      return;
                    }
                    await _refresh(actor);
                  },
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _refresh(actor),
            child: StreamBuilder<VendorAnalytics>(
              stream: _db.watchPolledValue(
                () => _db.getVendorAnalytics(store.id, actor: actor),
              ),
              builder: (context, analyticsSnapshot) {
                return StreamBuilder<List<OrderModel>>(
                  stream: _db.getVendorOrders(store.id, actor: actor),
                  builder: (context, ordersSnapshot) {
                    if (ordersSnapshot.connectionState == ConnectionState.waiting &&
                        analyticsSnapshot.connectionState != ConnectionState.done) {
                      return const AbzioLoadingView(
                        title: 'Refreshing order pipeline',
                        subtitle: 'Syncing live orders, product highlights, and payout data.',
                      );
                    }

                    final analytics = analyticsSnapshot.data;
                    final orders = ordersSnapshot.data ?? const <OrderModel>[];
                    final products = analytics?.bestSellingProducts ?? const <Product>[];
                    final newOrders = orders.where((order) => order.status == 'Placed').toList();
                    final processingOrders =
                        orders.where((order) => order.status == 'Confirmed' || order.status == 'Packed').toList();
                    final readyOrders = orders.where((order) => order.status == 'Ready for pickup').toList();
                    final completedOrders = orders
                        .where((order) =>
                            order.status == 'Delivered' ||
                            order.status == 'Out for delivery' ||
                            order.status == 'Picked up')
                        .toList();
                    final pendingOrders = orders
                        .where((order) =>
                            order.status == 'Placed' || order.status == 'Confirmed' || order.status == 'Packed')
                        .length;
                    final todayRevenue = _todayRevenue(orders);
                    final totalRevenue = analytics?.totalSales ?? orders.fold<double>(0, (sum, order) => sum + order.totalAmount);
                    final pendingPayouts = orders
                        .where((order) => order.payoutStatus != 'Paid')
                        .fold<double>(0, (sum, order) => sum + order.vendorEarnings);
                    final alerts = _buildAlerts(orders);

                    return ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        _VendorWelcomeBanner(
                          vendorName: actor.name.trim().isEmpty ? 'Vendor' : actor.name.trim(),
                          store: store,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Today at a glance',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        VendorSummaryCards(
                          metrics: [
                            VendorSummaryMetric(
                              label: "Today's Orders",
                              value: '${_todayOrderCount(orders)}',
                              icon: Icons.local_mall_outlined,
                              tint: const Color(0xFFD4AF37),
                              subtext: 'Live order volume',
                            ),
                            VendorSummaryMetric(
                              label: 'Pending Orders',
                              value: '$pendingOrders',
                              icon: Icons.hourglass_top_rounded,
                              tint: const Color(0xFFB76E00),
                              subtext: 'Needs action',
                            ),
                            VendorSummaryMetric(
                              label: 'Revenue Today',
                              value: _money(todayRevenue),
                              icon: Icons.trending_up_rounded,
                              tint: const Color(0xFF1C9A5F),
                              subtext: 'Gross sales today',
                            ),
                            VendorSummaryMetric(
                              label: 'Total Revenue',
                              value: _money(totalRevenue),
                              icon: Icons.account_balance_wallet_outlined,
                              tint: const Color(0xFF635BFF),
                              subtext: 'Lifetime gross sales',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Quick actions',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        VendorQuickActions(
                          actions: [
                            VendorQuickActionItem(
                              icon: Icons.add_box_outlined,
                              label: 'Add Product',
                              onTap: () => _openAddProduct(actor),
                            ),
                            VendorQuickActionItem(
                              icon: Icons.receipt_long_outlined,
                              label: 'View Orders',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => OrderManagementScreen(actor: actor, store: store),
                                  ),
                                );
                              },
                            ),
                            VendorQuickActionItem(
                              icon: Icons.storefront_outlined,
                              label: 'Manage Store',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => StoreSettingsScreen(store: store),
                                  ),
                                );
                              },
                            ),
                            VendorQuickActionItem(
                              icon: Icons.payments_outlined,
                              label: 'View Earnings',
                              onTap: _scrollToEarnings,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _StoreStatusCard(
                          store: store,
                          onChanged: (value) => _toggleAcceptingOrders(store, value, actor),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Orders to process',
                                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => OrderManagementScreen(actor: actor, store: store),
                                  ),
                                );
                              },
                              child: const Text('Open full queue'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F2E4),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            labelColor: Colors.white,
                            unselectedLabelColor: const Color(0xFF6E6E6E),
                            indicator: BoxDecoration(
                              color: const Color(0xFFD4AF37),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
                            tabs: const [
                              Tab(text: 'New'),
                              Tab(text: 'Processing'),
                              Tab(text: 'Ready'),
                              Tab(text: 'Completed'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 360,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              SingleChildScrollView(
                                child: VendorOrdersTab(
                                  orders: newOrders,
                                  emptyTitle: 'No new orders yet',
                                  emptySubtitle: 'Fresh orders will appear here the moment shoppers place them.',
                                  onConfirm: (order) => _handleStatusUpdate(order, 'Confirmed', actor),
                                  onPacked: (order) => _handleStatusUpdate(order, 'Packed', actor),
                                  formatCurrency: _money,
                                ),
                              ),
                              SingleChildScrollView(
                                child: VendorOrdersTab(
                                  orders: processingOrders,
                                  emptyTitle: 'Processing queue is clear',
                                  emptySubtitle: 'Confirmed and packed orders will appear here for quick action.',
                                  onConfirm: (order) => _handleStatusUpdate(order, 'Confirmed', actor),
                                  onPacked: (order) => _handleStatusUpdate(order, 'Packed', actor),
                                  formatCurrency: _money,
                                ),
                              ),
                              SingleChildScrollView(
                                child: VendorOrdersTab(
                                  orders: readyOrders,
                                  emptyTitle: 'Nothing waiting for pickup',
                                  emptySubtitle: 'Orders marked ready will show here until a rider accepts them.',
                                  onConfirm: (order) => _handleStatusUpdate(order, 'Confirmed', actor),
                                  onPacked: (order) => _handleStatusUpdate(order, 'Packed', actor),
                                  formatCurrency: _money,
                                ),
                              ),
                              SingleChildScrollView(
                                child: VendorOrdersTab(
                                  orders: completedOrders,
                                  emptyTitle: 'Completed orders will land here',
                                  emptySubtitle: 'This view helps you review delivered and in-flight fulfillment quickly.',
                                  onConfirm: (order) => _handleStatusUpdate(order, 'Confirmed', actor),
                                  onPacked: (order) => _handleStatusUpdate(order, 'Packed', actor),
                                  formatCurrency: _money,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        FutureBuilder<WalletSummary>(
                          future: _db.getVendorWallet(actor: actor),
                          builder: (context, walletSnapshot) {
                            final wallet = walletSnapshot.data;
                              return KeyedSubtree(
                                key: _earningsSectionKey,
                                child: _EarningsSection(
                                todayEarnings: orders
                                    .where((order) {
                                      final now = DateTime.now();
                                      return order.timestamp.year == now.year &&
                                          order.timestamp.month == now.month &&
                                          order.timestamp.day == now.day;
                                    })
                                    .fold<double>(0, (sum, order) => sum + order.vendorEarnings),
                                weeklyEarnings: _weeklyRevenue(orders),
                                pendingPayouts: wallet?.pendingAmount ?? pendingPayouts,
                                availableBalance: wallet?.balance ?? analytics?.availableBalance ?? store.walletBalance,
                                  reservedWithdrawals: wallet?.reservedAmount ?? 0,
                                  commissionRate: wallet?.commissionRate ?? store.commissionRate,
                                  payoutProfile: wallet?.payoutProfile ?? const PayoutProfileSummary.empty(),
                                  lastPayoutAmount: analytics?.lastPayoutAmount ?? 0,
                                  lastPayoutAt: analytics?.lastPayoutAt ?? '',
                                  ordersCompleted: analytics?.ordersCompleted ?? completedOrders.length,
                                  salesTrend: analytics?.salesTrend ?? const <AnalyticsPoint>[],
                                  transactions: analytics?.transactions ?? const <WalletTransaction>[],
                                  formatCurrency: _money,
                                  onWithdraw: () {
                                    final profile =
                                        wallet?.payoutProfile ?? const PayoutProfileSummary.empty();
                                    if (!profile.isConfigured) {
                                      _manageVendorPayoutAccount(actor, profile);
                                      return;
                                    }
                                    _requestVendorWithdrawal(actor);
                                  },
                                  onManagePayoutAccount: () => _manageVendorPayoutAccount(
                                    actor,
                                    wallet?.payoutProfile ?? const PayoutProfileSummary.empty(),
                                  ),
                                ),
                              );
                            },
                        ),
                        const SizedBox(height: 20),
                        _AlertsSection(alerts: alerts),
                        const SizedBox(height: 20),
                        _ProductPreviewSection(
                          products: products,
                          formatCurrency: _money,
                          onAddProduct: () => _openAddProduct(actor),
                          onManageProducts: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProductManagementScreen(storeId: store.id),
                              ),
                            );
                          },
                        ),
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

  Widget _buildRoot(BuildContext context, Widget child) {
    if (widget.embedded) {
      return ColoredBox(
        color: const Color(0xFFFAFAFA),
        child: child,
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF0D98A), Color(0xFFD4AF37)],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'A',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ABZORA Vendor',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111111),
                  ),
                ),
                Text(
                  'Revenue-focused control panel',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF7C7C7C),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: child,
    );
  }
}

class _VendorWelcomeBanner extends StatelessWidget {
  const _VendorWelcomeBanner({
    required this.vendorName,
    required this.store,
  });

  final String vendorName;
  final Store store;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E6), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFF0DFC0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
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
                  'Welcome back, $vendorName',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  store.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7A5A00),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  store.city.trim().isEmpty
                      ? 'Keep products fresh, move orders faster, and stay ready for peak demand.'
                      : 'Serving shoppers in ${store.city} with faster order processing and clearer revenue visibility.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: const Color(0xFF5E5E5E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.insights_rounded, color: Color(0xFFD4AF37), size: 32),
          ),
        ],
      ),
    );
  }
}

class _StoreStatusCard extends StatelessWidget {
  const _StoreStatusCard({
    required this.store,
    required this.onChanged,
  });

  final Store store;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AbzioTheme.grey100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
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
                Text(
                  'Accepting Orders',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  store.isActive
                      ? 'Your storefront is visible and ready to receive new orders.'
                      : 'Pause incoming orders while you update stock, staffing, or delivery timing.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: const Color(0xFF6C6C6C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: store.isActive,
            activeThumbColor: const Color(0xFFD4AF37),
            activeTrackColor: const Color(0xFFD4AF37).withValues(alpha: 0.34),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _EarningsSection extends StatelessWidget {
  const _EarningsSection({
    required this.todayEarnings,
    required this.weeklyEarnings,
    required this.pendingPayouts,
    required this.availableBalance,
    required this.reservedWithdrawals,
    required this.commissionRate,
    required this.payoutProfile,
    required this.lastPayoutAmount,
    required this.lastPayoutAt,
    required this.ordersCompleted,
    required this.salesTrend,
    required this.transactions,
    required this.formatCurrency,
    this.onWithdraw,
    this.onManagePayoutAccount,
  });

  final double todayEarnings;
  final double weeklyEarnings;
  final double pendingPayouts;
  final double availableBalance;
  final double reservedWithdrawals;
  final double? commissionRate;
  final PayoutProfileSummary payoutProfile;
  final double lastPayoutAmount;
  final String lastPayoutAt;
  final int ordersCompleted;
  final List<AnalyticsPoint> salesTrend;
  final List<WalletTransaction> transactions;
  final String Function(double amount) formatCurrency;
  final VoidCallback? onWithdraw;
  final VoidCallback? onManagePayoutAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AbzioTheme.grey100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Available ${formatCurrency(availableBalance)} • Reserved ${formatCurrency(reservedWithdrawals)} • Commission ${((commissionRate ?? 0.12) * 100).toStringAsFixed(0)}%',
            style: GoogleFonts.inter(color: AbzioTheme.grey500, fontSize: 12),
          ),
          const SizedBox(height: 14),
          PayoutAccountSummaryCard(
            title: 'Settlement destination',
            profile: payoutProfile,
            onManage: onManagePayoutAccount ?? () {},
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _EarningTile(
                  label: 'Orders completed',
                  value: '$ordersCompleted',
                  tint: const Color(0xFF111111),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _EarningTile(
                  label: 'Last payout',
                  value: lastPayoutAmount > 0 ? formatCurrency(lastPayoutAmount) : 'Pending',
                  tint: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          if (lastPayoutAt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Last payout on $lastPayoutAt',
              style: GoogleFonts.inter(color: AbzioTheme.grey500, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _EarningTile(
                  label: "Today's earnings",
                  value: formatCurrency(todayEarnings),
                  tint: const Color(0xFF1C9A5F),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _EarningTile(
                  label: 'Weekly earnings',
                  value: formatCurrency(weeklyEarnings),
                  tint: const Color(0xFF635BFF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _EarningTile(
                  label: 'Pending payouts',
                  value: formatCurrency(pendingPayouts),
                  tint: const Color(0xFFD97A00),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (salesTrend.isNotEmpty) ...[
            _CompactEarningsChart(
              title: 'Daily earnings',
              points: salesTrend,
              accent: const Color(0xFFD4AF37),
            ),
            const SizedBox(height: 14),
          ],
          if (transactions.isNotEmpty) ...[
            Text(
              'Recent finance activity',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...transactions.take(3).map(
              (transaction) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, size: 18, color: Color(0xFF6B6B6B)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        transaction.note.isEmpty ? transaction.status : transaction.note,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF555555)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatCurrency(transaction.amount.abs()),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
                onPressed: onWithdraw,
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                label: const Text('Withdraw'),
              ),
          ),
        ],
      ),
    );
  }
}

class _EarningTile extends StatelessWidget {
  const _EarningTile({
    required this.label,
    required this.value,
    required this.tint,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111111),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CompactEarningsChart extends StatelessWidget {
  const _CompactEarningsChart({
    required this.title,
    required this.points,
    required this.accent,
  });

  final String title;
  final List<AnalyticsPoint> points;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<double>(1, (current, point) => point.value > current ? point.value : current);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 104,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points.map((point) {
                final height = maxValue == 0 ? 8.0 : ((point.value / maxValue) * 64).clamp(8, 64).toDouble();
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          point.label,
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF666666)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsSection extends StatelessWidget {
  const _AlertsSection({required this.alerts});

  final List<String> alerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AbzioTheme.grey100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notifications',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            Text(
              'No new alerts right now. Fresh orders, pickups, and verified payments will show here.',
              style: GoogleFonts.inter(color: const Color(0xFF707070), height: 1.45),
            )
          else
            ...alerts.map(
              (alert) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD4AF37),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        alert,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.45,
                          color: const Color(0xFF444444),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductPreviewSection extends StatelessWidget {
  const _ProductPreviewSection({
    required this.products,
    required this.formatCurrency,
    required this.onAddProduct,
    required this.onManageProducts,
  });

  final List<Product> products;
  final String Function(double amount) formatCurrency;
  final VoidCallback onAddProduct;
  final VoidCallback onManageProducts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Your Products',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: onManageProducts,
              child: const Text('Manage all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 238,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.isEmpty ? 1 : products.take(6).length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (products.isEmpty || index == products.take(6).length) {
                return _AddProductCard(onTap: onAddProduct);
              }
              final product = products[index];
              return _ProductPreviewCard(
                product: product,
                formatCurrency: formatCurrency,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductPreviewCard extends StatelessWidget {
  const _ProductPreviewCard({
    required this.product,
    required this.formatCurrency,
  });

  final Product product;
  final String Function(double amount) formatCurrency;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 188,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AbzioTheme.grey100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: SizedBox(
              height: 120,
              width: double.infinity,
              child: AbzioNetworkImage(
                imageUrl: product.images.isNotEmpty ? product.images.first : '',
                fallbackLabel: product.name,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.brand.trim().isEmpty ? 'ABZORA' : product.brand,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7A5A00),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.name,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  formatCurrency(product.price),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F6F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    product.isActive ? 'Active' : 'Hidden',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddProductCard extends StatelessWidget {
  const _AddProductCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          width: 188,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE8D9AB), style: BorderStyle.solid),
            color: const Color(0xFFFFFBF0),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.add_rounded, color: Color(0xFFD4AF37), size: 30),
              ),
              const SizedBox(height: 14),
              Text(
                'Add Product',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Launch a new style quickly and keep your catalog fresh.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.4,
                  color: const Color(0xFF6F6F6F),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
