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
import '../../widgets/state_views.dart';
import 'add_product_screen.dart';
import 'order_management.dart';
import 'pricing_management_screen.dart';
import 'product_management.dart';
import 'store_settings_screen.dart';
import 'vendor_trial_home_dashboard_screen.dart';

class VendorWorkspaceScreen extends StatefulWidget {
  const VendorWorkspaceScreen({super.key});

  @override
  State<VendorWorkspaceScreen> createState() => _VendorWorkspaceScreenState();
}

class _VendorWorkspaceScreenState extends State<VendorWorkspaceScreen> {
  final DatabaseService _db = DatabaseService();
  final NumberFormat _money = NumberFormat.currency(locale: 'en_IN', symbol: '\\u20B9', decimalDigits: 0);

  int _index = 0;
  bool _loading = true;
  String _orderTab = 'new';
  String _txFilter = 'all';
  String _growthRange = '7d';
  String? _error;
  bool _acceptingOrders = true;
  bool _showEarningsBreakdown = false;

  Store? _store;
  List<OrderModel> _orders = const [];
  VendorAnalytics? _analytics;
  WalletSummary? _wallet;
  CustomVendorQualityState? _qualityState;
  Map<String, dynamic> _growthSummary = const {};
  List<Map<String, dynamic>> _growthRecommendations = const [];
  List<Map<String, dynamic>> _growthPerformance = const [];
  Map<String, dynamic> _growthCharts = const {};

