import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_metric_card.dart';
import '../../core/vendor/widgets/vendor_empty_state.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../models/models.dart';

class FinanceEarningsAnalyticsTab extends StatefulWidget {
  final String? storeId;
  const FinanceEarningsAnalyticsTab({super.key, this.storeId});

  @override
  State<FinanceEarningsAnalyticsTab> createState() => _FinanceEarningsAnalyticsTabState();
}

class _FinanceEarningsAnalyticsTabState extends State<FinanceEarningsAnalyticsTab> {
  VendorAnalytics? _analytics;
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
      final storeId = widget.storeId ?? actor.storeId;
      if (storeId != null) {
        final analytics = await DatabaseService().getVendorAnalytics(storeId, actor: actor);
        if (mounted) {
          setState(() {
            _analytics = analytics;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _money(double value) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
          .format(value);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: VendorTheme.primary));
    }

    if (_analytics == null) {
      return const VendorEmptyState(
        title: 'No Data Available',
        subtitle: 'Start selling to see your earnings analytics here.',
        icon: Icons.analytics_outlined,
      );
    }

    final double avgOrderValue = _analytics!.orders > 0 ? _analytics!.totalSales / _analytics!.orders : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue Breakdown',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: VendorTheme.spacing16),
          Row(
            children: [
              Expanded(
                child: VendorMetricCard(
                  title: 'Daily Revenue',
                  value: _money(_analytics!.todayRevenue),
                  icon: Icons.today,
                ),
              ),
              const SizedBox(width: VendorTheme.spacing12),
              Expanded(
                child: VendorMetricCard(
                  title: 'Weekly Revenue',
                  value: _money(_analytics!.weeklyRevenue),
                  icon: Icons.view_week,
                ),
              ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing12),
          Row(
            children: [
              Expanded(
                child: VendorMetricCard(
                  title: 'Monthly Revenue',
                  value: _money(_analytics!.totalSales), // Approx proxy
                  icon: Icons.calendar_month,
                ),
              ),
              const SizedBox(width: VendorTheme.spacing12),
              Expanded(
                child: VendorMetricCard(
                  title: 'Avg Order Value',
                  value: _money(avgOrderValue),
                  icon: Icons.shopping_bag,
                ),
              ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing32),
          Text(
            'Sales Trend',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: VendorTheme.spacing16),
          if (_analytics!.salesTrend.isEmpty)
            const PremiumVendorCard(
              padding: EdgeInsets.all(VendorTheme.spacing24),
              child: Center(
                child: Text('Not enough data to show trend.', style: TextStyle(color: VendorTheme.grey400)),
              ),
            )
          else
            PremiumVendorCard(
              padding: EdgeInsets.zero,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _analytics!.salesTrend.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final point = _analytics!.salesTrend[index];
                  // Using a simple visual bar relative to the max value
                  final maxVal = _analytics!.salesTrend.map((e) => e.value).reduce((a, b) => a > b ? a : b);
                  final ratio = maxVal > 0 ? point.value / maxVal : 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: VendorTheme.spacing16, vertical: VendorTheme.spacing12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(point.label, style: Theme.of(context).textTheme.titleSmall),
                            Text(
                              _money(point.value),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: VendorTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 6,
                            backgroundColor: VendorTheme.primary.withValues(alpha: 0.1),
                            valueColor: const AlwaysStoppedAnimation(VendorTheme.primary),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
