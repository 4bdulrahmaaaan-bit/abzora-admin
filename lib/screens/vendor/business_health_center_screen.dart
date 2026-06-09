import 'package:flutter/material.dart';
import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';

import '../../core/vendor/widgets/vendor_status_badge.dart';
import '../../services/business_health_api.dart';

class BusinessHealthCenterScreen extends StatefulWidget {
  const BusinessHealthCenterScreen({super.key});

  @override
  State<BusinessHealthCenterScreen> createState() => _BusinessHealthCenterScreenState();
}

class _BusinessHealthCenterScreenState extends State<BusinessHealthCenterScreen> {
  final BusinessHealthApi _api = BusinessHealthApi();

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _healthData = {};

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
      final res = await _api.getHealth();
      setState(() {
        _healthData = res['data'] ?? {};
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
        title: Text('Business Health', style: Theme.of(context).textTheme.titleLarge),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: VendorTheme.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Failed to load business health: $_error', textAlign: TextAlign.center),
            const SizedBox(height: VendorTheme.spacing16),
            ElevatedButton(
              onPressed: _fetchData,
              child: const Text('Retry'),
            )
          ],
        ),
      );
    }

    final recommendations = (_healthData['recommendations'] as List?)?.cast<String>() ?? [];

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: VendorTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(VendorTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverallHealthScore(context),
            if (recommendations.isNotEmpty) ...[
              const SizedBox(height: VendorTheme.spacing24),
              Text('Actionable Recommendations', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: VendorTheme.spacing16),
              ...recommendations.map((rec) => PremiumVendorCard(
                    margin: const EdgeInsets.only(bottom: VendorTheme.spacing8),
                    padding: const EdgeInsets.all(VendorTheme.spacing16),
                    backgroundColor: VendorTheme.warning.withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: VendorTheme.warning),
                        const SizedBox(width: VendorTheme.spacing16),
                        Expanded(child: Text(rec, style: Theme.of(context).textTheme.bodyMedium)),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: VendorTheme.spacing24),
            Text('Health Breakdown', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: VendorTheme.spacing16),
            _buildHealthMetricCard(
              context,
              title: 'Store Profile',
              score: _healthData['storeHealth'] ?? 0,
              icon: Icons.storefront_outlined,
              description: 'Profile completion, logos, banners, and policies.',
            ),
            const SizedBox(height: VendorTheme.spacing12),
            _buildHealthMetricCard(
              context,
              title: 'Inventory Health',
              score: _healthData['inventoryHealth'] ?? 0,
              icon: Icons.inventory_2_outlined,
              description: 'Out-of-stock and low-stock product ratio.',
            ),
            const SizedBox(height: VendorTheme.spacing12),
            _buildHealthMetricCard(
              context,
              title: 'Fulfillment & Operations',
              score: _healthData['fulfillmentHealth'] ?? 0,
              icon: Icons.local_shipping_outlined,
              description: 'Order fulfillment rates and cancellation ratios.',
            ),
            const SizedBox(height: VendorTheme.spacing12),
            _buildHealthMetricCard(
              context,
              title: 'Review Health',
              score: _healthData['reviewHealth'] ?? 0,
              icon: Icons.star_outline,
              description: 'Customer ratings and volume of negative reviews.',
            ),
            const SizedBox(height: VendorTheme.spacing12),
            _buildHealthMetricCard(
              context,
              title: 'Return Health',
              score: _healthData['returnHealth'] ?? 0,
              icon: Icons.keyboard_return_outlined,
              description: 'Return and refund rate ratios.',
            ),
            const SizedBox(height: VendorTheme.spacing12),
            _buildHealthMetricCard(
              context,
              title: 'Revenue Health',
              score: _healthData['revenueHealth'] ?? 0,
              icon: Icons.payments_outlined,
              description: 'Order volume and conversion rate momentum.',
            ),
            const SizedBox(height: VendorTheme.spacing32),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallHealthScore(BuildContext context) {
    final score = _healthData['businessScore'] ?? 0;
    final statusBadge = score >= 80
        ? const VendorStatusBadge(label: 'Excellent Standing', type: VendorBadgeType.success)
        : score >= 60
            ? const VendorStatusBadge(label: 'Good Standing', type: VendorBadgeType.warning)
            : const VendorStatusBadge(label: 'Needs Attention', type: VendorBadgeType.error);

    return PremiumVendorCard(
      padding: const EdgeInsets.all(VendorTheme.spacing24),
      backgroundColor: VendorTheme.primary.withValues(alpha: 0.05),
      child: Column(
        children: [
          Text(
            'ABIANZO SELLER SCORE',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: VendorTheme.primary,
                ),
          ),
          const SizedBox(height: VendorTheme.spacing16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 10,
                  backgroundColor: VendorTheme.grey200,
                  valueColor: const AlwaysStoppedAnimation<Color>(VendorTheme.primary),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$score',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: VendorTheme.primary,
                        ),
                  ),
                  Text(
                    '/ 100',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VendorTheme.grey500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing24),
          statusBadge,
        ],
      ),
    );
  }

  Widget _buildHealthMetricCard(
    BuildContext context, {
    required String title,
    required int score,
    required IconData icon,
    required String description,
  }) {
    final color = score >= 80
        ? VendorTheme.success
        : score >= 60
            ? VendorTheme.warning
            : VendorTheme.error;

    return PremiumVendorCard(
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: VendorTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: VendorTheme.spacing4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: score / 100,
                        backgroundColor: VendorTheme.grey100,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: VendorTheme.spacing16),
              Text(
                '$score',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing12),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: VendorTheme.grey600,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}
