import 'package:flutter/material.dart';
import '../../services/rider_settlement_api.dart';
import '../../widgets/state_views.dart';

// Rider palette
const _kIvory = Color(0xFFF8F5EF);
const _kGold = Color(0xFFC8A86B);
const _kGreen = Color(0xFF39D98A);
const _kAmber = Color(0xFFF59E0B);
const _kRed = Color(0xFFEF4444);

class RiderPayoutsScreen extends StatefulWidget {
  const RiderPayoutsScreen({super.key});

  @override
  State<RiderPayoutsScreen> createState() => _RiderPayoutsScreenState();
}

class _RiderPayoutsScreenState extends State<RiderPayoutsScreen> {
  Future<Map<String, dynamic>?>? _upcomingFuture;
  Future<List<dynamic>>? _historyFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _upcomingFuture = RiderSettlementApi.getUpcomingPayout();
      _historyFuture = RiderSettlementApi.getPayoutHistory();
    });
    await Future.wait([_upcomingFuture as Future, _historyFuture as Future]);
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  Color _chipColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return _kGreen;
      case 'processing':
        return _kAmber;
      case 'failed':
        return _kRed;
      default:
        return Colors.grey;
    }
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _chipColor(status).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _chipColor(status), width: 1.2),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: _chipColor(status),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // ── overview cards ────────────────────────────────────────────────────────

  Widget _overviewCards(Map<String, dynamic>? data) {
    final balance = data?['netPayout']?.toString() ?? '—';
    final pending = data?['pendingAmount']?.toString() ?? '—';
    final nextDate = data?['scheduledDate']?.toString() ?? 'TBD';

    return Row(
      children: [
        _overviewCard(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Available Balance',
          value: balance == '—' ? '—' : '₹$balance',
        ),
        const SizedBox(width: 10),
        _overviewCard(
          icon: Icons.hourglass_top_rounded,
          label: 'Pending Settlement',
          value: pending == '—' ? '—' : '₹$pending',
        ),
        const SizedBox(width: 10),
        _overviewCard(
          icon: Icons.calendar_today_rounded,
          label: 'Next Settlement',
          value: nextDate,
          isDate: true,
        ),
      ],
    );
  }

  Widget _overviewCard({
    required IconData icon,
    required String label,
    required String value,
    bool isDate = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kGold.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: _kGold.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _kGold, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: isDate ? 12 : 15,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1C1C2E),
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF8A8A9A),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  // ── section header ────────────────────────────────────────────────────────

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF8A8A9A),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ── payout account section ────────────────────────────────────────────────

  Widget _payoutAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        _sectionHeader('PAYOUT ACCOUNT'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kGold.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: _kGold.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _kGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_rounded, color: _kGold),
            ),
            title: const Text(
              'Bank / UPI Details',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text(
              'Manage where your earnings are sent',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A8A9A)),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF8A8A9A)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Manage payout account from Profile → Banking'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kIvory,
      appBar: AppBar(
        title: const Text('Wallet & Settlement Center'),
        backgroundColor: _kIvory,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1C1C2E),
      ),
      body: RefreshIndicator(
        color: _kGold,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            // ── Overview Cards (driven by upcoming payout data) ──────────
            FutureBuilder<Map<String, dynamic>?>(
              future: _upcomingFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: AbzioLoadingView(title: 'Loading wallet details'),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _overviewCards(snapshot.data),
                    const SizedBox(height: 24),

                    // ── Legacy upcoming payout detail card ───────────────
                    if (snapshot.data != null) ...[
                      _sectionHeader('UPCOMING PAYOUT'),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _kGold.withValues(alpha: 0.18),
                              _kGold.withValues(alpha: 0.06),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _kGold.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Net Payout',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF8A8A9A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${snapshot.data!['netPayout'] ?? '—'}',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1C1C2E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _statusChip(
                                snapshot.data!['status']?.toString() ??
                                    'unknown'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                );
              },
            ),

            // ── Settlement History ────────────────────────────────────────
            _sectionHeader('SETTLEMENT HISTORY'),
            FutureBuilder<List<dynamic>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(color: _kGold),
                    ),
                  );
                }
                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kGold.withValues(alpha: 0.2)),
                    ),
                    child: const Center(
                      child: Text(
                        'No past settlements.',
                        style:
                            TextStyle(color: Color(0xFF8A8A9A), fontSize: 14),
                      ),
                    ),
                  );
                }
                return Column(
                  children: list.map((s) {
                    final id = s['_id']?.toString() ?? '';
                    final shortId =
                        id.length >= 8 ? id.substring(0, 8) : id;
                    final status = s['status']?.toString() ?? 'unknown';
                    final amount = s['netPayout']?.toString() ?? '—';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kGold.withValues(alpha: 0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _chipColor(status).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: _chipColor(status),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Settlement #$shortId',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF1C1C2E),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _statusChip(status),
                        ),
                        trailing: Text(
                          '₹$amount',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF1C1C2E),
                          ),
                        ),
                        isThreeLine: false,
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            // ── Payout Account ────────────────────────────────────────────
            _payoutAccountSection(),
          ],
        ),
      ),
    );
  }
}
