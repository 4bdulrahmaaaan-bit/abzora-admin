import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme.dart';
import 'api/admin_business_analytics_api.dart';

class AdminAnalyticsSection extends StatefulWidget {
  const AdminAnalyticsSection({super.key});

  @override
  State<AdminAnalyticsSection> createState() => _AdminAnalyticsSectionState();
}

class _AdminAnalyticsSectionState extends State<AdminAnalyticsSection> {
  bool _isLoading = true;
  String _error = '';
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final res = await AdminBusinessAnalyticsApi.fetchAnalyticsV2();
      if (mounted) {
        setState(() {
          _data = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) return Center(child: Text('Error: $_error'));

    final overview = _data['overview'] ?? {};
    final trends = _data['trends'] as List? ?? [];
    final geographic = _data['geographic'] as List? ?? [];
    final topVendors = _data['topVendors'] as List? ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business Analytics V2',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              fontSize: 28,
              color: AbzioTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Live aggregated metrics for platform operational oversight.',
            style: GoogleFonts.inter(
              color: AbzioTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          Text('Platform Overview', style: context.abzioText.titleMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildMetricCard(
                'Total Revenue',
                '₹${overview['totalRevenue'] ?? 0}',
                Colors.blue.shade50,
              ),
              _buildMetricCard(
                'Orders Today',
                '${overview['todayOrders'] ?? 0}',
                Colors.green.shade50,
              ),
              _buildMetricCard(
                'Total Orders',
                '${overview['totalOrders'] ?? 0}',
                Colors.orange.shade50,
              ),
              _buildMetricCard(
                'Active Trials',
                '${overview['totalTrials'] ?? 0}',
                Colors.purple.shade50,
              ),
              _buildMetricCard(
                'Active Vendors',
                '${overview['activeVendors'] ?? 0}',
                Colors.teal.shade50,
              ),
              _buildMetricCard(
                'Registered Users',
                '${overview['totalUsers'] ?? 0}',
                Colors.indigo.shade50,
              ),
            ],
          ),
          const SizedBox(height: 32),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Revenue Trends (Last 7 Days)',
                          style: context.abzioText.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        ...trends.map(
                          (t) => ListTile(
                            title: Text(t['date']),
                            trailing: Text(
                              '₹${t['revenue']} (${t['orders']} orders)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Geographic Distribution',
                              style: context.abzioText.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            ...geographic.map(
                              (g) => ListTile(
                                dense: true,
                                title: Text(g['city']),
                                trailing: Text(
                                  '${g['percentage']}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Top Performing Vendors',
                              style: context.abzioText.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            if (topVendors.isEmpty)
                              const Text('No vendor data available yet.'),
                            ...topVendors.map(
                              (v) => ListTile(
                                dense: true,
                                title: Text(v['storeName'] ?? 'Unknown'),
                                subtitle: Text('${v['orderCount']} orders'),
                                trailing: Text('₹${v['totalRevenue']}'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
