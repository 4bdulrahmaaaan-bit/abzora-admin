import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

import '../../../theme.dart';
import 'api/admin_rider_intelligence_api.dart';

class AdminRiderIntelligenceSection extends StatefulWidget {
  const AdminRiderIntelligenceSection({super.key});

  @override
  State<AdminRiderIntelligenceSection> createState() =>
      _AdminRiderIntelligenceSectionState();
}

class _AdminRiderIntelligenceSectionState
    extends State<AdminRiderIntelligenceSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoadingDashboard = true;
  String _dashboardError = '';
  Map<String, dynamic> _kpis = {};

  bool _isLoadingRiders = false;
  List<Map<String, dynamic>> _riders = [];
  int _ridersPage = 1;
  int _ridersTotalPages = 1;
  String? _classificationFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchDashboard();
    _fetchRiders();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      if (_tabController.index == 0) {
        _fetchDashboard();
      } else if (_tabController.index == 1) {
        _fetchRiders();
      }
    }
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _isLoadingDashboard = true;
      _dashboardError = '';
    });
    try {
      final res = await AdminRiderIntelligenceApi.fetchDashboard();
      if (mounted) {
        setState(() {
          _kpis = res;
          _isLoadingDashboard = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dashboardError = e.toString();
          _isLoadingDashboard = false;
        });
      }
    }
  }

  Future<void> _fetchRiders() async {
    setState(() => _isLoadingRiders = true);
    try {
      final res = await AdminRiderIntelligenceApi.fetchRidersList(
        page: _ridersPage,
        limit: 25,
        classification: _classificationFilter,
      );
      if (mounted) {
        setState(() {
          _riders = res['riders'] as List<Map<String, dynamic>>;
          _ridersTotalPages = res['meta']['totalPages'] ?? 1;
          _isLoadingRiders = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching riders: $e');
      if (mounted) setState(() => _isLoadingRiders = false);
    }
  }

  Future<void> _exportCSV() async {
    String csv =
        'ID,Name,Phone,Classification,Health Score,Risk Score,Earnings\n';
    for (final row in _riders) {
      final line = [
        row['_id'],
        row['name'],
        row['phone'],
        row['classification'],
        row['healthScore'],
        row['riskScore'],
        row['earnings'],
      ].map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',');
      csv += '$line\n';
    }

    final bytes = utf8.encode(csv);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Rider_Intelligence_List.csv');
      await file.writeAsBytes(bytes);
      if (mounted) {
        await Share.shareXFiles([
          XFile(file.path, mimeType: 'text/csv'),
        ], text: 'Exported Rider_Intelligence_List.csv');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save file: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rider Intelligence V2',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: AbzioTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Advanced analytics and performance tracking for the delivery fleet.',
                  style: GoogleFonts.inter(
                    color: AbzioTheme.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Fleet Intelligence'),
            Tab(text: 'Rider Directory'),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildDashboardTab(), _buildRidersTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardTab() {
    if (_isLoadingDashboard) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_dashboardError.isNotEmpty) {
      return Center(child: Text('Error: $_dashboardError'));
    }

    final classif = _kpis['overallClassification'] ?? 'Healthy';
    final classifColor = classif == 'Critical'
        ? Colors.red
        : classif == 'Warning'
        ? Colors.orange
        : Colors.green;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildMetricCard(
                'Total Riders',
                '${_kpis['totalRiders'] ?? 0}',
                Colors.blue.shade50,
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                'Active Now',
                '${_kpis['activeRiders'] ?? 0}',
                Colors.green.shade50,
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                'Fleet Health Score',
                '${_kpis['riderHealthScore'] ?? 0}/100',
                Colors.teal.shade50,
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                'Fleet Risk Score',
                '${_kpis['riderRiskScore'] ?? 0}/100',
                Colors.red.shade50,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetricCard(
                'Avg Earnings',
                '${_kpis['avgEarningsTrend'] ?? '0'}',
                Colors.purple.shade50,
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                'Trial Performance',
                '${_kpis['avgTrialPerformance'] ?? '0%'}',
                Colors.indigo.shade50,
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                'Delivery Performance',
                '${_kpis['avgDeliveryPerformance'] ?? '0%'}',
                Colors.amber.shade50,
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                'SLA Performance',
                '${_kpis['slaPerformance'] ?? '0%'}',
                Colors.grey.shade200,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overall Fleet Classification',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: classifColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            classif,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Complaint Rate: ${_kpis['complaintRate'] ?? '0%'}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Expanded(
                flex: 2,
                child: SizedBox(),
              ), // Placeholder for chart
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
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
      ),
    );
  }

  Widget _buildRidersTab() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                initialValue: _classificationFilter,
                decoration: const InputDecoration(
                  labelText: 'Classification Filter',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(value: 'Healthy', child: Text('Healthy')),
                  DropdownMenuItem(value: 'Warning', child: Text('Warning')),
                  DropdownMenuItem(value: 'Critical', child: Text('Critical')),
                ],
                onChanged: (v) {
                  setState(() {
                    _classificationFilter = v;
                    _ridersPage = 1;
                  });
                  _fetchRiders();
                },
              ),
            ),
            ElevatedButton.icon(
              onPressed: _exportCSV,
              icon: const Icon(Icons.download),
              label: const Text('Export CSV'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoadingRiders
              ? const Center(child: CircularProgressIndicator())
              : _riders.isEmpty
              ? const Center(
                  child: Text('No riders found for this classification.'),
                )
              : Card(
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Name')),
                                DataColumn(label: Text('Phone')),
                                DataColumn(label: Text('Classification')),
                                DataColumn(label: Text('Health Score')),
                                DataColumn(label: Text('Risk Score')),
                                DataColumn(label: Text('Earnings')),
                              ],
                              rows: _riders.map((p) {
                                final classif =
                                    p['classification'] ?? 'Healthy';
                                final classifColor = classif == 'Critical'
                                    ? Colors.red
                                    : classif == 'Warning'
                                    ? Colors.orange
                                    : Colors.green;
                                return DataRow(
                                  cells: [
                                    DataCell(Text(p['name'] ?? 'N/A')),
                                    DataCell(Text(p['phone'] ?? '')),
                                    DataCell(
                                      Chip(
                                        label: Text(
                                          classif,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        backgroundColor: classifColor,
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${p['healthScore'] ?? 0}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${p['riskScore'] ?? 0}',
                                        style: TextStyle(
                                          color: p['riskScore'] > 50
                                              ? Colors.red
                                              : Colors.black,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text('₹${p['earnings'] ?? 0}')),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Page $_ridersPage of $_ridersTotalPages'),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: _ridersPage > 1
                                      ? () {
                                          setState(() => _ridersPage--);
                                          _fetchRiders();
                                        }
                                      : null,
                                  child: const Text('Previous'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: _ridersPage < _ridersTotalPages
                                      ? () {
                                          setState(() => _ridersPage++);
                                          _fetchRiders();
                                        }
                                      : null,
                                  child: const Text('Next'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
