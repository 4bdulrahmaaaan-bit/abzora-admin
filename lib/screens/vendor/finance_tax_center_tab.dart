import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_buttons.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../models/models.dart';

class FinanceTaxCenterTab extends StatefulWidget {
  final String? storeId;
  const FinanceTaxCenterTab({super.key, this.storeId});

  @override
  State<FinanceTaxCenterTab> createState() => _FinanceTaxCenterTabState();
}

class _FinanceTaxCenterTabState extends State<FinanceTaxCenterTab> {
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

    final totalSales = _analytics?.totalSales ?? 0.0;
    // GST extrapolation (informational only) - assuming a 5% blended rate for apparel/general
    final estimatedGst = totalSales * 0.05;
    final netSales = totalSales - estimatedGst;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumVendorCard(
            backgroundColor: VendorTheme.primary.withValues(alpha: 0.05),
            padding: const EdgeInsets.all(VendorTheme.spacing16),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: VendorTheme.primary),
                const SizedBox(width: VendorTheme.spacing12),
                Expanded(
                  child: Text(
                    'Estimated – For informational purposes only. These figures do not constitute legal tax advice.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: VendorTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: VendorTheme.spacing24),
          Text(
            'Tax Overview (All Time)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: VendorTheme.spacing16),
          Row(
            children: [
              Expanded(
                child: PremiumVendorCard(
                  padding: const EdgeInsets.all(VendorTheme.spacing16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Sales',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VendorTheme.grey400),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _money(totalSales),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: VendorTheme.spacing12),
              Expanded(
                child: PremiumVendorCard(
                  padding: const EdgeInsets.all(VendorTheme.spacing16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated GST',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VendorTheme.grey400),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _money(estimatedGst),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: VendorTheme.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing12),
          PremiumVendorCard(
            padding: const EdgeInsets.all(VendorTheme.spacing16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estimated Net Revenue',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  _money(netSales),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: VendorTheme.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: VendorTheme.spacing32),
          Text(
            'Reports & Documents',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: VendorTheme.spacing16),
          PremiumVendorCard(
            padding: const EdgeInsets.all(VendorTheme.spacing16),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: VendorTheme.background,
                    child: Icon(Icons.picture_as_pdf, color: VendorTheme.primary),
                  ),
                  title: const Text('Monthly GST Invoice'),
                  subtitle: const Text('Consolidated platform fees and taxes'),
                  trailing: VendorPrimaryButton(
                    label: 'Download',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('GST reporting module coming soon.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
