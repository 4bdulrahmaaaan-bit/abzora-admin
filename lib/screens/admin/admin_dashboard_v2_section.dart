import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/models.dart';
import '../../../theme.dart';
import '../../../widgets/state_views.dart';
import '../../../services/app_config.dart';
import 'widgets/admin_stat_card.dart';

class AdminDashboardV2Section extends StatelessWidget {
  const AdminDashboardV2Section({
    super.key,
    this.analytics,
    required this.orders,
    required this.users,
    required this.stores,
    required this.revenueToday,
    required this.pendingKycCount,
    required this.activeRiderCount,
    required this.onSearchGlobal,
    this.onNavigate,
  });

  final AdminAnalytics? analytics;
  final List<OrderModel> orders;
  final List<AppUser> users;
  final List<Store> stores;
  final double revenueToday;
  final int pendingKycCount;
  final int activeRiderCount;
  final void Function(String query) onSearchGlobal;
  final void Function(String section)? onNavigate;

  String _formatCurrency(double amount) =>
      '₹${amount.toStringAsFixed(2).replaceAll(RegExp(r'([.]*0)(?!.*\d)'), '')}';

  @override
  Widget build(BuildContext context) {
    final liveOrdersCount = orders
        .where((o) => o.status != 'delivered' && o.status != 'cancelled')
        .length;
    final activeTrialsCount = analytics?.trialsRequiringAttention ?? 0;
    final activeVendorsCount = stores.where((s) => s.isActive).length;
    final gmvToday = analytics?.totalRevenue ?? 0;
    final pendingRefundsCount = analytics?.pendingRefunds ?? 0;
    final fraudAlertsCount = analytics?.fraudAlerts ?? 0;

    final recentOrders = orders.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enterprise Dashboard',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: 28,
            color: AbzioTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Platform performance, operational alerts, and executive summary.',
          style: GoogleFonts.inter(
            color: AbzioTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        if (analytics != null) ...[
          _ExecutiveOperationsWidget(
            analytics: analytics!,
            onNavigate: onNavigate,
          ),
          const SizedBox(height: 32),
        ],
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          children: [
            AdminStatCard(
              title: 'Live Orders',
              value: '$liveOrdersCount',
              icon: Icons.shopping_bag_outlined,
            ),
            AdminStatCard(
              title: 'Active Trials',
              value: '$activeTrialsCount',
              icon: Icons.dry_cleaning_outlined,
            ),
            if (AppConfig.enableLocalRiderDelivery)
              AdminStatCard(
                title: 'Online Riders',
                value: '$activeRiderCount',
                icon: Icons.delivery_dining_outlined,
              ),
            AdminStatCard(
              title: 'Active Vendors',
              value: '$activeVendorsCount',
              icon: Icons.storefront_outlined,
            ),
            AdminStatCard(
              title: 'Revenue Today',
              value: _formatCurrency(revenueToday),
              icon: Icons.account_balance_wallet_outlined,
            ),
            AdminStatCard(
              title: 'GMV Today',
              value: _formatCurrency(gmvToday),
              icon: Icons.show_chart_rounded,
            ),
            AdminStatCard(
              title: 'Pending Refunds',
              value: '$pendingRefundsCount',
              icon: Icons.currency_exchange_outlined,
            ),
            AdminStatCard(
              title: 'Fraud Alerts',
              value: '$fraudAlertsCount',
              icon: Icons.warning_amber_rounded,
              trendUp: false,
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AbzioTheme.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Orders',
                        style: context.abzioText.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      if (recentOrders.isEmpty)
                        const AbzioEmptyCard(
                          title: 'No active order updates',
                          subtitle: 'Platform running smoothly.',
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: recentOrders.length > 5
                              ? 5
                              : recentOrders.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final order = recentOrders[index];
                            final invoice = order.invoiceNumber.isEmpty
                                ? order.id
                                : order.invoiceNumber;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('Order #$invoice'),
                              subtitle: Text(
                                'Status: ${order.status.toUpperCase()}',
                                style: TextStyle(
                                  color: order.status == 'delivered'
                                      ? Colors.green
                                      : AbzioTheme.accentColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: Text(
                                _formatCurrency(order.totalAmount),
                                style: context.abzioText.titleMedium,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AbzioTheme.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions',
                        style: context.abzioText.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _QuickActionTile(
                        title: 'Approve Vendor',
                        icon: Icons.storefront_rounded,
                        onTap: () {},
                      ),
                      if (AppConfig.enableLocalRiderDelivery)
                        _QuickActionTile(
                          title: 'Approve Rider',
                          icon: Icons.motorcycle_rounded,
                          onTap: () {},
                        ),
                      _QuickActionTile(
                        title: 'Broadcast Notification',
                        icon: Icons.campaign_rounded,
                        onTap: () {},
                      ),
                      _QuickActionTile(
                        title: 'Create Coupon',
                        icon: Icons.local_offer_rounded,
                        onTap: () {},
                      ),
                      _QuickActionTile(
                        title: 'Review Fraud Alerts',
                        icon: Icons.security_rounded,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AbzioTheme.accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AbzioTheme.accentColor),
      ),
      title: Text(
        title,
        style: context.abzioText.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
    );
  }
}

class _ExecutiveOperationsWidget extends StatelessWidget {
  const _ExecutiveOperationsWidget({required this.analytics, this.onNavigate});

  final AdminAnalytics analytics;
  final void Function(String section)? onNavigate;

  Color _getScoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.blue;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getScoreLabel(int score) {
    if (score >= 90) return 'EXCELLENT';
    if (score >= 75) return 'GOOD';
    if (score >= 60) return 'WARNING';
    return 'CRITICAL';
  }

  @override
  Widget build(BuildContext context) {
    final score = analytics.systemReadinessScore;
    final scoreColor = _getScoreColor(score);

    return Card(
      color: AbzioTheme.primaryColor.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AbzioTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.assignment_late_outlined,
                      color: AbzioTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Executive Command Center',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AbzioTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scoreColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Readiness: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '$score',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: scoreColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scoreColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getScoreLabel(score),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildActionItem(
                  context,
                  title: 'Orders Attention',
                  count: analytics.ordersRequiringAttention,
                  icon: Icons.local_shipping_outlined,
                  onTap: () => onNavigate?.call('orders'),
                ),
                _buildActionItem(
                  context,
                  title: 'Trials Attention',
                  count: analytics.trialsRequiringAttention,
                  icon: Icons.checkroom_outlined,
                  onTap: () => onNavigate?.call('trials'),
                ),
                _buildActionItem(
                  context,
                  title: 'Vendors Attention',
                  count: analytics.vendorsRequiringAttention,
                  icon: Icons.storefront_outlined,
                  onTap: () => onNavigate?.call('vendors'),
                ),
                _buildActionItem(
                  context,
                  title: 'Fraud Alerts',
                  count: analytics.fraudAlerts,
                  icon: Icons.security_outlined,
                  onTap: () => onNavigate?.call('fraud'),
                ),
                _buildActionItem(
                  context,
                  title: 'Pending Refunds',
                  count: analytics.pendingRefunds,
                  icon: Icons.currency_exchange_outlined,
                  onTap: () => onNavigate?.call('finance'),
                ),
                _buildActionItem(
                  context,
                  title: 'Pending KYC',
                  count: analytics.pendingKyc,
                  icon: Icons.badge_outlined,
                  onTap: () => onNavigate?.call('kyc'),
                ),
                _buildActionItem(
                  context,
                  title: 'Vendor Payouts',
                  count: analytics.pendingVendorSettlements,
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () => onNavigate?.call('finance'),
                ),
                if (AppConfig.enableLocalRiderDelivery)
                  _buildActionItem(
                    context,
                    title: 'Rider Payouts',
                    count: analytics.pendingRiderSettlements,
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () => onNavigate?.call('finance'),
                  ),
                _buildActionItem(
                  context,
                  title: 'Low Stock',
                  count: analytics.lowStockAlertsCount,
                  icon: Icons.inventory_2_outlined,
                  onTap: () => onNavigate?.call('inventory'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    Color severityColor = Colors.green;
    if (count > 0 && count <= 5) severityColor = Colors.orange;
    if (count > 5) severityColor = Colors.red;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: severityColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: AbzioTheme.textSecondary, size: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: severityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: context.abzioText.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AbzioTheme.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