  AppUser? get _actor => context.read<AuthProvider>().user;
  bool get _isCustomVendor => _store?.vendorType == 'custom_vendor';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final actor = _actor;
    if (!hasVendorOperationsAccess(actor)) {
      setState(() {
        _loading = false;
        _error = 'Vendor account required.';
      });
      return;
    }
    final safeActor = actor!;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final store = await _db.getStoreByOwner(safeActor.id);
      if (store == null) throw Exception('Store not found.');
      final futures = <Future<dynamic>>[
        _db.getVendorOrders(store.id, actor: safeActor).first,
        _db.getVendorAnalytics(store.id, actor: safeActor),
        _db.getVendorWallet(actor: safeActor),
        _db.getVendorGrowthSummary(actor: safeActor, range: _growthRange),
        _db.getVendorGrowthRecommendations(actor: safeActor),
        _db.getVendorGrowthProductPerformance(actor: safeActor),
        _db.getVendorGrowthCharts(actor: safeActor),
      ];
      if (store.vendorType == 'custom_vendor') {
        futures.add(_db.getCustomVendorQuality(actor: safeActor));
      }
      final data = await Future.wait<dynamic>(futures);
      if (!mounted) return;
      setState(() {
        _store = store;
        _orders = data[0] as List<OrderModel>;
        _analytics = data[1] as VendorAnalytics;
        _wallet = data[2] as WalletSummary;
        _growthSummary = Map<String, dynamic>.from(data[3] as Map? ?? const {});
        _growthRecommendations = (data[4] as List).cast<Map<String, dynamic>>();
        _growthPerformance = (data[5] as List).cast<Map<String, dynamic>>();
        _growthCharts = Map<String, dynamic>.from(data[6] as Map? ?? const {});
        _qualityState = store.vendorType == 'custom_vendor'
            ? data.last as CustomVendorQualityState
            : null;
        _acceptingOrders = store.isActive;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppErrorText.from(e);
      });
    }
  }

  String m(double v) => _money.format(v);

  Future<void> _setStatus(OrderModel order, String status) async {
    final actor = _actor;
    if (actor == null) return;
    await _db.updateOrderStatus(order.id, status, actor: actor);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated to $status')));
    await _load();
  }

  Future<void> _openCustomOrderDetails(OrderModel order) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF9F7F2),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _CustomOrderDetailSheet(
          order: order,
          money: m,
          onSet: (status) => _setStatus(order, status),
        ),
      ),
    );
  }

  Future<void> _withdraw() async {
    final actor = _actor;
    final wallet = _wallet;
    if (actor == null || wallet == null) return;
    final c = TextEditingController(text: wallet.balance.toStringAsFixed(0));
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Earnings'),
        content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(c.text) ?? 0), child: const Text('Request')),
        ],
      ),
    );
    if (amount == null || amount < 100) return;
    await _db.requestVendorWithdraw(amount: amount, actor: actor);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal requested')));
    await _load();
  }

  Future<void> _applyGrowthSuggestion(Map<String, dynamic> rec) async {
    final actor = _actor;
    if (actor == null) return;
    final productId = rec['productId']?.toString().trim() ?? '';
    if (productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No product linked to this suggestion.')),
      );
      return;
    }
    final perf = _growthPerformance.firstWhere(
      (item) => (item['productId']?.toString() ?? '') == productId,
      orElse: () => const <String, dynamic>{},
    );
    if (perf.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product data unavailable for this suggestion.')),
      );
      return;
    }
    final productName = perf['productName']?.toString() ?? 'Product';
    final currentPrice = ((perf['currentPrice'] ?? 0) as num).toDouble();
    final msg = rec['message']?.toString().toLowerCase() ?? '';
    double targetPrice = currentPrice > 0 ? currentPrice : 1;
    final rupeeReg = RegExp(r'₹\s?(\d+)');
    final match = rupeeReg.firstMatch(rec['message']?.toString() ?? '');
    final parsed = match == null ? null : double.tryParse(match.group(1) ?? '');
    if (msg.contains('lower price') && parsed != null) {
      targetPrice = (targetPrice - parsed).clamp(1, 1000000);
    } else if (msg.contains('increase price') && parsed != null) {
      targetPrice = (targetPrice + parsed).clamp(1, 1000000);
    } else if (msg.contains('discount')) {
      targetPrice = (targetPrice * 0.8).clamp(1, 1000000);
    }
    await _db.updateVendorProductPrice(
      actor: actor,
      productId: productId,
      price: targetPrice,
      originalPrice: currentPrice,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied suggestion to $productName at ${m(targetPrice)}.')),
    );
    await _load();
  }

  Future<void> _completeTrainingModule(CustomVendorTrainingModule module) async {
    final actor = _actor;
    if (actor == null) return;
    await _db.completeCustomVendorTrainingModule(
      moduleKey: module.key,
      actor: actor,
      score: 100,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${module.title} marked as completed')),
    );
    await _load();
  }

  Future<void> _submitSampleReview() async {
    final actor = _actor;
    if (actor == null) return;
    final imagesController = TextEditingController();
    final notesController = TextEditingController();
    final result = await showDialog<(List<String>, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit sample work'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: imagesController,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Sample image URLs',
                hintText: 'Paste one image URL per line',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Optional notes for admin review',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final images = imagesController.text
                  .split(RegExp(r'[\r\n]+'))
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList();
              Navigator.of(context).pop((images, notesController.text.trim()));
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    imagesController.dispose();
    notesController.dispose();
    if (result == null || result.$1.isEmpty) return;
    await _db.submitCustomVendorSampleReview(
      sampleImages: result.$1,
      notes: result.$2,
      actor: actor,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sample work submitted for approval')),
    );
    await _load();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to access your vendor workspace.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay signed in'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      appBar: AppBar(
        title: Text('Abianzo PARTNER', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () => Navigator.pushNamed(context, '/vendor-profile'),
            icon: const Icon(Icons.person_outline_rounded),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const _Skeleton()
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: AbzioEmptyCard(title: 'Unable to load', subtitle: _error!, ctaLabel: 'Retry', onTap: _load)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: IndexedStack(
                    index: _index,
                    children: [
                      _home(),
                      _ordersTab(),
                      const VendorTrialHomeDashboardScreen(),
                      _earnings(),
                      _account(),
                    ],
                  ),
                ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.home_work_outlined), selectedIcon: Icon(Icons.home_work_rounded), label: 'Trials'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Earnings'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Account'),
        ],
      ),
    );
  }

  Widget _home() {
    final a = _analytics!;
    final w = _wallet!;
    final customOrders = _orders.where((order) => order.fulfillmentType == 'custom_tailoring').toList();
    final todayTailoringOrders = customOrders.where((order) {
      final created = DateTime.tryParse(order.createdAt ?? '') ?? order.timestamp;
      final now = DateTime.now();
      return created.year == now.year && created.month == now.month && created.day == now.day;
    }).length;
    final inProduction = customOrders.where((order) {
      return order.customOrderStatus == 'accepted' ||
          order.customOrderStatus == 'in_stitching' ||
          order.customOrderStatus == 'quality_check';
    }).length;
    return ListView(padding: const EdgeInsets.all(12), children: [
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Welcome back, ${_store!.name}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [const Icon(Icons.storefront_rounded, color: AbzioTheme.accentColor), const SizedBox(width: 8), const Expanded(child: Text('Accepting Orders')), Switch(value: _acceptingOrders, onChanged: (v) => setState(() => _acceptingOrders = v))]),
      ])),
      const SizedBox(height: 10),
      _isCustomVendor
          ? _MetricGrid(
              items: [
                ('Today Orders', 'New custom requests', '$todayTailoringOrders', const Color(0xFF374151)),
                ('In Production', 'Accepted or stitching', '$inProduction', const Color(0xFFC2410C)),
                ('Earnings Today', 'Released + pending', m(a.todayEarnings), const Color(0xFF15803D)),
                ('Completed', 'Delivered custom pieces', '${customOrders.where((o) => o.customOrderStatus == 'delivered').length}', const Color(0xFF374151)),
              ],
            )
          : _MetricGrid(items: [('Revenue Today', 'Gross sales', m(a.todayRevenue), const Color(0xFF374151)), ('Earnings Today', 'After commission', m(a.todayEarnings), const Color(0xFF15803D)), ('Pending Orders', 'Need action', '${_orders.where((o) => o.status == 'Placed').length}', const Color(0xFFC2410C)), ('Completed Orders', 'Delivered', '${_orders.where((o) => o.status == 'Delivered' || o.status == 'Completed').length}', const Color(0xFF374151))]),
      const SizedBox(height: 10),
      _MetricGrid3(items: [('Commission Today', m(a.todayCommission), const Color(0xFFB91C1C)), ('Pending Settlement', m(w.pendingAmount), const Color(0xFFC2410C)), ('Available Balance', m(w.balance), const Color(0xFF15803D))]),
      if (_isCustomVendor) ...[
        const SizedBox(height: 10),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tailor Performance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _line('Rating', _store!.rating == 0 ? 'New' : _store!.rating.toStringAsFixed(1)),
              _line('On-time delivery', '${((1 - _store!.customVendorProfile.metrics.delayRate) * 100).toStringAsFixed(0)}%'),
              _line('Order success rate', '${(_store!.customVendorProfile.metrics.orderSuccessRate * 100).toStringAsFixed(0)}%'),
              _line('Production time', '${_store!.customVendorProfile.productionTimeDays} days'),
            ],
          ),
        ),
        if (_qualityState != null) ...[
          const SizedBox(height: 10),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Studio Quality', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _line('Quality score', '${_qualityState!.quality.qualityScore.toStringAsFixed(0)}/100'),
                _line('Visibility tier', _qualityState!.quality.visibilityTier),
                _line('Training status', _qualityState!.training.trainingStatus.replaceAll('_', ' ')),
                _line('Sample approval', _qualityState!.sampleReview.status.replaceAll('_', ' ')),
                _line('Fit success', '${(_qualityState!.quality.fitSuccessRate * 100).toStringAsFixed(0)}%'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final module in _qualityState!.training.modules)
                      ActionChip(
                        avatar: Icon(
                          module.status == 'completed' ? Icons.check_circle_rounded : Icons.school_outlined,
                          size: 18,
                          color: module.status == 'completed' ? const Color(0xFF15803D) : const Color(0xFF8C6A12),
                        ),
                        label: Text(module.title),
                        onPressed: module.status == 'completed'
                            ? null
                            : () => _completeTrainingModule(module),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_qualityState!.sampleReview.status != 'approved')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _submitSampleReview,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Submit sample work'),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Orders in production', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (customOrders.isEmpty)
                const AbzioEmptyCard(title: 'No custom orders yet', subtitle: 'Accepted orders will appear here for stitching and QC.')
              else
                ...customOrders
                    .where((order) => order.customOrderStatus != 'delivered')
                    .take(3)
                    .map((order) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CustomProductionRow(
                            order: order,
                            onTap: () => _openCustomOrderDetails(order),
                          ),
                        )),
            ],
          ),
        ),
      ],
      const SizedBox(height: 10),
      _growthDashboard(),
      const SizedBox(height: 10),
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Quick actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Action(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddProductScreen(storeId: _store!.id))), icon: Icons.add_box_rounded, t: 'Add Product', s: 'Publish new item'),
          _Action(onTap: () => setState(() => _index = 1), icon: Icons.list_alt_rounded, t: _isCustomVendor ? 'Custom Orders' : 'View Orders', s: _isCustomVendor ? 'Stitching workflow' : 'Process quickly'),
          _Action(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreSettingsScreen(store: _store!))), icon: Icons.store_rounded, t: 'Manage Store', s: 'Branding/settings'),
          _Action(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PricingManagementScreen(storeId: _store!.id),
              ),
            ),
            icon: Icons.price_change_rounded,
            t: 'Pricing',
            s: 'Prices and discounts',
          ),
          _Action(onTap: () => setState(() => _index = 2), icon: Icons.payments_rounded, t: 'View Earnings', s: 'Wallet/payouts'),
        ]),
      ])),
    ]);
  }

  Widget _ordersTab() {
    final filtered = _orders.where((o) {
      if (_isCustomVendor && o.fulfillmentType == 'custom_tailoring') {
        if (_orderTab == 'new') return o.customOrderStatus == 'new_order';
        if (_orderTab == 'processing') {
          return o.customOrderStatus == 'accepted' ||
              o.customOrderStatus == 'in_stitching' ||
              o.customOrderStatus == 'quality_check';
        }
        if (_orderTab == 'ready') {
          return o.customOrderStatus == 'ready' || o.customOrderStatus == 'shipped';
        }
        return o.customOrderStatus == 'delivered';
      }
      if (_orderTab == 'new') return o.status == 'Placed';
      if (_orderTab == 'processing') return o.status == 'Confirmed' || o.status == 'Packed';
      if (_orderTab == 'ready') return o.status == 'Ready for pickup';
      return o.status == 'Delivered' || o.status == 'Completed';
    }).toList();
    return ListView(padding: const EdgeInsets.all(12), children: [
      _Card(child: Row(children: [
        _OChip(label: 'New', selected: _orderTab == 'new', onTap: () => setState(() => _orderTab = 'new')),
        _OChip(label: 'Processing', selected: _orderTab == 'processing', onTap: () => setState(() => _orderTab = 'processing')),
        _OChip(label: 'Ready', selected: _orderTab == 'ready', onTap: () => setState(() => _orderTab = 'ready')),
        _OChip(label: 'Completed', selected: _orderTab == 'completed', onTap: () => setState(() => _orderTab = 'completed')),
      ])),
      const SizedBox(height: 10),
      if (filtered.isEmpty) const _Card(child: AbzioEmptyCard(title: 'No orders yet', subtitle: 'New orders will appear here.')),
      ...filtered.map((o) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _isCustomVendor && o.fulfillmentType == 'custom_tailoring'
            ? _CustomOrderCard(order: o, money: m, onSet: _setStatus)
            : _OrderCard(order: o, money: m, onSet: _setStatus),
      )),
      const SizedBox(height: 6),
      if (_orderTab != 'completed') FilledButton.tonal(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderManagementScreen(actor: _actor!, store: _store!))), child: const Text('Open full queue')),
    ]);
  }

  Widget _growthDashboard() {
    final a = _analytics!;
    final localProducts = const <Product>[];
    final conversionRate = ((_growthSummary['conversionRate'] ?? (a.orders == 0 ? 0.0 : (a.ordersCompleted / a.orders) * 100)) as num).toDouble();
    final avgOrderValue = ((_growthSummary['avgOrderValue'] ?? (a.ordersCompleted == 0 ? 0.0 : a.totalSales / a.ordersCompleted)) as num).toDouble();
    final revenue = ((_growthSummary['revenue'] ?? a.totalSales) as num).toDouble();
    final completedOrders = ((_growthSummary['orders'] ?? a.ordersCompleted) as num).toInt();
    final demandHigh = a.ordersToday >= 5;

    final recommendations = _growthRecommendations.isNotEmpty
        ? _growthRecommendations
            .map((item) => (
                  item['title']?.toString() ?? 'AI Recommendation',
                  item['message']?.toString() ?? '',
                  item['priority']?.toString() ?? 'Low',
                  item['recommendation']?.toString() ?? 'Review',
                ))
            .toList()
        : <(String, String, String, String)>[
            (
              'Pricing Optimization',
              'Lower price by ₹300 to increase conversion by 18%',
              'High',
              'Apply Price Suggestion',
            ),
            (
              'Discount Opportunity',
              'Apply 20% discount to clear slow-moving stock',
              'Medium',
              'Apply Discount',
            ),
            (
              'High Demand Alert',
              demandHigh
                  ? 'Increase price by ₹200 to maximize profit'
                  : 'Demand stable. Keep current pricing strategy',
              demandHigh ? 'High' : 'Low',
              'View Pricing',
            ),
          ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Growth Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Smart insights to grow your sales', style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              DropdownButton<String>(
                value: _growthRange,
                underline: const SizedBox.shrink(),
                onChanged: (v) async {
                  setState(() => _growthRange = v ?? '7d');
                  await _load();
                },
                items: const [
                  DropdownMenuItem(value: 'today', child: Text('Today')),
                  DropdownMenuItem(value: '7d', child: Text('7d')),
                  DropdownMenuItem(value: '30d', child: Text('30d')),
                ],
              ),
              const SizedBox(width: 8),
              const Row(
                children: [
                  Icon(Icons.circle, size: 9, color: Color(0xFF16A34A)),
                  SizedBox(width: 4),
                  Text('Live', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              _MoneyKpi(title: 'Revenue', value: m(revenue), trend: '+12%'),
              _MoneyKpi(title: 'Conversion Rate', value: '${conversionRate.toStringAsFixed(1)}%', trend: '+2.3%'),
              _MoneyKpi(title: 'Orders', value: '$completedOrders', trend: '+8%'),
              _MoneyKpi(title: 'Avg Order Value', value: m(avgOrderValue), trend: '+5%'),
            ],
          ),
          const SizedBox(height: 10),
          ...recommendations.take(4).map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _GrowthActionCard(
                recommendationMap: _growthRecommendations.isNotEmpty
                    ? _growthRecommendations.firstWhere(
                        (item) => (item['title']?.toString() ?? '') == r.$1,
                        orElse: () => const <String, dynamic>{},
                      )
                    : const <String, dynamic>{},
                title: r.$1,
                description: r.$2,
                priority: r.$3,
                cta: r.$4,
                onApply: _applyGrowthSuggestion,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text('Product Performance', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (_growthPerformance.isEmpty && localProducts.isEmpty)
            const Text('No products yet', style: TextStyle(color: Colors.black54))
          else if (_growthPerformance.isNotEmpty)
            ..._growthPerformance.take(6).map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(item['productName']?.toString() ?? 'Item', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(m(((item['currentPrice'] ?? 0) as num).toDouble()), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text(item['suggestedAction']?.toString() ?? 'Review', style: const TextStyle(fontSize: 12, color: Color(0xFF15803D))),
                  ],
                ),
              ),
            )
          else
            ...localProducts.map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(m(p.effectivePrice), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    const Text('Performing well', style: TextStyle(fontSize: 12, color: Color(0xFF15803D))),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFBFAF6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFECE4D2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Price vs Conversion', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 72,
                  child: _PriceConversionMiniChart(
                    points: (_growthCharts['points'] as List? ?? const [])
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Best performing price: ${_growthCharts['bestPricePoint'] is Map ? m((((_growthCharts['bestPricePoint'] as Map)['price'] ?? 2999) as num).toDouble()) : '₹2,999'}',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 4),
                const Text('Demand insights: Sneakers trending up | Peak sales: 7-10 PM', style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _earnings() {
    final a = _analytics!;
    final w = _wallet!;
    final allTx = a.transactions;
    final tx = switch (_txFilter) {
      'earnings' => allTx.where((e) => e.type == 'order').toList(),
      'withdrawals' => allTx.where((e) => e.type == 'withdrawal' || e.type == 'payout').toList(),
      'commission' => allTx.where((e) => e.type == 'commission').toList(),
      _ => allTx,
    };

    final trend = a.todayEarnings - (a.weeklyRevenue / 7);
    final trendUp = trend >= 0;
    final nextPayout = DateFormat('EEE, d MMM').format(DateTime.now().add(const Duration(days: 1)));
    final payoutProcessing = w.withdrawalRequests.any((r) => r.status.toLowerCase() == 'pending');

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Earnings Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: [
                  _MoneyKpi(title: 'Available Balance', value: m(w.balance), trend: '+4.2%'),
                  _MoneyKpi(title: 'Pending Settlement', value: m(w.pendingAmount), trend: '-1.3%'),
                  _MoneyKpi(title: 'Today Earnings', value: m(a.todayEarnings), trend: trendUp ? 'up' : 'down'),
                  _MoneyKpi(title: 'Weekly Earnings', value: m(a.weeklyRevenue), trend: '+9.1%'),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                trendUp
                    ? 'You earned ${m(trend.abs())} more than yesterday (up)'
                    : 'Earnings down by ${((trend.abs() / (a.weeklyRevenue == 0 ? 1 : a.weeklyRevenue)) * 100).toStringAsFixed(0)}% this week (down)',
                style: TextStyle(
                  color: trendUp ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setState(() => _showEarningsBreakdown = !_showEarningsBreakdown),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Text('View full breakdown', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Icon(_showEarningsBreakdown ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _showEarningsBreakdown ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                firstChild: Column(
                  children: [
                    _line('Total earnings', m(a.totalEarnings)),
                    _line('Total commission paid', m(a.weeklyCommission + a.todayCommission)),
                  ],
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Withdraw', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _line('Available balance', m(w.balance)),
              _line('Minimum withdrawal', '\u20B9100'),
              _line('Next payout date', nextPayout),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: payoutProcessing ? const Color(0xFFFFF4E5) : const Color(0xFFEAF8EE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  payoutProcessing ? 'Processing payout' : 'Available for withdrawal',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: payoutProcessing ? const Color(0xFF9A6700) : const Color(0xFF15803D),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _withdraw,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC8A96A)),
                  child: Text('Withdraw ${m(w.balance)} ->'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pending settlement includes orders under return window',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                'Secure payouts powered by Razorpay',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _txFilter,
                    underline: const SizedBox.shrink(),
                    onChanged: (v) => setState(() => _txFilter = v ?? 'all'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'earnings', child: Text('Earnings')),
                      DropdownMenuItem(value: 'withdrawals', child: Text('Withdrawals')),
                      DropdownMenuItem(value: 'commission', child: Text('Commission')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (tx.isEmpty)
                const AbzioEmptyCard(title: 'No transactions', subtitle: 'Transactions will show after activity.'),
              ...tx.take(20).map((e) => _TxRow(e: e, money: m)),
            ],
          ),
        ),
      ],
    );
  }
  Widget _account() {
    final store = _store!;
    final wallet = _wallet!;
    return ListView(padding: const EdgeInsets.all(12), children: [
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Store Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _line('Store', store.name),
        _line('Address', store.address),
        _line('Commission', '${(store.commissionRate * 100).toStringAsFixed(1)}%'),
        _line('Payout Profile', wallet.payoutProfile.isConfigured ? 'Configured' : 'Pending'),
        if (_isCustomVendor) _line('Vendor Type', 'Custom tailoring'),
      ])),
      if (_isCustomVendor) ...[
        const SizedBox(height: 10),
        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Custom Tailoring Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _line('Experience', '${store.customVendorProfile.experienceYears} years'),
          _line('Specialization', store.customVendorProfile.specializations.isEmpty ? 'Not set' : store.customVendorProfile.specializations.join(', ')),
          _line('Price range', '${m(store.customVendorProfile.priceRangeMin)} - ${m(store.customVendorProfile.priceRangeMax)}'),
          _line('Production time', '${store.customVendorProfile.productionTimeDays} days'),
          _line('Alterations', store.customVendorProfile.supportsAlterations ? 'Supported' : 'Not supported'),
        ])),
        if (_qualityState != null) ...[
          const SizedBox(height: 10),
          _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Quality & Training', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _line('Quality score', '${_qualityState!.quality.qualityScore.toStringAsFixed(0)}/100'),
            _line('On-time delivery', '${(_qualityState!.quality.onTimeDeliveryRate * 100).toStringAsFixed(0)}%'),
            _line('Fit success', '${(_qualityState!.quality.fitSuccessRate * 100).toStringAsFixed(0)}%'),
            _line('Sample approval', _qualityState!.sampleReview.status.replaceAll('_', ' ')),
            if (_qualityState!.sampleReview.adminFeedback.isNotEmpty)
              _line('Admin feedback', _qualityState!.sampleReview.adminFeedback),
          ])),
        ],
      ],
      const SizedBox(height: 10),
      _Card(child: Column(children: [
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.inventory_2_outlined), title: const Text('Product Management'), subtitle: const Text('Catalogue and stock'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductManagementScreen(storeId: store.id)))),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.settings_outlined), title: const Text('Store Controls'), subtitle: const Text('Branding and operations'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreSettingsScreen(store: store)))),
      ])),
      const SizedBox(height: 10),
      _Card(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout_rounded, color: Color(0xFFB91C1C)),
          title: const Text('Log out'),
          subtitle: const Text('Sign out from this vendor account'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _logout,
        ),
      ),
    ]);
  }

  Widget _line(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: Text(l, style: const TextStyle(color: Colors.black54))), Text(v, style: const TextStyle(fontWeight: FontWeight.w700))]),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 6))]),
        child: child,
      );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<(String, String, String, Color)> items;
  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.6),
        itemBuilder: (_, i) => _Metric(title: items[i].$1, subtitle: items[i].$2, value: items[i].$3, color: items[i].$4),
      );
}

