import 'package:flutter/material.dart';

import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_metric_card.dart';

class CustomerInsightsScreen extends StatelessWidget {
  const CustomerInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VendorTheme.background,
      appBar: AppBar(
        title: Text('Customer Insights', style: Theme.of(context).textTheme.titleLarge),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(VendorTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAudienceOverview(context),
            const SizedBox(height: VendorTheme.spacing24),
            _buildMetricsGrid(),
            const SizedBox(height: VendorTheme.spacing24),
            Text('Top Cities', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: VendorTheme.spacing16),
            _buildTopCities(context),
            const SizedBox(height: VendorTheme.spacing24),
            Text('Top Products by Volume', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: VendorTheme.spacing16),
            _buildTopProducts(context),
            const SizedBox(height: VendorTheme.spacing32),
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceOverview(BuildContext context) {
    return PremiumVendorCard(
      padding: const EdgeInsets.all(VendorTheme.spacing20),
      backgroundColor: VendorTheme.primary.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Audience Split',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Last 30 Days',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VendorTheme.grey500),
              ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing24),
          Row(
            children: [
              Expanded(
                flex: 65,
                child: Container(
                  height: 12,
                  decoration: const BoxDecoration(
                    color: VendorTheme.primary,
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(6)),
                  ),
                ),
              ),
              Expanded(
                flex: 35,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: VendorTheme.primary.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: VendorTheme.primary, shape: BoxShape.circle)),
                      const SizedBox(width: VendorTheme.spacing8),
                      Text('New Customers', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: VendorTheme.spacing4),
                  Text('65%', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: VendorTheme.primary.withValues(alpha: 0.3), shape: BoxShape.circle)),
                      const SizedBox(width: VendorTheme.spacing8),
                      Text('Returning', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: VendorTheme.spacing4),
                  Text('35%', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(
              child: VendorMetricCard(
                title: 'Repeat Rate',
                value: '22.4%',
                icon: Icons.repeat_outlined,
                trend: 2.1,
              ),
            ),
            SizedBox(width: VendorTheme.spacing16),
            Expanded(
              child: VendorMetricCard(
                title: 'Est. CLV',
                value: '\u20B94,200',
                icon: Icons.diamond_outlined,
                trend: 5.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopCities(BuildContext context) {
    return PremiumVendorCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final cities = ['Mumbai', 'Delhi', 'Bengaluru', 'Pune'];
          final percentages = [32, 24, 18, 12];
          return Padding(
            padding: const EdgeInsets.all(VendorTheme.spacing16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    cities[index],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: percentages[index] / 100,
                      backgroundColor: VendorTheme.grey100,
                      valueColor: const AlwaysStoppedAnimation<Color>(VendorTheme.primary),
                      minHeight: 8,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${percentages[index]}%',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopProducts(BuildContext context) {
    return PremiumVendorCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final products = ['Silk Embroidered Saree', 'Cotton Kurta Set', 'Linen Blend Shirt'];
          final units = ['145 units', '98 units', '64 units'];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: VendorTheme.spacing16, vertical: VendorTheme.spacing8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
              child: Container(
                width: 48,
                height: 48,
                color: VendorTheme.grey200,
                child: const Icon(Icons.image_outlined, color: VendorTheme.grey400),
              ),
            ),
            title: Text(
              products[index],
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            trailing: Text(
              units[index],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: VendorTheme.primary,
                  ),
            ),
          );
        },
      ),
    );
  }
}
