import 'package:flutter/material.dart';

import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_metric_card.dart';

import '../../services/promotion_analytics_api.dart';

class PromotionAnalyticsScreen extends StatefulWidget {
  const PromotionAnalyticsScreen({super.key});

  @override
  State<PromotionAnalyticsScreen> createState() =>
      _PromotionAnalyticsScreenState();
}

class _PromotionAnalyticsScreenState extends State<PromotionAnalyticsScreen> {
  final PromotionAnalyticsApi _api = PromotionAnalyticsApi();

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _api.getPromotionAnalytics();
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VendorTheme.background,
      appBar: AppBar(
        title: Text(
          'Promotion Analytics',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: VendorTheme.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Failed to load analytics: $_error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VendorTheme.spacing16),
            ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: VendorTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(VendorTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodSelector(context),
            const SizedBox(height: VendorTheme.spacing24),
            _buildMetricsGrid(context),
            const SizedBox(height: VendorTheme.spacing24),
            Text(
              'Top Store Coupons',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: VendorTheme.spacing16),
            _buildTopCoupons(context),
            const SizedBox(height: VendorTheme.spacing32),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Overview',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: VendorTheme.spacing12,
            vertical: VendorTheme.spacing4,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
            border: Border.all(color: VendorTheme.grey300),
          ),
          child: Row(
            children: [
              Text(
                'Last 30 Days',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: VendorTheme.spacing4),
              const Icon(Icons.arrow_drop_down, color: VendorTheme.grey600),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    final overview = _data['overview'] ?? {};
    final promoRevenue = overview['promoRevenue'] ?? 0.0;
    final couponUsage = overview['couponUsage'] ?? 0;
    final conversionLift = overview['conversionLift'] ?? 4.2;
    final roi = overview['roi'] ?? 3.5;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: VendorMetricCard(
                title: 'Promo Revenue',
                value: '\u20B9${promoRevenue.toStringAsFixed(0)}',
                icon: Icons.payments_outlined,
                trend: 15.2,
              ),
            ),
            const SizedBox(width: VendorTheme.spacing16),
            Expanded(
              child: VendorMetricCard(
                title: 'Coupon Usage',
                value: couponUsage.toString(),
                icon: Icons.local_activity_outlined,
                trend: 5.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: VendorTheme.spacing16),
        Row(
          children: [
            Expanded(
              child: VendorMetricCard(
                title: 'Conversion Lift',
                value: '+${conversionLift.toStringAsFixed(1)}%',
                icon: Icons.trending_up_outlined,
                trend: 1.1,
              ),
            ),
            const SizedBox(width: VendorTheme.spacing16),
            Expanded(
              child: VendorMetricCard(
                title: 'ROI',
                value: '${roi.toStringAsFixed(1)}x',
                icon: Icons.analytics_outlined,
                trend: -0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopCoupons(BuildContext context) {
    final topCoupons = _data['topCoupons'];
    if (topCoupons == null || topCoupons.isEmpty) {
      return const PremiumVendorCard(
        padding: EdgeInsets.all(VendorTheme.spacing24),
        child: Center(child: Text('No coupon analytics available')),
      );
    }

    return PremiumVendorCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: topCoupons.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final coupon = topCoupons[index];
          final code = coupon['_id'] ?? 'UNKNOWN';
          final uses = coupon['redemptions'] ?? 0;
          final rev = coupon['revenue'] ?? 0.0;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: VendorTheme.spacing16,
              vertical: VendorTheme.spacing8,
            ),
            leading: CircleAvatar(
              backgroundColor: VendorTheme.primary.withValues(alpha: 0.1),
              child: const Icon(
                Icons.local_offer_outlined,
                color: VendorTheme.primary,
                size: 20,
              ),
            ),
            title: Text(
              code,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '$uses uses',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\u20B9${rev.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: VendorTheme.success,
                  ),
                ),
                Text(
                  'Revenue',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