class _MetricGrid3 extends StatelessWidget {
  const _MetricGrid3({required this.items});
  final List<(String, String, Color)> items;
  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.95),
        itemBuilder: (_, i) => _Metric(title: items[i].$1, subtitle: '', value: items[i].$2, color: items[i].$3),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.subtitle, required this.value, required this.color});
  final String title;
  final String subtitle;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFFBFAF7), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEAE6DB))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
          if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.black45)),
          const SizedBox(height: 5),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}

class _MoneyKpi extends StatelessWidget {
  const _MoneyKpi({
    required this.title,
    required this.value,
    this.trend = '',
  });

  final String title;
  final String value;
  final String trend;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFAF6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFECE4D2)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if (trend.isNotEmpty)
              Text(trend, style: const TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _GrowthActionCard extends StatelessWidget {
  const _GrowthActionCard({
    required this.recommendationMap,
    required this.title,
    required this.description,
    required this.priority,
    required this.cta,
    required this.onApply,
  });

  final Map<String, dynamic> recommendationMap;
  final String title;
  final String description;
  final String priority;
  final String cta;
  final Future<void> Function(Map<String, dynamic>) onApply;

  @override
  Widget build(BuildContext context) {
    final bg = switch (priority) {
      'High' => const Color(0xFFFFF4EB),
      'Medium' => const Color(0xFFFFF8F0),
      _ => const Color(0xFFF7F8F8),
    };
    final fg = switch (priority) {
      'High' => const Color(0xFFB45309),
      'Medium' => const Color(0xFF9A6700),
      _ => const Color(0xFF4B5563),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECE4D2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFFC8A96A)),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                child: Text(priority, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: recommendationMap.isEmpty ? null : () => onApply(recommendationMap),
              child: Text(cta),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceConversionMiniChart extends StatelessWidget {
  const _PriceConversionMiniChart({required this.points});

  final List<Map<String, dynamic>> points;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const Center(
        child: Text('Not enough chart data', style: TextStyle(fontSize: 12, color: Colors.black54)),
      );
    }
    return CustomPaint(
      painter: _PriceConversionPainter(points),
      size: const Size(double.infinity, 72),
    );
  }
}

class _PriceConversionPainter extends CustomPainter {
  _PriceConversionPainter(this.points);

  final List<Map<String, dynamic>> points;

  @override
  void paint(Canvas canvas, Size size) {
    final sorted = [...points]
      ..sort((a, b) => ((a['price'] ?? 0) as num).compareTo((b['price'] ?? 0) as num));
    final prices = sorted.map((e) => ((e['price'] ?? 0) as num).toDouble()).toList();
    final conv = sorted.map((e) => ((e['conversionRate'] ?? 0) as num).toDouble()).toList();
    final minP = prices.reduce((a, b) => a < b ? a : b);
    final maxP = prices.reduce((a, b) => a > b ? a : b);
    final minC = conv.reduce((a, b) => a < b ? a : b);
    final maxC = conv.reduce((a, b) => a > b ? a : b);
    final dx = (maxP - minP).abs() < 0.001 ? 1.0 : (maxP - minP);
    final dy = (maxC - minC).abs() < 0.001 ? 1.0 : (maxC - minC);

    final path = Path();
    for (var i = 0; i < sorted.length; i++) {
      final x = ((prices[i] - minP) / dx) * (size.width - 8) + 4;
      final y = size.height - ((((conv[i] - minC) / dy) * (size.height - 12)) + 6);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final line = Paint()
      ..color = const Color(0xFFC8A96A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _PriceConversionPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _Action extends StatelessWidget {
  const _Action({required this.onTap, required this.icon, required this.t, required this.s});
  final VoidCallback onTap;
  final IconData icon;
  final String t;
  final String s;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: (MediaQuery.of(context).size.width - 52) / 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFBFAF6), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFECE4D2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 30, width: 30, decoration: BoxDecoration(color: AbzioTheme.accentColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 17)),
              const SizedBox(height: 7),
              Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ]),
          ),
        ),
      );
}

