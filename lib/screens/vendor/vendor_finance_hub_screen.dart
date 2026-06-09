import 'package:flutter/material.dart';
import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_metric_card.dart';
import '../../core/vendor/widgets/vendor_status_badge.dart';
import '../../core/vendor/widgets/vendor_buttons.dart';

class VendorFinanceHubScreen extends StatefulWidget {
  const VendorFinanceHubScreen({super.key, required this.storeId});

  final String storeId;

  @override
  State<VendorFinanceHubScreen> createState() => _VendorFinanceHubScreenState();
}

class _VendorFinanceHubScreenState extends State<VendorFinanceHubScreen> {
  String _selectedPeriod = 'This Month';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VendorTheme.background,
      appBar: AppBar(
        title: Text(
          'Finance Hub',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
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
            '\u20B91,24,500.00',
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
            Text(
              'Performance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            DropdownButton<String>(
              value: _selectedPeriod,
              underline: const SizedBox(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: VendorTheme.primary,
                  ),
              icon: const Icon(Icons.arrow_drop_down, color: VendorTheme.primary),
              items: <String>['Today', 'This Week', 'This Month', 'This Year']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
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
                value: '\u20B94,80,000',
                icon: Icons.payments_outlined,
                trend: 12.5,
              ),
            ),
            const SizedBox(width: VendorTheme.spacing16),
            Expanded(
              child: VendorMetricCard(
                title: 'Pending Payout',
                value: '\u20B945,000',
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
                title: 'Avg Order Value',
                value: '\u20B91,200',
                icon: Icons.shopping_bag_outlined,
                trend: 2.1,
              ),
            ),
            const SizedBox(width: VendorTheme.spacing16),
            Expanded(
              child: VendorMetricCard(
                title: 'Refunds',
                value: '\u20B912,400',
                icon: Icons.assignment_return_outlined,
                trend: -5.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPayoutSchedule(BuildContext context) {
    return PremiumVendorCard(
      padding: const EdgeInsets.all(VendorTheme.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Next Payout Schedule', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: VendorTheme.spacing16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: VendorTheme.success.withValues(alpha: 0.1),
              child: const Icon(Icons.check_circle, color: VendorTheme.success),
            ),
            title: Text('Scheduled for Oct 15, 2026', style: Theme.of(context).textTheme.titleSmall),
            subtitle: Text('Direct to HDFC Bank **** 1234', style: Theme.of(context).textTheme.bodySmall),
            trailing: Text(
              '\u20B945,000.00',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Recent Transactions', style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: () {},
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: VendorTheme.spacing16),
        PremiumVendorCard(
          padding: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final isSettlement = index == 2;
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
                    color: isSettlement ? VendorTheme.primary : VendorTheme.success,
                    size: 20,
                  ),
                ),
                title: Text(
                  isSettlement ? 'Payout to Bank' : 'Order #100${45 + index}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Text(
                  isSettlement ? 'Oct 01, 2026 \u2022 Processing' : 'Oct ${10 - index}, 2026 \u2022 Completed',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Text(
                  isSettlement ? '-\u20B950,000.00' : '+\u20B91,240.00',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSettlement ? Theme.of(context).colorScheme.onSurface : VendorTheme.success,
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
