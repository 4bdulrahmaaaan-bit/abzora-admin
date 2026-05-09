import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/rider_glass_card.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';

class RiderEarningsScreen extends StatelessWidget {
  const RiderEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final db = DatabaseService();
    return FutureBuilder<WalletSummary>(
      future: db.getRiderWallet(actor: user),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final wallet = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            RiderGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available Balance'),
                  const SizedBox(height: 6),
                  Text('Rs ${wallet.balance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RiderGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recent Payout Transactions', style: TextStyle(fontWeight: FontWeight.w700)),
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