class _OChip extends StatelessWidget {
  const _OChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: selected ? AbzioTheme.accentColor.withValues(alpha: 0.18) : const Color(0xFFF6F3EA), borderRadius: BorderRadius.circular(10)),
            child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.money, required this.onSet});
  final OrderModel order;
  final String Function(double) money;
  final Future<void> Function(OrderModel order, String status) onSet;
  @override
  Widget build(BuildContext context) => _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))), Chip(label: Text(order.status), backgroundColor: const Color(0xFFF4E8C5), side: BorderSide.none)]),
          Text('Customer: ${order.shippingLabel.isEmpty ? order.userId : order.shippingLabel}'),
          Text('${order.items.length} item(s)', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 6),
          Text(money(order.totalAmount), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('Payment: ${order.paymentMethod}', style: const TextStyle(color: Colors.black87)),
          Text('Commission: ${money(order.platformCommission)}', style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600)),
          Text('You earn: ${money(order.vendorEarnings)}', style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: order.status == 'Placed' ? () => onSet(order, 'Confirmed') : null, child: const Text('Accept'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: order.status == 'Confirmed' ? () => onSet(order, 'Packed') : null, child: const Text('Mark Packed'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.tonal(onPressed: order.status == 'Packed' ? () => onSet(order, 'Ready for pickup') : null, child: const Text('Ready'))),
          ]),
        ]),
      );
}

