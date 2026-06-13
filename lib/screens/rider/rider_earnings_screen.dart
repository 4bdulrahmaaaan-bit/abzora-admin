import 'package:flutter/material.dart';
import '../../services/rider_earnings_api.dart';
import '../../widgets/state_views.dart';

class RiderEarningsScreen extends StatefulWidget {
  const RiderEarningsScreen({super.key});

  @override
  State<RiderEarningsScreen> createState() => _RiderEarningsScreenState();
}

class _RiderEarningsScreenState extends State<RiderEarningsScreen> {
  Future<Map<String, dynamic>>? _summaryFuture;
  Future<List<dynamic>>? _earningsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _summaryFuture = RiderEarningsApi.getEarningsSummary();
      _earningsFuture = RiderEarningsApi.getEarnings();
    });
    await Future.wait([_summaryFuture!, _earningsFuture!]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AbzioLoadingView(
                    title: 'Loading earnings summary',
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Text('Failed to load summary.');
                }
                final data = snapshot.data!;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Today: ₹${data['today']}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        _buildStat('Weekly', '₹${data['weekly']}'),
                        _buildStat('Monthly', '₹${data['monthly']}'),
                        _buildStat('Pending', '₹${data['pending']}'),
                        _buildStat('TBYB Earnings', '₹${data['tbyb']}'),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Recent Earnings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<dynamic>>(
              future: _earningsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                final list = snapshot.data ?? [];
                if (list.isEmpty) return const Text('No recent earnings.');
                return Column(
                  children: list
                      .map(
                        (e) => Card(
                          child: ListTile(
                            title: Text(
                              e['earningType']
                                  .toString()
                                  .replaceAll('_', ' ')
                                  .toUpperCase(),
                            ),
                            subtitle: Text(
                              e['status'].toString().toUpperCase(),
                            ),
                            trailing: Text(
                              '₹${e['amount']}',
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

  Widget _buildStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
