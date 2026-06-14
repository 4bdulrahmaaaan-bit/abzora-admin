import 'package:flutter/material.dart';
import '../../services/rider_performance_api.dart';
import '../../widgets/state_views.dart';

// ── Brand palette ──────────────────────────────────────────────────────────
const _ivory = Color(0xFFF8F5EF);
const _gold = Color(0xFFC8A86B);
const _dark = Color(0xFF111111);

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

  // ── Classification helper ─────────────────────────────────────────────────
  (String label, Color color) _classifyScore(int score) {
    if (score >= 90) return ('Excellent', const Color(0xFF39D98A));
    if (score >= 75) return ('Good', _gold);
    if (score >= 50) return ('Warning', const Color(0xFFF59E0B));
    return ('Critical', const Color(0xFFEF4444));
  }

  // ── Score hero card ───────────────────────────────────────────────────────
  Widget _buildScoreHero(Map<String, dynamic> data) {
    final score = (data['riderScore'] as num?)?.toInt() ?? 0;
    final (label, color) = _classifyScore(score);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _dark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2.5),
      ),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Text(
            '$score',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rider Score',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withAlpha(153),
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          // Classification badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: color.withAlpha(38),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withAlpha(128)),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Metric row with linear progress ──────────────────────────────────────
  Widget _buildMetricRow(
    String label,
    double rate, {
    Color barColor = _gold,
  }) {
    final pct = (rate.clamp(0, 100) / 100);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: _dark,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: const Color(0xFFE5DDD1),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── Customer rating stars ─────────────────────────────────────────────────
  Widget _buildStarRating(double rating) {
    final fullStars = rating.floor();
    final halfStar = (rating - fullStars) >= 0.5;
    return Row(
      children: List.generate(5, (i) {
        if (i < fullStars) {
          return const Icon(Icons.star_rounded, color: _gold, size: 22);
        }
        if (i == fullStars && halfStar) {
          return const Icon(Icons.star_half_rounded, color: _gold, size: 22);
        }
        return const Icon(Icons.star_outline_rounded, color: _gold, size: 22);
      }),
    );
  }

  Widget _buildCustomerRating(double rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Customer Rating',
            style: TextStyle(
              fontSize: 13,
              color: _dark,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              _buildStarRating(rating),
              const SizedBox(width: 8),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Metrics section card ──────────────────────────────────────────────────
  Widget _buildMetricsCard(Map<String, dynamic> data) {
    final acceptanceRate =
        (data['acceptanceRate'] as num?)?.toDouble() ?? 0.0;
    final completionRate =
        (data['completionRate'] as num?)?.toDouble() ?? 0.0;
    final onTimeRate =
        (data['onTimeRate'] ?? 0 as num).toDouble();
    final trialSuccessRate =
        (data['trialSuccessRate'] ?? 0 as num).toDouble();
    final customerRating =
        (data['customerRating'] as num?)?.toDouble() ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: _ivory,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5DDD1)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Metrics',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _dark,
              letterSpacing: 0.3,
            ),
          ),
          const Divider(height: 20, color: Color(0xFFE5DDD1)),
          _buildMetricRow(
            'Acceptance Rate',
            acceptanceRate,
            barColor: const Color(0xFF39D98A),
          ),
          _buildMetricRow(
            'Completion Rate',
            completionRate,
            barColor: _gold,
          ),
          _buildMetricRow(
            'On-Time Deliveries',
            onTimeRate,
            barColor: const Color(0xFF60A5FA),
          ),
          _buildMetricRow(
            'Trial Success Rate',
            trialSuccessRate,
            barColor: const Color(0xFFA78BFA),
          ),
          const Divider(height: 20, color: Color(0xFFE5DDD1)),
          _buildCustomerRating(customerRating),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ivory,
      appBar: AppBar(
        title: const Text('Performance'),
        backgroundColor: _dark,
        foregroundColor: _ivory,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: _gold,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Performance FutureBuilder ──────────────────────────────────
            FutureBuilder<Map<String, dynamic>>(
              future: _performanceFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AbzioLoadingView(title: 'Loading stats');
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Failed to load performance metrics.'),
                    ),
                  );
                }
                final data = snapshot.data!;
                return Column(
                  children: [
                    _buildScoreHero(data),
                    const SizedBox(height: 16),
                    _buildMetricsCard(data),
                  ],
                );
              },
            ),

            const SizedBox(height: 28),

            // ── Incentives section ─────────────────────────────────────────
            Text(
              'Active Incentives',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _dark,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<dynamic>>(
              future: _incentivesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _gold),
                  );
                }
                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('No active incentives.')),
                  );
                }
                return Column(
                  children: list
                      .map(
                        (inc) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5DDD1)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            title: Text(
                              inc['title'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _dark,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Progress: ${inc['currentProgress']} / ${inc['target']}',
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: (inc['currentProgress'] as num? ??
                                                  0)
                                              .toDouble() /
                                          ((inc['target'] as num? ?? 1)
                                              .toDouble()
                                              .clamp(1, double.infinity)),
                                      minHeight: 6,
                                      backgroundColor:
                                          const Color(0xFFE5DDD1),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              _gold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _gold.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '₹${inc['rewardAmount']}',
                                style: const TextStyle(
                                  color: Color(0xFF8B6914),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
