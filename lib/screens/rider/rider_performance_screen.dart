import 'package:flutter/material.dart';
import '../../services/rider_performance_api.dart';
import '../../widgets/state_views.dart';

class RiderPerformanceScreen extends StatefulWidget {
  const RiderPerformanceScreen({super.key});

  @override
  State<RiderPerformanceScreen> createState() => _RiderPerformanceScreenState();
}

class _RiderPerformanceScreenState extends State<RiderPerformanceScreen> {
  Future<Map<String, dynamic>>? _performanceFuture;
  Future<List<dynamic>>? _incentivesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _performanceFuture = RiderPerformanceApi.getPerformance();
      _incentivesFuture = RiderPerformanceApi.getIncentives();
    });
    await Future.wait([_performanceFuture!, _incentivesFuture!]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: _performanceFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AbzioLoadingView(title: 'Loading stats');
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Text('Failed to load performance metrics.');
                }
                final data = snapshot.data!;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Rider Score: ${data['riderScore']}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        _buildStat(
                          'Acceptance Rate',
                          '${data['acceptanceRate']}%',
                        ),
                        _buildStat(
                          'Completion Rate',
                          '${data['completionRate']}%',
                        ),
                        _buildStat(
                          'Customer Rating',
                          '${data['customerRating']}',
                        ),
                        _buildStat('No Show Rate', '${data['noShowRate']}%'),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Active Incentives',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<dynamic>>(
              future: _incentivesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                final list = snapshot.data ?? [];
                if (list.isEmpty) return const Text('No active incentives.');
                return Column(
                  children: list
                      .map(
                        (inc) => Card(
                          child: ListTile(
                            title: Text(inc['title']),
                            subtitle: Text(
                              'Progress: ${inc['currentProgress']} / ${inc['target']}',
                            ),
                            trailing: Text('₹${inc['rewardAmount']}'),
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
