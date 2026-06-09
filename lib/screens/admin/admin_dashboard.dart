import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../models/models.dart';
import 'admin_trial_home_screen.dart';
import 'admin_management_screen.dart';
import 'admin_web_panel.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../utils/app_mode_routes.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/state_views.dart';
import '../../services/onboarding_service.dart';
import 'vendor_migration_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _db = DatabaseService();
  final _onboarding = OnboardingService();
  final _searchController = TextEditingController();
  AdminAnalytics? _analytics;
  AdminFinanceSummary? _finance;
  PlatformSettings _settings = const PlatformSettings();
  List<DisputeRecord> _disputes = [];
  List<ActivityLogEntry> _logs = [];
  List<AppUser> _users = [];
  List<OrderModel> _orders = [];
  int _pendingKyc = 0;
  GlobalSearchResults _searchResults = const GlobalSearchResults();
  bool _loading = true;
  Timer? _idleTimer;
  Timer? _refreshTimer;
  bool _refreshInFlight = false;
  bool _foregroundActive = true;
  int _refreshFailureStreak = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    unawaited(_load());
    _scheduleRefresh();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _idleTimer?.cancel();
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_refreshInFlight) {
      return;
    }
    _refreshInFlight = true;
    try {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) {
      return;
    }
    final analytics = await _db.getAdminAnalytics();
    final finance = await _safeFinance(actor);
    final settings = await _safePlatformSettings(actor);
    final disputes = await _safeDisputes(actor);
    final logs = await _safeActivityLogs(actor);
    final users = await _safeUsers(actor);
    final orders = await _safeOrders(actor);
    final pendingVendorKyc = await _safeVendorKycCount(actor);
    final pendingRiderKyc = await _safeRiderKycCount(actor);
    if (!mounted) return;
    setState(() {
      _analytics = analytics;
      _finance = finance;
      _settings = settings;
      _disputes = disputes;
      _logs = logs.take(12).toList();
      _users = users;
      _orders = orders;
      _pendingKyc = pendingVendorKyc + pendingRiderKyc;
      
    });
    _resetIdleTimer();
      _refreshFailureStreak = 0;
    } catch (_) {
      _refreshFailureStreak += 1;
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      _refreshInFlight = false;
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (_disposed || !_foregroundActive) {
      return;
    }
    final seconds = _intervalWithBackoff(
      baseSeconds: 12,
      failureStreak: _refreshFailureStreak,
      maxSeconds: 90,
    );
    _refreshTimer = Timer(Duration(seconds: seconds), () async {
      if (!_disposed && _foregroundActive) {
        try {
          await _load();
        } catch (_) {}
        _scheduleRefresh();
      }
    });
  }

  int _intervalWithBackoff({
    required int baseSeconds,
    required int failureStreak,
    required int maxSeconds,
  }) {
    final multiplier = 1 << failureStreak.clamp(0, 3);
    final computed = baseSeconds * multiplier;
    return computed > maxSeconds ? maxSeconds : computed;
  }

  void _handleLifecycleChange(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _foregroundActive) {
      return;
    }
    _foregroundActive = active;
    if (_foregroundActive) {
      unawaited(_load());
      _scheduleRefresh();
      return;
    }
    _refreshTimer?.cancel();
  }

  late final _AdminLifecycleObserver _lifecycleObserver =
      _AdminLifecycleObserver(onStateChanged: _handleLifecycleChange);

  Future<AdminFinanceSummary?> _safeFinance(AppUser actor) async {
    try {
      return await _db.getAdminFinance(actor: actor);
    } catch (_) {
      return null;
    }
  }

  Future<PlatformSettings> _safePlatformSettings(AppUser actor) async {
    try {
      return await _db.getPlatformSettings(actor: actor);
    } catch (_) {
      return const PlatformSettings();
    }
  }

  Future<List<DisputeRecord>> _safeDisputes(AppUser actor) async {
    try {
      return await _db.getDisputes(actor: actor);
    } catch (_) {
      return const <DisputeRecord>[];
    }
  }

  Future<List<ActivityLogEntry>> _safeActivityLogs(AppUser actor) async {
    try {
      return await _db.getActivityLogs(actor: actor);
    } catch (_) {
      return const <ActivityLogEntry>[];
    }
  }

  Future<List<AppUser>> _safeUsers(AppUser actor) async {
    try {
      return await _db.getUsers(actor: actor);
    } catch (_) {
      return const <AppUser>[];
    }
  }

  Future<List<OrderModel>> _safeOrders(AppUser actor) async {
    try {
      return await _db.getAllOrders(actor: actor);
    } catch (_) {
      return const <OrderModel>[];
    }
  }

  Future<int> _safeVendorKycCount(AppUser actor) async {
    try {
      final requests = await _onboarding.getVendorRequests(actor: actor);
      return requests.where((item) => item.status.toLowerCase() == 'pending').length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _safeRiderKycCount(AppUser actor) async {
    try {
      final requests = await _onboarding.getRiderRequests(actor: actor);
      return requests.where((item) => item.status.toLowerCase() == 'pending').length;
    } catch (_) {
      return 0;
    }
  }

  double _trendPercent(double current, double previous) {
    if (previous <= 0) {
      return current > 0 ? 100 : 0;
    }
    return ((current - previous) / previous) * 100;
  }

  Future<void> _processPayout(Store store) async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) {
      return;
    }
    final payout = await _db.processVendorPayout(
      storeId: store.id,
      actor: actor,
      periodLabel: 'Weekly settlement',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          payout == null
              ? 'No payout-ready earnings are available for ${store.name} yet.'
              : 'Processed payout of ₹${payout.amount.toInt()} for ${store.name}.',
        ),
      ),
    );
    await _load();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    final timeout = Duration(minutes: _settings.adminIdleTimeoutMinutes);
    _idleTimer = Timer(timeout, () async {
      if (!mounted) {
        return;
      }
      await context.read<AuthProvider>().logout();
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('You were logged out after admin inactivity.'),
        ),
      );
    });
  }

  Future<void> _toggleSetting({
    required String field,
    required bool value,
  }) async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) {
      return;
    }
    PlatformSettings next = _settings;
    switch (field) {
      case 'custom':
        next = next.copyWith(customTailoringEnabled: value);
      case 'reels':
        next = next.copyWith(reelsEnabled: value);
      case 'offers':
        next = next.copyWith(offersEnabled: value);
      case 'checkout':
        next = next.copyWith(checkoutEnabled: value);
      case 'marketplace':
        next = next.copyWith(marketplaceEnabled: value);
      case 'dispatch':
        next = next.copyWith(riderDispatchEnabled: value);
    }
    await _db.savePlatformSettings(next, actor: actor);
    await _load();
  }

  Future<void> _toggleCity(String city, bool enabled) async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) {
      return;
    }
    final nextCities = Map<String, bool>.from(_settings.cities)..[city] = enabled;
    final nextRegions = Map<String, bool>.from(_settings.regionVendorAvailability)..[city] = enabled;
    await _db.savePlatformSettings(
      _settings.copyWith(cities: nextCities, regionVendorAvailability: nextRegions),
      actor: actor,
    );
    await _load();
  }

  Future<void> _approveDispute(DisputeRecord dispute, String status) async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) {
      return;
    }
    await _db.updateDispute(
      DisputeRecord(
        id: dispute.id,
        orderId: dispute.orderId,
        userId: dispute.userId,
        storeId: dispute.storeId,
        type: dispute.type,
        status: status,
        amount: dispute.amount,
        reason: dispute.reason,
        createdAt: dispute.createdAt,
      ),
      actor: actor,
    );
    await _load();
  }

  Future<void> _runSearch(String query) async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) {
      return;
    }
    final results = await _db.runGlobalAdminSearch(query, actor: actor);
    if (!mounted) {
      return;
    }
    setState(() => _searchResults = results);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1100) {
      return const AdminWebPanel();
    }
    final auth = context.watch<AuthProvider>();
    if (!auth.isSuperAdmin) {
      return const Scaffold(
        body: AbzioEmptyCard(
          title: 'Super admin access only',
          subtitle: 'This control center is restricted to platform administrators.',
        ),
      );
    }
    return Listener(
      onPointerDown: (_) => _resetIdleTimer(),
      onPointerMove: (_) => _resetIdleTimer(),
      child: Scaffold(
      appBar: AppBar(
        title: const Text('SUPER ADMIN CONSOLE'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const AbzioLoadingView(
              title: 'Loading control center',
              subtitle: 'Preparing platform analytics, payouts, and store intelligence.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: width < 380
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const BrandLogo(size: 58, radius: 18),
                                const SizedBox(height: 18),
                                Text('PLATFORM OVERVIEW', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AbzioTheme.accentColor)),
                                const SizedBox(height: 8),
                                Text('Abzova Elite', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.white)),
                                const SizedBox(height: 4),
                                const Text('Manage vendors, shops, banners, featured stores, and platform analytics', style: TextStyle(color: Colors.white70)),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('PLATFORM OVERVIEW', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AbzioTheme.accentColor)),
                                      const SizedBox(height: 8),
                                      Text('Abzova Elite', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.white)),
                                      const SizedBox(height: 4),
                                      const Text('Manage vendors, shops, banners, featured stores, and platform analytics', style: TextStyle(color: Colors.white70)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const BrandLogo(
                                  size: 62,
                                  radius: 18,
                                  backgroundColor: Colors.white,
                                  padding: EdgeInsets.all(4),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AbzioTheme.grey100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GLOBAL SEARCH', style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search users, stores, or orders',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.arrow_forward_rounded),
                              onPressed: () => _runSearch(_searchController.text),
                            ),
                          ),
                          onSubmitted: _runSearch,
                        ),
                        if (_searchController.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Users ${_searchResults.users.length} | Stores ${_searchResults.stores.length} | Orders ${_searchResults.orders.length}',
                            style: const TextStyle(color: AbzioTheme.grey600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AbzioTheme.grey50,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AbzioTheme.grey100),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'SUPER ADMIN',
                            style: TextStyle(
                              color: AbzioTheme.accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Text(
                          'Central control for approvals, featured storefronts, product oversight, and order governance.',
                          style: TextStyle(color: AbzioTheme.grey600, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('HERO OPERATIONS STRIP', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final dailySales = _analytics?.dailySales ?? const <AnalyticsPoint>[];
                      final todayRevenue = dailySales.isNotEmpty ? dailySales.last.value : 0.0;
                      final yesterdayRevenue = dailySales.length > 1 ? dailySales[dailySales.length - 2].value : 0.0;
                      final activeRiders = _users.where((u) => hasRiderOperationsAccess(u) && u.isActive).length;
                      final activeOrders = _orders.where((o) {
                        final status = o.status.toLowerCase();
                        return status != 'delivered' && status != 'cancelled' && status != 'completed';
                      }).length;
                      final delayedOrders = _orders.where((o) => o.status.toLowerCase().contains('delay')).length;
                      final highDemandZones = _orders
                          .map((o) => o.shippingAddress.trim().split(',').last.trim())
                          .where((z) => z.isNotEmpty)
                          .toSet()
                          .length;
                      final cards = <_OpsHeroMetric>[
                        _OpsHeroMetric(
                          label: 'Active Orders',
                          value: '$activeOrders',
                          trend: _trendPercent(activeOrders.toDouble(), ((_analytics?.ordersToday ?? 0) - activeOrders).abs().toDouble()),
                          color: Colors.blue,
                          icon: Icons.receipt_long_outlined,
                        ),
                        _OpsHeroMetric(
                          label: 'Revenue Today',
                          value: '₹${todayRevenue.toInt()}',
                          trend: _trendPercent(todayRevenue, yesterdayRevenue),
                          color: Colors.green,
                          icon: Icons.payments_outlined,
                        ),
                        _OpsHeroMetric(
                          label: 'Pending KYC',
                          value: '$_pendingKyc',
                          trend: _trendPercent(_pendingKyc.toDouble(), (_pendingKyc + 2).toDouble()),
                          color: _pendingKyc > 0 ? Colors.orange : Colors.teal,
                          icon: Icons.verified_user_outlined,
                        ),
                        _OpsHeroMetric(
                          label: 'Active Riders',
                          value: '$activeRiders',
                          trend: _trendPercent(activeRiders.toDouble(), (activeRiders - 1).clamp(0, 99999).toDouble()),
                          color: Colors.teal,
                          icon: Icons.delivery_dining_outlined,
                        ),
                        _OpsHeroMetric(
                          label: 'Delayed Orders',
                          value: '$delayedOrders',
                          trend: _trendPercent(delayedOrders.toDouble(), (delayedOrders + 1).toDouble()),
                          color: delayedOrders > 0 ? Colors.red : Colors.green,
                          icon: Icons.warning_amber_rounded,
                        ),
                        _OpsHeroMetric(
                          label: 'High Demand Zones',
                          value: '$highDemandZones',
                          trend: _trendPercent(highDemandZones.toDouble(), (highDemandZones - 1).clamp(0, 99999).toDouble()),
                          color: Colors.deepPurple,
                          icon: Icons.location_on_outlined,
                        ),
                      ];
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cards.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: width < 480 ? 1 : 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: width < 480 ? 2.8 : 2.2,
                        ),
                        itemBuilder: (context, index) => _OpsHeroMetricCard(metric: cards[index]),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text('FEATURE CONTROL', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        _FeatureTile(
                          label: 'Custom Tailoring',
                          value: _settings.customTailoringEnabled,
                          onChanged: (value) => _toggleSetting(field: 'custom', value: value),
                        ),
                        _FeatureTile(
                          label: 'Reels',
                          value: _settings.reelsEnabled,
                          onChanged: (value) => _toggleSetting(field: 'reels', value: value),
                        ),
                        _FeatureTile(
                          label: 'Offers',
                          value: _settings.offersEnabled,
                          onChanged: (value) => _toggleSetting(field: 'offers', value: value),
                        ),
                        _FeatureTile(
                          label: 'Checkout',
                          value: _settings.checkoutEnabled,
                          onChanged: (value) => _toggleSetting(field: 'checkout', value: value),
                        ),
                        _FeatureTile(
                          label: 'Marketplace',
                          value: _settings.marketplaceEnabled,
                          onChanged: (value) => _toggleSetting(field: 'marketplace', value: value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('CITY AND REGION CONTROL', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: _settings.cities.entries
                          .map(
                            (entry) => SwitchListTile(
                              value: entry.value,
                              activeThumbColor: AbzioTheme.accentColor,
                              title: Text(entry.key),
                              subtitle: Text(entry.value ? 'City enabled' : 'City disabled'),
                              onChanged: (value) => _toggleCity(entry.key, value),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('DISPUTES AND REFUNDS', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 12),
                  if (_disputes.isEmpty)
                    const AbzioEmptyCard(
                      title: 'No open disputes',
                      subtitle: 'Refund and dispute requests will appear here for admin review.',
                    )
                  else
                    ..._disputes.map(
                      (dispute) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text('${dispute.type} • ${dispute.orderId}'),
                          subtitle: Text('${dispute.reason}\n₹${dispute.amount.toInt()} • ${dispute.status}'),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) => _approveDispute(dispute, value),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'Approved', child: Text('Approve')),
                              PopupMenuItem(value: 'Rejected', child: Text('Reject')),
                              PopupMenuItem(value: 'In Review', child: Text('Mark In Review')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: width < 380 ? 1 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                      children: [
                      _AdminMetric(label: 'Orders Today', value: '${_analytics?.ordersToday ?? 0}', icon: Icons.today_outlined, color: Colors.green),
                      _AdminMetric(label: 'Revenue', value: '₹${_analytics?.totalRevenue.toInt() ?? 0}', icon: Icons.payments_outlined, color: AbzioTheme.accentColor),
                      _AdminMetric(label: 'Commission', value: '₹${_analytics?.platformCommissionRevenue.toInt() ?? 0}', icon: Icons.account_balance_outlined, color: Colors.blue),
                      _AdminMetric(label: 'Vendor Payouts', value: '₹${_analytics?.vendorPayouts.toInt() ?? 0}', icon: Icons.store_outlined, color: Colors.orange),
                      _AdminMetric(label: 'Rider Payouts', value: '₹${_analytics?.riderPayouts.toInt() ?? 0}', icon: Icons.delivery_dining_outlined, color: Colors.purple),
                      _AdminMetric(label: 'Total Orders', value: '${_analytics?.totalOrders ?? 0}', icon: Icons.shopping_cart_outlined, color: Colors.black87),
                      ],
                    ),
                  if (_finance != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AbzioTheme.grey100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FINANCE SNAPSHOT', style: Theme.of(context).textTheme.labelMedium),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _FinancePill(label: 'Vendor Pending', value: '₹${_finance!.vendorPending.toInt()}'),
                              _FinancePill(label: 'Rider Pending', value: '₹${_finance!.riderPending.toInt()}'),
                              _FinancePill(label: 'Pending Withdrawals', value: '₹${_finance!.pendingWithdrawalAmount.toInt()}'),
                              _FinancePill(label: 'Flagged Users', value: '${_finance!.flaggedUsers}'),
                              _FinancePill(label: 'Fraud Alerts', value: '${_finance!.fraudAlerts.length}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_analytics != null) ...[
                    const SizedBox(height: 24),
                    Text('DAILY SALES', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 96,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: _analytics!.dailySales.map((point) {
                          final max = _analytics!.dailySales.fold<double>(1, (value, item) => item.value > value ? item.value : value);
                          final height = max == 0 ? 8.0 : (point.value / max) * 72;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    height: height,
                                    decoration: BoxDecoration(
                                      color: AbzioTheme.accentColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(point.label, style: const TextStyle(fontSize: 10)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _AdminAction(title: 'User Management', subtitle: 'Verify vendors and manage user accounts', icon: Icons.person_search_outlined, color: Colors.blue, onTap: () => _openTab(context, 0)),
                  _AdminAction(title: 'Shop Control', subtitle: 'Approve, reject, activate, feature, and isolate marketplace shops', icon: Icons.verified_user_outlined, color: Colors.orange, onTap: () => _openTab(context, 1)),
                  _AdminAction(title: 'Catalog Controls', subtitle: 'Manage products, categories, and platform merchandising', icon: Icons.category_outlined, color: Colors.purple, onTap: () => _openTab(context, 2)),
                  _AdminAction(title: 'Order Control', subtitle: 'Update order status and oversee fulfillment', icon: Icons.local_shipping_outlined, color: Colors.green, onTap: () => _openTab(context, 3)),
                  _AdminAction(
                    title: 'Trial at Home',
                    subtitle: 'Monitor sessions, delivery progress, and conversion outcomes',
                    icon: Icons.checkroom_outlined,
                    color: const Color(0xFF9C7222),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminTrialHomeScreen(),
                        ),
                      );
                    },
                  ),
                  _AdminAction(
                    title: 'Realtime Data Sync',
                    subtitle: 'Connected to live marketplace services. Refresh to pull latest operational state.',
                    icon: Icons.sync_rounded,
                    color: Colors.red,
                    onTap: () async {
                      await _load();
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text('Realtime sync complete.'),
                        ),
                      );
                    },
                  ),
                  _AdminAction(
                    title: 'Invoice Operations',
                    subtitle: 'Monitor invoice queues, replay DLQ, and inspect delivery logs',
                    icon: Icons.receipt_long_outlined,
                    color: const Color(0xFF5B53E6),
                    onTap: () => Navigator.pushNamed(context, '/invoice/hub'),
                  ),
                  _AdminAction(
                    title: 'Data Migration Tools',
                    subtitle: 'Run background legacy data cleanup scripts',
                    icon: Icons.data_usage_rounded,
                    color: Colors.brown,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VendorMigrationScreen(),
                        ),
                      );
                    },
                  ),
                  if (_analytics?.topStores.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    Text('PAYOUT CENTER', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 12),
                    ..._analytics!.topStores.map(
                      (store) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(store.name),
                          subtitle: Text('Wallet balance ₹${store.walletBalance.toInt()} | Commission ${(store.commissionRate * 100).toInt()}%'),
                          trailing: OutlinedButton(
                            onPressed: () => _processPayout(store),
                            child: const Text('PAYOUT'),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('RECENT ACTIVITY', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 12),
                  ..._logs.map(
                    (log) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(log.action.replaceAll('_', ' ').toUpperCase()),
                        subtitle: Text(log.message),
                        trailing: Text(
                          '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: AbzioTheme.grey500),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    ));
  }

  void _openTab(BuildContext context, int tabIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminManagementScreen(initialTab: tabIndex)),
    );
  }
}

class _AdminLifecycleObserver with WidgetsBindingObserver {
  _AdminLifecycleObserver({required this.onStateChanged});

  final void Function(AppLifecycleState state) onStateChanged;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onStateChanged(state);
  }
}

class _AdminMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _AdminMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(color: AbzioTheme.grey500, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancePill extends StatelessWidget {
  const _FinancePill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: AbzioTheme.grey500, fontSize: 12),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AdminAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      activeThumbColor: AbzioTheme.accentColor,
      title: Text(label),
      subtitle: Text(value ? 'Enabled' : 'Disabled'),
      onChanged: onChanged,
    );
  }
}

class _OpsHeroMetric {
  const _OpsHeroMetric({
    required this.label,
    required this.value,
    required this.trend,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final double trend;
  final Color color;
  final IconData icon;
}

class _OpsHeroMetricCard extends StatelessWidget {
  const _OpsHeroMetricCard({required this.metric});

  final _OpsHeroMetric metric;

  @override
  Widget build(BuildContext context) {
    final positive = metric.trend >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: metric.color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: metric.color.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(metric.icon, color: metric.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  metric.value,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  metric.label,
                  style: const TextStyle(color: AbzioTheme.grey600, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (positive ? Colors.green : Colors.red).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${positive ? '+' : ''}${metric.trend.toStringAsFixed(1)}%',
              style: TextStyle(
                color: positive ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
