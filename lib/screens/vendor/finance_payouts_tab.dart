import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_empty_state.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../models/models.dart';

class FinancePayoutsTab extends StatefulWidget {
  final String? storeId;
  const FinancePayoutsTab({super.key, this.storeId});

  @override
  State<FinancePayoutsTab> createState() => _FinancePayoutsTabState();
}

class _FinancePayoutsTabState extends State<FinancePayoutsTab> {
  List<PayoutModel>? _payouts;
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
      final payouts = await DatabaseService().getPayouts(actor: actor, storeId: widget.storeId ?? actor.storeId);
      if (mounted) {
        setState(() {
          _payouts = payouts;
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return VendorTheme.success;
      case 'processing':
        return VendorTheme.warning;
      case 'pending':
      default:
        return VendorTheme.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: VendorTheme.primary));
    }

    if (_payouts == null || _payouts!.isEmpty) {
      return const VendorEmptyState(
        title: 'No Payouts Found',
        subtitle: 'Your upcoming and past payouts will appear here.',
        icon: Icons.receipt_long_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      itemCount: _payouts!.length,
      separatorBuilder: (context, index) => const SizedBox(height: VendorTheme.spacing16),
      itemBuilder: (context, index) {
        final payout = _payouts![index];
        final statusColor = _getStatusColor(payout.status);

        return PremiumVendorCard(
          padding: const EdgeInsets.all(VendorTheme.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    payout.periodLabel.isNotEmpty ? payout.periodLabel : 'Payout',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      payout.status.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: VendorTheme.spacing16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: VendorTheme.primary.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      color: VendorTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: VendorTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Created on ${DateFormat('MMM dd, yyyy').format(payout.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: VendorTheme.grey400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Payout ID: ${payout.id.substring(0, 8)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: VendorTheme.grey300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _money(payout.amount),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: VendorTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
