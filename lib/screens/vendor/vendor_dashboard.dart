import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../utils/app_error_text.dart';
import '../../utils/app_mode_routes.dart';
import '../../widgets/payout_account_dialog.dart';
import '../../widgets/state_views.dart';
import '../../widgets/tap_scale.dart';
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

class _VendorDashboardState extends State<VendorDashboard>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final ScrollController _scrollController = ScrollController();
  late final TabController _tabController;

  Future<Store?>? _storeFuture;
  Future<List<OrderModel>>? _ordersFuture;
  Future<VendorAnalytics>? _analyticsFuture;
  String? _boundActorId;
  String? _boundStoreId;
  bool _showMoreInsights = false;

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

  void _ensureDashboardFutures(AppUser actor, Store store) {
    if (_boundActorId == actor.id &&
        _boundStoreId == store.id &&
        _ordersFuture != null &&
        _analyticsFuture != null) {
      return;
    }
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
      await Future.wait<void>([
        _ordersFuture!.then((_) {}),
        _analyticsFuture!.then((_) {}),
      ]);
    }
  }

  String _money(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  int _todayOrderCount(List<OrderModel> orders) {
    final now = DateTime.now();
    return orders.where((order) {
      final time = order.timestamp;
      return time.year == now.year &&
          time.month == now.month &&
          time.day == now.day;
    }).length;
  }

  double _todayRevenue(List<OrderModel> orders) {
    final now = DateTime.now();
    return orders
        .where(
          (order) =>
              order.timestamp.year == now.year &&
              order.timestamp.month == now.month &&
              order.timestamp.day == now.day,
        )
        .fold<double>(0, (sum, order) => sum + order.totalAmount);
  }

  double _todayCommission(List<OrderModel> orders) {
    final now = DateTime.now();
    return orders
        .where(
          (order) =>
              order.timestamp.year == now.year &&
              order.timestamp.month == now.month &&
              order.timestamp.day == now.day,
        )
        .fold<double>(0, (sum, order) => sum + order.platformCommission);
  }

  String _trendVsYesterday(List<OrderModel> orders) {
    final now = DateTime.now();
    final todayRevenue = orders
        .where(
          (order) =>
              order.timestamp.year == now.year &&
              order.timestamp.month == now.month &&
              order.timestamp.day == now.day,
        )
        .fold<double>(0, (sum, order) => sum + order.totalAmount);
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayRevenue = orders
        .where(
          (order) =>
              order.timestamp.year == yesterday.year &&
              order.timestamp.month == yesterday.month &&
              order.timestamp.day == yesterday.day,
        )
        .fold<double>(0, (sum, order) => sum + order.totalAmount);
    if (yesterdayRevenue <= 0) {
      return todayRevenue > 0 ? '+100%' : '0%';
    }
    final trend = ((todayRevenue - yesterdayRevenue) / yesterdayRevenue) * 100;
    final sign = trend >= 0 ? '+' : '';
    return '$sign${trend.toStringAsFixed(0)}%';
  }

  List<String> _aiInsights({
    required List<OrderModel> orders,
    required List<Product> products,
    required int pendingOrders,
  }) {
    final insights = <String>[];
    final lowStockCount = products
        .where((p) => p.stock > 0 && p.stock <= 5)
        .length;
    if (lowStockCount > 0) {
      insights.add(
        'Low stock alert: $lowStockCount styles are moving quickly today.',
      );
    }
    final discountedProducts = products.where((p) {
      final original = p.originalPrice ?? p.basePrice;
      return original != null && original > p.effectivePrice;
    }).length;
    if (discountedProducts > 0) {
      insights.add(
        'Products with discounts are converting faster in your catalog.',
      );
    }
    if (pendingOrders >= 6) {
      insights.add(
        'High pending queue: process top orders now to protect delivery speed.',
      );
    }
    if (_todayOrderCount(orders) >= 8) {
      insights.add(
        'Strong demand today. Prioritize best sellers and low-stock SKUs.',
      );
    }
    if (insights.isEmpty) {
      insights.add('Reduce price by ₹200 on slow movers to lift conversion.');
    }
    return insights.take(3).toList();
  }

  List<String> _buildAlerts(List<OrderModel> orders) {
    final alerts = <String>[];
    final newOrders = orders.where((order) => order.status == 'Placed').length;
    final confirmedOrders = orders
        .where((order) => order.status == 'Confirmed')
        .length;
    final readyPickup = orders
        .where((order) => order.status == 'Ready for pickup')
        .length;
    final paymentsToday = orders
        .where((order) => order.isPaymentVerified)
        .length;

    if (newOrders > 0) {
      alerts.add(
        '$newOrders new order${newOrders == 1 ? '' : 's'} waiting for acceptance',
      );
    }
    if (confirmedOrders > 0) {
      alerts.add(
        '$confirmedOrders confirmed order${confirmedOrders == 1 ? '' : 's'} should be packed next',
      );
    }
    if (readyPickup > 0) {
      alerts.add(
        '$readyPickup pickup${readyPickup == 1 ? '' : 's'} are ready for riders',
      );
    }
    if (paymentsToday > 0) {
      alerts.add(
        '$paymentsToday payment${paymentsToday == 1 ? '' : 's'} verified recently',
      );
    }
    return alerts;
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
          content: Text(
            'Complete your store registration before adding products.',
          ),
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
      MaterialPageRoute(builder: (_) => AddProductScreen(storeId: store.id)),
    );
    if (!mounted) {
      return;
    }
    await _refresh(actor);
  }

  Future<void> _toggleAcceptingOrders(
    Store store,
    bool value,
    AppUser actor,
  ) async {
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
          content: Text(
            value
                ? 'Store is now accepting new orders.'
                : 'Store is now paused for new orders.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(AppErrorText.from(error)),
        ),
      );
    }
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
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.trim()),
            ),
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
          content: Text(AppErrorText.from(error)),
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
          content: Text(AppErrorText.from(error)),
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
    if (!hasVendorOperationsAccess(actor)) {
      return _buildRoot(
        context,
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: AbzioEmptyCard(
              title: 'Vendor access only',
              subtitle:
                  'Switch to a vendor account to manage store orders, products, and earnings.',
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
              subtitle:
                  'Fetching store details, sales metrics, and pending tasks.',
            );
          }

          final store = storeSnapshot.data;
          if (store == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AbzioEmptyCard(
                  title: 'Set up your store first',
                  subtitle:
                      'Create your storefront to start accepting orders, publishing products, and tracking revenue.',
                  ctaLabel: 'REGISTER STORE',
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const VendorRegistrationScreen(),
                      ),
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

          _ensureDashboardFutures(actor, store);

          return RefreshIndicator(
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
                        title: 'Refreshing order pipeline',
                        subtitle:
                            'Syncing live orders, product highlights, and payout data.',
                      );
                    }

                    final analytics = analyticsSnapshot.data;
                    final orders = List<OrderModel>.of(
                      ordersSnapshot.data ?? const <OrderModel>[],
                    )..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                    final products =
                        analytics?.bestSellingProducts ?? const <Product>[];
                    final pendingOrders = orders
                        .where(
                          (order) =>
                              order.status == 'Placed' ||
                              order.status == 'Confirmed' ||
                              order.status == 'Packed',
                        )
                        .length;
                    final todayRevenue = _todayRevenue(orders);
                    final totalRevenue =
                        analytics?.totalSales ??
                        orders.fold<double>(
                          0,
                          (sum, order) => sum + order.totalAmount,
                        );
                    final pendingPayouts = orders
                        .where((order) => order.payoutStatus != 'Paid')
                        .fold<double>(
                          0,
                          (sum, order) => sum + order.vendorEarnings,
                        );
                    final alerts = _buildAlerts(orders);
                    final trendText = _trendVsYesterday(orders);
                    final insights = _aiInsights(
                      orders: orders,
                      products: products,
                      pendingOrders: pendingOrders,
                    );
                    final completedToday = orders
                        .where((order) => order.status == 'Delivered')
                        .length;
                    final refundsCount = orders
                        .where(
                          (order) => order.refundStatus.toLowerCase() != 'none',
                        )
                        .length;
                    final averageOrderValue = orders.isEmpty
                        ? 0.0
                        : totalRevenue / orders.length;

                    return ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 320),
                          builder: (context, opacity, child) => Opacity(
                            opacity: opacity,
                            child: Transform.translate(
                              offset: Offset(0, (1 - opacity) * 8),
                              child: child,
                            ),
                          ),
                          child: _LuxuryHeaderCard(
                            storeName: store.name.trim().isEmpty
                                ? 'Abianzo Partner'
                                : store.name,
                            acceptingOrders: store.isActive,
                            onToggle: (value) =>
                                _toggleAcceptingOrders(store, value, actor),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _PriorityOrdersCard(
                          pendingOrders: pendingOrders,
                          onProcessOrders: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => OrderManagementScreen(
                                  actor: actor,
                                  store: store,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _PrimaryMetricsRow(
                          revenueToday: _money(todayRevenue),
                          trend: trendText,
                          completedCount: completedToday,
                          pendingCount: pendingOrders,
                        ),
                        const SizedBox(height: 16),
                        _AiInsightsCard(
                          insights: insights,
                          onViewPricing: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PricingManagementScreen(storeId: store.id),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _QuickActionGrid(
                          onAddProduct: () => _openAddProduct(actor),
                          onOrders: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => OrderManagementScreen(
                                  actor: actor,
                                  store: store,
                                ),
                              ),
                            );
                          },
                          onPricing: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PricingManagementScreen(storeId: store.id),
                              ),
                            );
                          },
                          onManageStore: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    StoreSettingsScreen(store: store),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<WalletSummary>(
                          future: _db.getVendorWallet(actor: actor),
                          builder: (context, walletSnapshot) {
                            final wallet = walletSnapshot.data;
                            return _MergedEarningsCard(
                              availableBalance: _money(
                                (wallet?.balance ??
                                        analytics?.availableBalance ??
                                        store.walletBalance)
                                    .toDouble(),
                              ),
                              pendingSettlement: _money(
                                (wallet?.pendingAmount ?? pendingPayouts)
                                    .toDouble(),
                              ),
                              onWithdraw: () {
                                final profile =
                                    wallet?.payoutProfile ??
                                    const PayoutProfileSummary.empty();
                                if (!profile.isConfigured) {
                                  _manageVendorPayoutAccount(actor, profile);
                                  return;
                                }
                                _requestVendorWithdrawal(actor);
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _MoreInsightsCard(
                          expanded: _showMoreInsights,
                          onToggle: () {
                            setState(() {
                              _showMoreInsights = !_showMoreInsights;
                            });
                          },
                          commissionToday: _money(_todayCommission(orders)),
                          avgOrderValue: _money(averageOrderValue),
                          refundsCount: refundsCount,
                        ),
                        const SizedBox(height: 16),
                        if (orders.isEmpty && products.isEmpty)
                          _VendorEmptyState(
                            onAddProduct: () => _openAddProduct(actor),
                          )
                        else
                          _AlertsSection(alerts: alerts),
                        if (orders.isNotEmpty || products.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _ProductPreviewSection(
                            products: products,
                            formatCurrency: _money,
                            onAddProduct: () => _openAddProduct(actor),
                            onManageProducts: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProductManagementScreen(
                                    storeId: store.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
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
      return ColoredBox(color: const Color(0xFFFAFAFA), child: child);
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
                color: Colors.white,
                border: Border.all(color: const Color(0xFFEAEAEA)),
              ),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/branding/abzora_partner_icon.png',
                  fit: BoxFit.cover,
                  width: 30,
                  height: 30,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Abianzo Vendor',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
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
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () => Navigator.pushNamed(context, '/vendor-profile'),
            icon: const Icon(Icons.person_outline_rounded),
          ),
          IconButton(
            tooltip: 'Invoices',
            onPressed: () => Navigator.pushNamed(context, '/invoice/hub'),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      body: child,
    );
  }
}

class _LuxuryHeaderCard extends StatelessWidget {
  const _LuxuryHeaderCard({
    required this.storeName,
    required this.acceptingOrders,
    required this.onToggle,
  });

  final String storeName;
  final bool acceptingOrders;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
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
                  storeName,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF171717),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: acceptingOrders
                            ? const Color(0xFF2FA36B)
                            : const Color(0xFFB5B5B5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      acceptingOrders
                          ? 'You are visible to customers'
                          : 'Store visibility paused',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF6B6A68),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Accepting Orders',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5E5A53),
                ),
              ),
              const SizedBox(height: 6),
              Switch.adaptive(
                value: acceptingOrders,
                activeThumbColor: const Color(0xFFC8A96A),
                activeTrackColor: const Color(
                  0xFFC8A96A,
                ).withValues(alpha: 0.35),
                onChanged: onToggle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriorityOrdersCard extends StatelessWidget {
  const _PriorityOrdersCard({
    required this.pendingOrders,
    required this.onProcessOrders,
  });

  final int pendingOrders;
  final VoidCallback onProcessOrders;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: pendingOrders > 0
            ? const Color(0xFFFFF0EA)
            : const Color(0xFFF8F6F2),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFFD27F58,
            ).withValues(alpha: pendingOrders > 0 ? 0.16 : 0.06),
            blurRadius: 22,
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
                  'Orders Pending',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$pendingOrders',
                  style: GoogleFonts.poppins(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111111),
                  ),
                ),
                Text(
                  'Needs action now',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF7A6D66),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TapScale(
            onTap: onProcessOrders,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFC8A96A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Process Orders',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryMetricsRow extends StatelessWidget {
  const _PrimaryMetricsRow({
    required this.revenueToday,
    required this.trend,
    required this.completedCount,
    required this.pendingCount,
  });

  final String revenueToday;
  final String trend;
  final int completedCount;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'Revenue Today',
            value: revenueToday,
            subtitle: '$trend vs yesterday',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            title: 'Orders Today',
            value: 'Completed $completedCount',
            subtitle: 'Pending $pendingCount',
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF6F6A63),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF151515),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF7B756E),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiInsightsCard extends StatelessWidget {
  const _AiInsightsCard({required this.insights, required this.onViewPricing});

  final List<String> insights;
  final VoidCallback onViewPricing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFFC8A96A),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'AI Insights',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '- $text',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF504B45),
                  height: 1.4,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onViewPricing,
              child: const Text('View Pricing'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({
    required this.onAddProduct,
    required this.onOrders,
    required this.onPricing,
    required this.onManageStore,
  });

  final VoidCallback onAddProduct;
  final VoidCallback onOrders;
  final VoidCallback onPricing;
  final VoidCallback onManageStore;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.35,
      children: [
        _QuickActionTile(
          icon: Icons.add_box_outlined,
          label: 'Add Product',
          onTap: onAddProduct,
        ),
        _QuickActionTile(
          icon: Icons.receipt_long_outlined,
          label: 'Orders',
          onTap: onOrders,
        ),
        _QuickActionTile(
          icon: Icons.price_change_outlined,
          label: 'Pricing',
          onTap: onPricing,
        ),
        _QuickActionTile(
          icon: Icons.storefront_outlined,
          label: 'Manage Store',
          onTap: onManageStore,
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFC8A96A)),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2A2723),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MergedEarningsCard extends StatelessWidget {
  const _MergedEarningsCard({
    required this.availableBalance,
    required this.pendingSettlement,
    required this.onWithdraw,
  });

  final String availableBalance;
  final String pendingSettlement;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings Overview',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Available Balance',
                  value: availableBalance,
                  subtitle: 'Ready to withdraw',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Pending Settlement',
                  value: pendingSettlement,
                  subtitle: 'Will settle soon',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onWithdraw,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC8A96A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Withdraw'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreInsightsCard extends StatelessWidget {
  const _MoreInsightsCard({
    required this.expanded,
    required this.onToggle,
    required this.commissionToday,
    required this.avgOrderValue,
    required this.refundsCount,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String commissionToday;
  final String avgOrderValue;
  final int refundsCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Row(
              children: [
                Text(
                  expanded ? 'More Insights ▲' : 'More Insights ▼',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3D3A36),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  _InsightLine(
                    label: 'Commission Today',
                    value: commissionToday,
                  ),
                  _InsightLine(label: 'Avg Order Value', value: avgOrderValue),
                  _InsightLine(label: 'Refunds', value: '$refundsCount'),
                ],
              ),
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 240),
          ),
        ],
      ),
    );
  }
}

class _InsightLine extends StatelessWidget {
  const _InsightLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF67635E),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D1C1A),
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorEmptyState extends StatelessWidget {
  const _VendorEmptyState({required this.onAddProduct});
  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Start selling on Abianzo',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your first product to receive orders',
            style: GoogleFonts.inter(color: const Color(0xFF6D6A65)),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onAddProduct,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC8A96A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Product'),
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
      padding: const EdgeInsets.all(20),
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
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            Text(
              'No new alerts right now. Fresh orders, pickups, and verified payments will show here.',
              style: GoogleFonts.inter(
                color: const Color(0xFF707070),
                height: 1.45,
              ),
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
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
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
          height: 266,
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.brand.trim().isEmpty ? 'Abianzo' : product.brand,
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
                  maxLines: 1,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F6F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    product.isActive ? 'Active' : 'Hidden',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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
            border: Border.all(
              color: const Color(0xFFE8D9AB),
              style: BorderStyle.solid,
            ),
            color: const Color(0xFFFFFBF0),
          ),
          padding: const EdgeInsets.all(20),
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
                child: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFFD4AF37),
                  size: 30,
                ),
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
