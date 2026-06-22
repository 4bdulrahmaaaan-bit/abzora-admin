import 'package:flutter/material.dart';
import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_metric_card.dart';
import '../../core/vendor/widgets/vendor_status_badge.dart';
import '../../core/vendor/widgets/vendor_buttons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../models/models.dart';
import 'finance_settlements_tab.dart';
import 'finance_payouts_tab.dart';
import 'finance_tax_center_tab.dart';
import 'finance_earnings_analytics_tab.dart';
import '../../widgets/lazy_indexed_tab_view.dart';

class VendorFinanceHubScreen extends StatelessWidget {
  const VendorFinanceHubScreen({super.key, this.storeId});

  final String? storeId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: VendorTheme.background,
        appBar: AppBar(
          title: const Text('Finance Hub'),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: VendorTheme.primary,
            unselectedLabelColor: VendorTheme.grey400,
            indicatorColor: VendorTheme.primary,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Settlements'),
              Tab(text: 'Payouts'),
              Tab(text: 'Tax Center'),
              Tab(text: 'Earnings Analytics'),
            ],
          ),
        ),
        body: LazyIndexedTabView(
          length: 5,
          itemBuilder: (context, index) {
            switch (index) {
              case 0:
                return _FinanceOverviewTab(storeId: storeId);
              case 1:
                return FinanceSettlementsTab(storeId: storeId);
              case 2:
                return FinancePayoutsTab(storeId: storeId);
              case 3:
                return FinanceTaxCenterTab(storeId: storeId);
              case 4:
                return FinanceEarningsAnalyticsTab(storeId: storeId);
              default:
                return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }
}

class _FinanceOverviewTab extends StatefulWidget {
  final String? storeId;
  const _FinanceOverviewTab({this.storeId});

  @override
  State<_FinanceOverviewTab> createState() => _FinanceOverviewTabState();
}

class _FinanceOverviewTabState extends State<_FinanceOverviewTab> {
  String _selectedPeriod = 'This Month';
  WalletSummary? _wallet;
  VendorAnalytics? _analytics;
  List<PayoutModel>? _payouts;
  PayoutProfileSummary? _profile;
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
      final db = DatabaseService();
      final storeId = widget.storeId ?? actor.storeId;
      final futures = await Future.wait([
        db.getVendorWallet(actor: actor),
        if (storeId != null) db.getVendorAnalytics(storeId, actor: actor) else Future.value(null),
        db.getPayouts(actor: actor, storeId: storeId),
        db.getVendorPayoutProfile(actor: actor),
      ]);
      if (mounted) {
        setState(() {
          _wallet = futures[0] as WalletSummary?;
          _analytics = futures[1] as VendorAnalytics?;
          _payouts = futures[2] as List<PayoutModel>?;
          _profile = futures[3] as PayoutProfileSummary?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _money(double value) => NumberFormat.currency(locale: 'en_IN', symbol: 'â‚¹', decimalDigits: 0).format(value);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildWalletOverview(context),
          const SizedBox(height: VendorTheme.spacing24),
          _buildMetricsGrid(),
          const SizedBox(height: VendorTheme.spacing24),
          _buildPayoutSchedule(context),
          const SizedBox(height: VendorTheme.spacing24),
          _buildRecentTransactions(context),
          const SizedBox(height: VendorTheme.spacing32),
        ],
      ),
    );
  }

  Widget _buildWalletOverview(BuildContext context) {
    return PremiumVendorCard(
      backgroundColor: VendorTheme.primary,
      padding: const EdgeInsets.all(VendorTheme.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Available Balance',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: VendorTheme.background.withValues(alpha: 0.8),
                ),
              ),
              VendorStatusBadge(
                label: 'Ready for Payout',
                type: VendorBadgeType.success,
              ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing12),
          Text(
            _money(_wallet?.balance ?? 0),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: VendorTheme.background,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: VendorTheme.spacing24),
          Row(
            children: <Widget>[
              Expanded(
                child: VendorSecondaryButton(
                  label: 'Withdraw Funds',
                  onTap: () {},
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: VendorTheme.spacing12),
              Expanded(
                child: VendorOutlinedButton(
                  label: 'View Reports',
                  onTap: () {},
                  icon: Icons.receipt_long_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Performance', style: Theme.of(context).textTheme.titleLarge),
            DropdownButton<String>(
              value: _selectedPeriod,
              underline: const SizedBox(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: VendorTheme.primary,
              ),
              icon: const Icon(
                Icons.arrow_drop_down,
                color: VendorTheme.primary,
              ),
              items: <String>[
                'Today',
                'This Week',
                'This Month',
                'This Year',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedPeriod = value);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: VendorTheme.spacing16),
        Row(
          children: <Widget>[
            Expanded(
              child: VendorMetricCard(
                title: 'Total Revenue',
                value: _money(_analytics?.totalSales ?? 0),
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: VendorTheme.spacing16),
            Expanded(
              child: VendorMetricCard(
                title: 'Pending Payout',
                value: _money(_wallet?.pendingAmount ?? 0),
                icon: Icons.schedule_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: VendorTheme.spacing16),
        Row(
          children: <Widget>[
            Expanded(
              child: VendorMetricCard(
                title: 'Total Earnings',
                value: _money(_wallet?.totalEarnings ?? 0),
                icon: Icons.shopping_bag_outlined,
              ),
            ),
            const SizedBox(width: VendorTheme.spacing16),
            Expanded(
              child: VendorMetricCard(
                title: 'Total Withdrawn',
                value: _money(_wallet?.totalWithdrawn ?? 0),
                icon: Icons.assignment_return_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPayoutSchedule(BuildContext context) {
    if (_payouts == null || _payouts!.isEmpty) return const SizedBox.shrink();
    final nextPayout = _payouts!.firstWhere((p) => p.status != 'completed', orElse: () => _payouts!.first);
    final isConfigured = _profile?.isConfigured ?? false;
    final bankInfo = isConfigured ? '${_profile!.bankName} **** ${_profile!.bankAccountNumber.substring(_profile!.bankAccountNumber.length > 4 ? _profile!.bankAccountNumber.length - 4 : 0)}' : 'No payout method';

    return PremiumVendorCard(
      padding: const EdgeInsets.all(VendorTheme.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Next Payout Schedule',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: VendorTheme.spacing16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: VendorTheme.success.withValues(alpha: 0.1),
              child: const Icon(Icons.check_circle, color: VendorTheme.success),
            ),
            title: Text(
              'Scheduled for ${DateFormat('MMM dd, yyyy').format(nextPayout.createdAt.add(const Duration(days: 3)))}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: Text(
              isConfigured ? 'Direct to $bankInfo' : 'Payout method missing',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Text(
              _money(nextPayout.amount),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: VendorTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context) {
    final txs = _wallet?.transactions ?? [];
    if (txs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Recent Transactions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(onPressed: () {}, child: const Text('View All')),
          ],
        ),
        const SizedBox(height: VendorTheme.spacing16),
        PremiumVendorCard(
          padding: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: txs.length > 5 ? 5 : txs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tx = txs[index];
              final isSettlement = tx.type == 'withdrawal';
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: VendorTheme.spacing16,
                  vertical: VendorTheme.spacing8,
                ),
                leading: CircleAvatar(
                  backgroundColor: isSettlement
                      ? VendorTheme.primary.withValues(alpha: 0.1)
                      : VendorTheme.success.withValues(alpha: 0.1),
                  child: Icon(
                    isSettlement ? Icons.account_balance : Icons.shopping_cart,
                    color: isSettlement
                        ? VendorTheme.primary
                        : VendorTheme.success,
                    size: 20,
                  ),
                ),
                title: Text(
                  isSettlement ? 'Payout to Bank' : (tx.orderId.isNotEmpty ? 'Order #${tx.orderId.substring(0, 5)}' : 'Transaction'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Text(
                  '${DateFormat('MMM dd, yyyy').format(DateTime.now())} \u2022 ${tx.status}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Text(
                  (isSettlement ? '-' : '+') + _money(tx.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSettlement
                        ? Theme.of(context).colorScheme.onSurface
                        : VendorTheme.success,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}


