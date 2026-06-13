import 'package:flutter/material.dart';
import '../../services/rider_settlement_api.dart';
import '../../widgets/state_views.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payouts')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<Map<String, dynamic>?>(
              future: _upcomingFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AbzioLoadingView(
                    title: 'Loading payout details',
                  );
                }
                final data = snapshot.data;
                if (data == null) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No upcoming payouts.'),
                    ),
                  );
                }
                return Card(
                  color: Theme.of(context).primaryColorLight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upcoming Payout',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${data['netPayout']}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          'Status: ${data['status'].toString().toUpperCase()}',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Payout History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<dynamic>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                final list = snapshot.data ?? [];
                if (list.isEmpty) return const Text('No past settlements.');
                return Column(
                  children: list
                      .map(
                        (s) => Card(
                          child: ListTile(
                            title: Text(
                              'Settlement ${s['_id'].toString().substring(0, 8)}',
                            ),
                            subtitle: Text(
                              s['status'].toString().toUpperCase(),
                            ),
                            trailing: Text(
                              '₹${s['netPayout']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