class _CustomOrderCard extends StatelessWidget {
  const _CustomOrderCard({required this.order, required this.money, required this.onSet});
  final OrderModel order;
  final String Function(double) money;
  final Future<void> Function(OrderModel order, String status) onSet;

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
                  label: Text(order.customOrderStatus.replaceAll('_', ' ')),
                  backgroundColor: const Color(0xFFF4E8C5),
                  side: BorderSide.none,
                ),
              ],
            ),
            Text('Customer: ${order.shippingLabel.isEmpty ? order.userId : order.shippingLabel}'),
            Text(
              'Category: ${order.items.isEmpty ? 'Custom' : order.items.first.productName}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.straighten_rounded, size: 16, color: Color(0xFF8F6A1D)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _measurementSummary(order),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Delivery: ${_deliveryLabel(order)}',
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(money(order.totalAmount), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: order.customOrderStatus == 'new_order'
                        ? () => onSet(order, 'accepted')
                        : null,
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: const Color(0xFFF9F7F2),
                        builder: (context) => FractionallySizedBox(
                          heightFactor: 0.92,
                          child: _CustomOrderDetailSheet(
                            order: order,
                            money: money,
                            onSet: (status) => onSet(order, status),
                          ),
                        ),
                      );
                    },
                    child: const Text('View details'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  String _measurementSummary(OrderModel order) {
    if (order.customMeasurements.isEmpty) {
      return 'Measurements pending';
    }
    final chest = order.customMeasurements['chest'];
    final waist = order.customMeasurements['waist'];
    final shoulder = order.customMeasurements['shoulder'];
    final pieces = <String>[
      if (chest != null) 'Chest ${chest.toString()}',
      if (waist != null) 'Waist ${waist.toString()}',
      if (shoulder != null) 'Shoulder ${shoulder.toString()}',
    ];
    return pieces.isEmpty ? 'Measurements captured' : pieces.join(' • ');
  }

  String _deliveryLabel(OrderModel order) {
    final created = DateTime.tryParse(order.createdAt ?? '') ?? order.timestamp;
    final days = order.customProductionTimeDays > 0 ? order.customProductionTimeDays : 7;
    final target = created.add(Duration(days: days));
    return DateFormat('d MMM').format(target);
  }
}

