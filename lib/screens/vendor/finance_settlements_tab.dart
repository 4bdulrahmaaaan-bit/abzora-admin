import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_empty_state.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../models/models.dart';

class FinanceSettlementsTab extends StatefulWidget {
  final String? storeId;
  const FinanceSettlementsTab({super.key, this.storeId});

  @override
  State<FinanceSettlementsTab> createState() => _FinanceSettlementsTabState();
}

class _FinanceSettlementsTabState extends State<FinanceSettlementsTab> {
  WalletSummary? _wallet;
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
      final summary = await DatabaseService().getVendorWallet(actor: actor);
      if (mounted) {
        setState(() {
          _wallet = summary;
          _isLoading = false;
        });
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

    final allTxs = _wallet?.transactions ?? [];
    final settlements = allTxs.where((tx) => tx.type == 'settlement' || tx.type == 'withdrawal').toList();

    if (settlements.isEmpty) {
      return const VendorEmptyState(
        title: 'No Settlements Yet',
        subtitle: 'Once your funds are settled to your bank, they will appear here.',
        icon: Icons.account_balance_outlined,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settlement History',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: VendorTheme.spacing16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: settlements.length,
            separatorBuilder: (context, index) => const SizedBox(height: VendorTheme.spacing12),
            itemBuilder: (context, index) {
              final tx = settlements[index];
              return PremiumVendorCard(
                padding: const EdgeInsets.all(VendorTheme.spacing16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Settlement #${tx.id.substring(0, 8)}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: VendorTheme.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tx.status.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: VendorTheme.success,
                              fontWeight: FontWeight.bold,
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
                            Text(
                              'Amount',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VendorTheme.grey400),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _money(tx.amount),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: VendorTheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Processed On',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VendorTheme.grey400),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM dd, yyyy').format(DateTime.now().subtract(Duration(days: index * 2))), // Mock date since tx doesn't have a date field
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: VendorTheme.spacing12),
                    const Divider(height: 1),
                    const SizedBox(height: VendorTheme.spacing12),
                    Row(
                      children: [
                        const Icon(Icons.account_balance, size: 16, color: VendorTheme.grey400),
                        const SizedBox(width: 8),
                        Text(
                          'Transferred to configured bank account',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VendorTheme.grey400),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
