import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/rider_telemetry.dart';
import '../../core/widgets/rider_glass_card.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/payout_account_dialog.dart';

class RiderEarningsScreen extends StatefulWidget {
  const RiderEarningsScreen({super.key});

  @override
  State<RiderEarningsScreen> createState() => _RiderEarningsScreenState();
}

class _RiderEarningsScreenState extends State<RiderEarningsScreen> {
  final DatabaseService _db = DatabaseService();
  bool _loading = false;

  Future<void> _withdraw(AppUser user) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request withdrawal'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Enter amount in Rs'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              Navigator.of(context).pop(value);
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0) return;

    setState(() => _loading = true);
    try {
      await _db.requestRiderWithdraw(amount: amount, actor: user);
      RiderTelemetry.event('withdrawal_requested', data: {'amount': amount});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal request submitted')),
      );
      setState(() {});
    } catch (error) {
      RiderTelemetry.event('withdrawal_failed', data: {'error': error.toString()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _managePayout(AppUser user, PayoutProfileSummary profile) async {
    final formValue = await showPayoutAccountDialog(
      context: context,
      title: 'Rider payout account',
      initialValue: profile,
    );
    if (formValue == null) return;

    setState(() => _loading = true);
    try {
      await _db.saveRiderPayoutProfile(
        actor: user,
        methodType: formValue.methodType,
        accountHolderName: formValue.accountHolderName,
        upiId: formValue.upiId,
        bankAccountNumber: formValue.bankAccountNumber,
        bankIfsc: formValue.bankIfsc,
        bankName: formValue.bankName,
      );
      RiderTelemetry.event('payout_profile_saved');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout account saved')),
      );
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<WalletSummary>(
      future: _db.getRiderWallet(actor: user),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final wallet = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(color: Color(0xFFFF6B00)),
            RiderGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available Balance'),
                  const SizedBox(height: 6),
                  Text(
                    'Rs ${wallet.balance.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton(
                        onPressed: _loading ? null : () => _withdraw(user),
                        child: const Text('Request Withdrawal'),
                      ),
                      OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () => _managePayout(user, wallet.payoutProfile),
                        child: Text(wallet.payoutProfile.isConfigured ? 'Edit Payout Account' : 'Setup Payout Account'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RiderGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Payout Transactions',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...wallet.transactions.take(5).map(
                    (t) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.note.isEmpty ? t.type : t.note),
                      subtitle: Text(t.createdAt),
                      trailing: Text('Rs ${t.amount.toStringAsFixed(0)}'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

