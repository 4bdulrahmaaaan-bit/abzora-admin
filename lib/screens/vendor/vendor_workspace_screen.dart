import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';
import 'add_product_screen.dart';
import 'order_management.dart';
import 'product_management.dart';
import 'store_settings_screen.dart';

class VendorWorkspaceScreen extends StatefulWidget {
  const VendorWorkspaceScreen({super.key});

  @override
  State<VendorWorkspaceScreen> createState() => _VendorWorkspaceScreenState();
}

class _VendorWorkspaceScreenState extends State<VendorWorkspaceScreen> {
  final DatabaseService _db = DatabaseService();
  final NumberFormat _money = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0);

  int _index = 0;
  bool _loading = true;
  String _orderTab = 'new';
  String _txFilter = 'all';
  String? _error;
  bool _acceptingOrders = true;

  Store? _store;
  List<OrderModel> _orders = const [];
  VendorAnalytics? _analytics;
  WalletSummary? _wallet;

  AppUser? get _actor => context.read<AuthProvider>().user;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final actor = _actor;
    if (actor == null || actor.role != 'vendor') {
      setState(() {
        _loading = false;
        _error = 'Vendor account required.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final store = await _db.getStoreByOwner(actor.id);
      if (store == null) throw Exception('Store not found.');
      final data = await Future.wait<dynamic>([
        _db.getVendorOrders(store.id, actor: actor).first,
        _db.getVendorAnalytics(store.id, actor: actor),
        _db.getVendorWallet(actor: actor),
      ]);
      if (!mounted) return;
      setState(() {
        _store = store;
        _orders = data[0] as List<OrderModel>;
        _analytics = data[1] as VendorAnalytics;
        _wallet = data[2] as WalletSummary;
        _acceptingOrders = store.isActive;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      appBar: AppBar(
        title: Text('ABZORA PARTNER', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const _Skeleton()
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: AbzioEmptyCard(title: 'Unable to load', subtitle: _error!, ctaLabel: 'Retry', onTap: _load)))
              : RefreshIndicator(onRefresh: _load, child: IndexedStack(index: _index, children: [_home(), _ordersTab(), _earnings(), _account()])),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Earnings'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Account'),
        ],
      ),
    );
  }

  Widget _home() {
    final a = _analytics!;
    final w = _wallet!;
    return ListView(padding: const EdgeInsets.all(12), children: [
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Welcome back, ${_store!.name}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [const Icon(Icons.storefront_rounded, color: AbzioTheme.accentColor), const SizedBox(width: 8), const Expanded(child: Text('Accepting Orders')), Switch(value: _acceptingOrders, onChanged: (v) => setState(() => _acceptingOrders = v))]),
      ])),
      const SizedBox(height: 10),
      _MetricGrid(items: [('Revenue Today', 'Gross sales', m(a.todayRevenue), const Color(0xFF374151)), ('Earnings Today', 'After commission', m(a.todayEarnings), const Color(0xFF15803D)), ('Pending Orders', 'Need action', '${_orders.where((o) => o.status == 'Placed').length}', const Color(0xFFC2410C)), ('Completed Orders', 'Delivered', '${_orders.where((o) => o.status == 'Delivered' || o.status == 'Completed').length}', const Color(0xFF374151))]),
      const SizedBox(height: 10),
      _MetricGrid3(items: [('Commission Today', m(a.todayCommission), const Color(0xFFB91C1C)), ('Pending Settlement', m(w.pendingAmount), const Color(0xFFC2410C)), ('Available Balance', m(w.balance), const Color(0xFF15803D))]),
      const SizedBox(height: 10),
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Quick actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Action(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddProductScreen(storeId: _store!.id))), icon: Icons.add_box_rounded, t: 'Add Product', s: 'Publish new item'),
          _Action(onTap: () => setState(() => _index = 1), icon: Icons.list_alt_rounded, t: 'View Orders', s: 'Process quickly'),
          _Action(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreSettingsScreen(store: _store!))), icon: Icons.store_rounded, t: 'Manage Store', s: 'Branding/settings'),
          _Action(onTap: () => setState(() => _index = 2), icon: Icons.payments_rounded, t: 'View Earnings', s: 'Wallet/payouts'),
        ]),
      ])),
    ]);
  }

  Widget _ordersTab() {
    final filtered = _orders.where((o) {
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
      ...filtered.map((o) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _OrderCard(order: o, money: m, onSet: _setStatus))),
      const SizedBox(height: 6),
      if (_orderTab != 'completed') FilledButton.tonal(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderManagementScreen(actor: _actor!, store: _store!))), child: const Text('Open full queue')),
    ]);
  }

  Widget _earnings() {
    final a = _analytics!;
    final w = _wallet!;
    final tx = _txFilter == 'all' ? a.transactions : a.transactions.where((e) => e.type == _txFilter).toList();
    return ListView(padding: const EdgeInsets.all(12), children: [
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Earnings summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _line('Available Balance', m(w.balance)),
        _line('Pending Settlement', m(w.pendingAmount)),
        _line('Total Earnings', m(a.totalEarnings)),
        _line('Today Earnings', m(a.todayEarnings)),
        _line('Weekly Earnings', m(a.weeklyRevenue)),
        _line('Total Commission Paid', m(a.weeklyCommission + a.todayCommission)),
      ])),
      const SizedBox(height: 10),
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Withdraw Earnings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _line('Available', m(w.balance)),
        _line('Minimum withdrawal', 'Rs 100'),
        _line('Next payout date', DateFormat('EEE, d MMM').format(DateTime.now().add(const Duration(days: 1)))),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: _withdraw, child: const Text('Withdraw'))),
      ])),
      const SizedBox(height: 10),
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Spacer(),
          DropdownButton<String>(value: _txFilter, underline: const SizedBox.shrink(), onChanged: (v) => setState(() => _txFilter = v ?? 'all'), items: const [DropdownMenuItem(value: 'all', child: Text('All')), DropdownMenuItem(value: 'order', child: Text('Order')), DropdownMenuItem(value: 'commission', child: Text('Commission')), DropdownMenuItem(value: 'refund', child: Text('Refund')), DropdownMenuItem(value: 'payout', child: Text('Payout'))]),
        ]),
        const SizedBox(height: 8),
        if (tx.isEmpty) const AbzioEmptyCard(title: 'No transactions', subtitle: 'Transactions will show after activity.'),
        ...tx.take(12).map((e) => _TxRow(e: e, money: m)),
      ])),
    ]);
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
      ])),
      const SizedBox(height: 10),
      _Card(child: Column(children: [
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.inventory_2_outlined), title: const Text('Product Management'), subtitle: const Text('Catalogue and stock'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductManagementScreen(storeId: store.id)))),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.settings_outlined), title: const Text('Store Controls'), subtitle: const Text('Branding and operations'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreSettingsScreen(store: store)))),
      ])),
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

class _TxRow extends StatelessWidget {
  const _TxRow({required this.e, required this.money});
  final WalletTransaction e;
  final String Function(double) money;
  @override
  Widget build(BuildContext context) {
    final debit = e.type == 'commission' || e.type == 'refund' || e.type == 'payout' || e.type == 'withdrawal';
    final color = debit ? const Color(0xFFB91C1C) : const Color(0xFF15803D);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(debit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e.type.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700)), Text(e.createdAt, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54))])),
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
