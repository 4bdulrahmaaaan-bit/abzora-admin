import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';

class RiderEarningsScreen extends StatelessWidget {
  const RiderEarningsScreen({super.key});

  String _money(double amount) => '₹${amount.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final rider = context.watch<AuthProvider>().user;
    if (rider == null) {
      return const Scaffold(
        body: AbzioLoadingView(
          title: 'Loading earnings',
          subtitle: 'Syncing rider wallet and payout analytics.',
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(title: const Text('Earnings')),
      body: StreamBuilder(
        stream: DatabaseService().watchPolledValue(
          () => DatabaseService().getRiderAnalytics(actor: rider),
        ),
        builder: (context, analyticsSnapshot) {
          return StreamBuilder(
            stream: DatabaseService().watchPolledValue(
              () => DatabaseService().getRiderWallet(actor: rider),
            ),
            builder: (context, walletSnapshot) {
              if (analyticsSnapshot.connectionState == ConnectionState.waiting &&
                  walletSnapshot.connectionState == ConnectionState.waiting) {
                return const AbzioLoadingView(
                  title: 'Loading earnings insights',
                  subtitle: 'Building daily, weekly and payout trend view.',
                );
              }
              final analytics = analyticsSnapshot.data;
              final wallet = walletSnapshot.data;
              final today = analytics?.earningsToday ?? 0.0;
              final pending = wallet?.pendingAmount ?? analytics?.pendingPayout ?? 0.0;
              final reserved = wallet?.reservedAmount ?? analytics?.reservedAmount ?? 0.0;
              final total = wallet?.totalEarnings ?? analytics?.totalEarnings ?? rider.walletBalance;
              final available = wallet?.balance ?? analytics?.availableBalance ?? rider.walletBalance;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F10),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EARNINGS INTELLIGENCE',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFD4B06A),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _money(today),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Today\'s earnings',
                          style: GoogleFonts.inter(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _metric('Available balance', _money(available)),
                  _metric('Pending payout', _money(pending)),
                  _metric('Reserved amount', _money(reserved)),
                  _metric('Total earnings', _money(total)),
                  if ((analytics?.transactions ?? const []).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Recent activity',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...analytics!.transactions.take(5).map(
                      (entry) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                        leading: const Icon(Icons.payments_outlined),
                        title: Text(
                          entry.note.isEmpty ? entry.status : entry.note,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(entry.status, style: GoogleFonts.inter(color: AbzioTheme.grey600)),
                        trailing: Text(
                          _money(entry.amount.abs()),
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
