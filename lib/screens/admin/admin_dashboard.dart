import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../models/models.dart';
import 'admin_management_screen.dart';
import 'admin_web_panel.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/state_views.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _db = DatabaseService();
  final _searchController = TextEditingController();
  AdminAnalytics? _analytics;
  PlatformSettings _settings = const PlatformSettings();
  List<DisputeRecord> _disputes = [];
  List<ActivityLogEntry> _logs = [];
  GlobalSearchResults _searchResults = const GlobalSearchResults();
  bool _loading = true;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) {
      return;
    }
    final analytics = await _db.getAdminAnalytics();
    final settings = await _safePlatformSettings(actor);
    final disputes = await _safeDisputes(actor);
    final logs = await _safeActivityLogs(actor);
    if (!mounted) return;
    setState(() {
      _analytics = analytics;
      _settings = settings;
      _disputes = disputes;
      _logs = logs.take(12).toList();
      _loading = false;
    });
    _resetIdleTimer();
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
              : 'Processed payout of Rs ${payout.amount.toInt()} for ${store.name}.',
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
                          subtitle: Text('${dispute.reason}\nRs ${dispute.amount.toInt()} • ${dispute.status}'),
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
                      _AdminMetric(label: 'Orders', value: '${_analytics?.totalOrders ?? 0}', icon: Icons.shopping_cart_outlined, color: Colors.green),
                      _AdminMetric(label: 'Revenue', value: 'Rs ${_analytics?.totalRevenue.toInt() ?? 0}', icon: Icons.payments_outlined, color: AbzioTheme.accentColor),
                      _AdminMetric(label: 'Commission', value: 'Rs ${_analytics?.platformCommissionRevenue.toInt() ?? 0}', icon: Icons.account_balance_outlined, color: Colors.blue),
                      _AdminMetric(label: 'Top Store', value: _analytics?.topStores.isNotEmpty == true ? _analytics!.topStores.first.name : 'None', icon: Icons.store_outlined, color: Colors.orange),
                    ],
                  ),
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
                    title: 'Migrate to Firebase',
                    subtitle: 'Push all local demo mock data into the connected Firestore project',
                    icon: Icons.cloud_upload_outlined,
                    color: Colors.red,
                    onTap: () async {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text('Starting migration via batch write...'),
                          ),
                        );
                      }
                      try {
                        await _db.migrateDemoDataToFirestore(actor: auth.user!);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text('Migration complete. Pull to refresh.'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text('Migration failed: $e'),
                            ),
                          );
                        }
                      }
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
                          subtitle: Text('Wallet balance Rs ${store.walletBalance.toInt()} | Commission ${(store.commissionRate * 100).toInt()}%'),
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