class _CustomProductionRow extends StatelessWidget {
  const _CustomProductionRow({required this.order, required this.onTap});

  final OrderModel order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFAF7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAE6DB)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AbzioTheme.accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.design_services_rounded, color: AbzioTheme.accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.shippingLabel.isEmpty ? order.userId : order.shippingLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.customOrderStatus.replaceAll('_', ' '),
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _CustomOrderDetailSheet extends StatelessWidget {
  const _CustomOrderDetailSheet({
    required this.order,
    required this.money,
    required this.onSet,
  });

  final OrderModel order;
  final String Function(double) money;
  final Future<void> Function(String status) onSet;

  @override
  Widget build(BuildContext context) {
    final measurementEntries = order.customMeasurements.entries.toList();
    final designEntries = order.customDesignOptions.entries.toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Custom Order Details',
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.shippingLabel.isEmpty ? order.userId : order.shippingLabel,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(order.items.isEmpty ? 'Custom outfit' : order.items.first.productName),
                        const SizedBox(height: 6),
                        Text('Earnings per order: ${money(order.vendorEarnings)}', style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w700)),
                        Text('Delivery date: ${DateFormat('d MMM y').format((DateTime.tryParse(order.createdAt ?? '') ?? order.timestamp).add(Duration(days: order.customProductionTimeDays > 0 ? order.customProductionTimeDays : 7)))}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Full measurements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        if (measurementEntries.isEmpty)
                          const Text('No measurements attached.')
                        else
                          ...measurementEntries.map((entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(entry.key, style: const TextStyle(color: Colors.black54))),
                                    Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Design selections', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        if (designEntries.isEmpty)
                          const Text('No design selections attached.')
                        else
                          ...designEntries.map((entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(entry.key, style: const TextStyle(color: Colors.black54))),
                                    Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reference image', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: const Color(0xFFF5F0E2),
                            border: Border.all(color: const Color(0xFFE5D7B2)),
                          ),
                          child: Center(
                            child: order.referenceImageUrl.isEmpty
                                ? const Text('No reference image')
                                : const Icon(Icons.image_rounded, size: 40, color: Color(0xFF9C7A2C)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Production tracking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            _StatusChip(label: 'New'),
                            _StatusChip(label: 'Accepted'),
                            _StatusChip(label: 'Stitching'),
                            _StatusChip(label: 'Quality Check'),
                            _StatusChip(label: 'Ready'),
                            _StatusChip(label: 'Shipped'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(onPressed: order.customOrderStatus == 'new_order' ? () => onSet('accepted') : null, child: const Text('Accept')),
                OutlinedButton(onPressed: order.customOrderStatus == 'new_order' ? () => onSet('rejected') : null, child: const Text('Reject')),
                FilledButton(onPressed: order.customOrderStatus == 'accepted' ? () => onSet('in_stitching') : null, child: const Text('Start stitching')),
                FilledButton.tonal(onPressed: order.customOrderStatus == 'in_stitching' ? () => onSet('quality_check') : null, child: const Text('Mark QC done')),
                FilledButton.tonal(onPressed: order.customOrderStatus == 'quality_check' ? () => onSet('ready') : null, child: const Text('Ready for dispatch')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4E8C5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.e, required this.money});
  final WalletTransaction e;
  final String Function(double) money;
  @override
  Widget build(BuildContext context) {
    final debit = e.type == 'commission' || e.type == 'refund' || e.type == 'payout' || e.type == 'withdrawal';
    final color = debit ? const Color(0xFFB91C1C) : const Color(0xFF15803D);
    final isWithdrawal = e.type == 'withdrawal' || e.type == 'payout';
    final icon = isWithdrawal
        ? Icons.account_balance_wallet_outlined
        : e.type == 'commission'
            ? Icons.percent_rounded
            : e.type == 'order'
                ? Icons.verified_rounded
                : Icons.receipt_long_outlined;
    final typeLabel = isWithdrawal
        ? 'Withdrawal'
        : e.type == 'commission'
            ? 'Commission'
            : e.type == 'order'
                ? 'Escrow'
                : '${e.type[0].toUpperCase()}${e.type.substring(1)}';
    final date = DateTime.tryParse(e.createdAt);
    final dateText = date == null ? e.createdAt : DateFormat('d MMM, hh:mm a').format(date);
    final statusText = e.status.isEmpty ? 'Completed' : e.status[0].toUpperCase() + e.status.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEDE7D9))),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(typeLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Text(statusText, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              ),
              Text(dateText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ),
        Text('${debit ? '-' : '+'}${money(e.amount)}', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(12),
        children: List.generate(6, (i) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Container(height: i == 1 ? 180 : 90, decoration: BoxDecoration(color: const Color(0xFFEFECE4), borderRadius: BorderRadius.circular(16))))),
      );
}
