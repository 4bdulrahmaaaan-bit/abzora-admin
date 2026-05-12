import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:abzio/features/dashboard/rider_earnings_screen.dart';
import 'package:abzio/features/dashboard/rider_orders_screen.dart';
import 'package:abzio/features/profile/rider_profile_screen.dart';
import 'package:abzio/features/settings/rider_settings_screen.dart';

import '../../core/widgets/rider_glass_card.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';

class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  final _db = DatabaseService();
  int _index = 0;
  bool _online = true;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      _home(user),
      const RiderOrdersScreen(),
      const RiderEarningsScreen(),
      const RiderProfileScreen(),
      const RiderSettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Abzora Rider')),
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.currency_rupee),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _home(AppUser user) {
    return FutureBuilder<RiderAnalytics>(
      future: _db.getRiderAnalytics(actor: user),
      builder: (context, analyticsSnap) {
        return FutureBuilder<WalletSummary>(
          future: _db.getRiderWallet(actor: user),
          builder: (context, walletSnap) {
            final analytics = analyticsSnap.data;
            final wallet = walletSnap.data;
            final error = analyticsSnap.error ?? walletSnap.error;
            final loading =
                analyticsSnap.connectionState == ConnectionState.waiting ||
                walletSnap.connectionState == ConnectionState.waiting;
            if (error != null && !loading) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RiderGlassCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Unable to load dashboard right now'),
                        const SizedBox(height: 8),
                        Text(error.toString(), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                RiderGlassCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Switch(
                        value: _online,
                        activeThumbColor: const Color(0xFFD4AF37),
                        onChanged: (v) => setState(() => _online = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (loading)
                  const LinearProgressIndicator(color: Color(0xFFD4AF37)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Wallet',
                        value:
                            'Rs ${((wallet?.balance ?? 0)).toStringAsFixed(0)}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Deliveries Today',
                        value: '${analytics?.todayDeliveries ?? 0}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Earnings Today',
                        value:
                            'Rs ${((analytics?.earningsToday ?? 0)).toStringAsFixed(0)}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Pending Payout',
                        value:
                            'Rs ${((analytics?.pendingPayout ?? 0)).toStringAsFixed(0)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RiderGlassCard(
                  child: SizedBox(
                    height: 200,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(
                          user.latitude ?? 12.9716,
                          user.longitude ?? 77.5946,
                        ),
                        initialZoom: 12,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                RiderGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Transactions',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ...(wallet?.transactions
                              .take(2)
                              .map(
                                (t) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(t.note.isEmpty ? t.type : t.note),
                                  subtitle: Text(t.createdAt),
                                  trailing: Text(
                                    'Rs ${t.amount.toStringAsFixed(0)}',
                                  ),
                                ),
                              ) ??
                          [
                            const ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('No recent transactions'),
                            ),
                          ]),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RiderGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color.fromRGBO(255, 255, 255, 0.72)),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
        ],
      ),
    );
  }
}
