import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

import '../../providers/auth_provider.dart';
import '../../../theme.dart';
import '../../../widgets/state_views.dart';
import 'api/admin_finance_api.dart';

class AdminFinanceSection extends StatefulWidget {
  const AdminFinanceSection({super.key});

  @override
  State<AdminFinanceSection> createState() => _AdminFinanceSectionState();
}

class _AdminFinanceSectionState extends State<AdminFinanceSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingDashboard = true;
  String _dashboardError = '';
  Map<String, dynamic> _dashboardStats = {};

  // Settlements state
  bool _isLoadingSettlements = false;
  List<Map<String, dynamic>> _settlements = [];
  int _settlementsPage = 1;
  String _settlementTypeFilter = 'Vendor';
  String? _settlementStatusFilter;

  // Refunds state
  bool _isLoadingRefunds = false;
  List<Map<String, dynamic>> _refunds = [];
  final int _refundsPage = 1;

  // Reports state
  bool _isLoadingReports = false;
  List<Map<String, dynamic>> _reports = [];
  String _reportPeriod = 'Daily';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchDashboard();
    _fetchSettlements();
    _fetchRefunds();
    _fetchReports();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      if (_tabController.index == 1) {
        setState(() => _settlementTypeFilter = 'Vendor');
        _fetchSettlements();
      } else if (_tabController.index == 2) {
        setState(() => _settlementTypeFilter = 'Rider');
        _fetchSettlements();
      } else if (_tabController.index == 3) {
        _fetchRefunds();
      } else if (_tabController.index == 4) {
        _fetchReports();
      }
    }
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _isLoadingDashboard = true;
      _dashboardError = '';
    });
    try {
      final res = await AdminFinanceApi.fetchDashboard();
      if (mounted) {
        setState(() {
          _dashboardStats = res;
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

  Future<void> _fetchSettlements() async {
    setState(() => _isLoadingSettlements = true);
    try {
      final res = await AdminFinanceApi.fetchSettlements(
        page: _settlementsPage,
        limit: 25,
        type: _settlementTypeFilter,
        status: _settlementStatusFilter,
      );
      if (mounted) {
        setState(() {
          _settlements = res['settlements'] as List<Map<String, dynamic>>;

          _isLoadingSettlements = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching settlements: $e');
      if (mounted) setState(() => _isLoadingSettlements = false);
    }
  }

  Future<void> _fetchRefunds() async {
    setState(() => _isLoadingRefunds = true);
    try {
      final res = await AdminFinanceApi.fetchRefunds(
        page: _refundsPage,
        limit: 25,
      );
      if (mounted) {
        setState(() {
          _refunds = res['refunds'] as List<Map<String, dynamic>>;

          _isLoadingRefunds = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching refunds: $e');
      if (mounted) setState(() => _isLoadingRefunds = false);
    }
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoadingReports = true);
    try {
      final res = await AdminFinanceApi.fetchReports(_reportPeriod);
      if (mounted) {
        setState(() {
          _reports = res;
          _isLoadingReports = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching reports: $e');
      if (mounted) setState(() => _isLoadingReports = false);
    }
  }

  Future<void> _exportCSV(
    String filename,
    List<String> headers,
    List<List<dynamic>> rows,
  ) async {
    String csv = '${headers.join(',')}\n';
    for (final row in rows) {
      csv +=
          '${row.map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',')}\n';
    }

    final bytes = utf8.encode(csv);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename.csv');
      await file.writeAsBytes(bytes);
      if (mounted) {
        await Share.shareXFiles([
          XFile(file.path, mimeType: 'text/csv'),
        ], text: 'Exported $filename.csv');
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
    final auth = context.watch<AuthProvider>();
    if (!auth.isAdmin) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: AbzioEmptyCard(
              title: 'Admin access only',
              subtitle: 'Finance is restricted to platform administrators.',
            ),
          ),
        ),
      );
    }
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
                  'Finance & Settlement Center',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: AbzioTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Centralized financial command center for marketplace revenue and payouts.',
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
            Tab(text: 'Overview'),
            Tab(text: 'Vendor Settlements'),
            Tab(text: 'Rider Settlements'),
            Tab(text: 'Refund Ledger'),
            Tab(text: 'Reports & Exports'),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildSettlementsTab('Vendor'),
              _buildSettlementsTab('Rider'),
              _buildRefundsTab(),
              _buildReportsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    if (_isLoadingDashboard) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_dashboardError.isNotEmpty) {
      return Center(child: Text('Error: $_dashboardError'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildMetricCard(
                'Gross Merchandise Value (GMV)',
                '₹${_dashboardStats['gmv'] ?? 0}',
                Colors.blue.shade50,
              ),
              _buildMetricCard(
                'Net Revenue',
                '₹${_dashboardStats['netRevenue'] ?? 0}',
                Colors.green.shade50,
              ),
              _buildMetricCard(
                'Platform Commission',
                '₹${_dashboardStats['platformCommission'] ?? 0}',
                Colors.orange.shade50,
              ),
              _buildMetricCard(
                'Trial Revenue',
                '₹${_dashboardStats['trialRevenue'] ?? 0}',
                Colors.purple.shade50,
              ),
              _buildMetricCard(
                'Refund Exposure',
                '₹${_dashboardStats['refundExposure'] ?? 0}',
                Colors.red.shade50,
              ),
              _buildMetricCard(
                'Settlement Success Rate',
                '${_dashboardStats['settlementSuccessRate']?.toStringAsFixed(1) ?? 100}%',
                Colors.teal.shade50,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Growth & Health Indicators',
            style: context.abzioText.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSmallCard(
                'Finance Health Score',
                _dashboardStats['financeHealthScore'] ?? 'Healthy',
              ),
              const SizedBox(width: 16),
              _buildSmallCard(
                'Revenue Growth',
                _dashboardStats['revenueGrowthPercent'] ?? '0%',
              ),
              const SizedBox(width: 16),
              _buildSmallCard(
                'Commission Growth',
                _dashboardStats['commissionGrowthPercent'] ?? '0%',
              ),
              const SizedBox(width: 16),
              _buildSmallCard(
                'Refund Ratio',
                _dashboardStats['refundRatio'] ?? '0%',
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
                          'Pending Settlements',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${_dashboardStats['pendingSettlementsCount'] ?? 0} settlements',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${_dashboardStats['pendingSettlementsValue'] ?? 0}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Completed Settlements',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${_dashboardStats['completedSettlementsCount'] ?? 0} settlements successfully processed.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
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

  Widget _buildSmallCard(String title, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettlementsTab(String type) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                initialValue: _settlementStatusFilter,
                decoration: const InputDecoration(
                  labelText: 'Status Filter',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                  DropdownMenuItem(
                    value: 'Processing',
                    child: Text('Processing'),
                  ),
                  DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'Failed', child: Text('Failed')),
                ],
                onChanged: (v) {
                  setState(() {
                    _settlementStatusFilter = v;
                    _settlementsPage = 1;
                  });
                  _fetchSettlements();
                },
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _exportCSV(
                  '${type}_Settlements',
                  [
                    'ID',
                    'Entity ID',
                    'Gross Amount',
                    'Platform Fees',
                    'Taxes',
                    'Net Amount',
                    'Status',
                    'Date',
                  ],
                  _settlements
                      .map(
                        (s) => [
                          s['settlementId'],
                          s['entityId'],
                          s['grossAmount'],
                          s['platformFees'],
                          s['taxes'],
                          s['netAmount'],
                          s['status'],
                          s['createdAt'],
                        ],
                      )
                      .toList(),
                );
              },
              icon: const Icon(Icons.download),
              label: const Text('Export CSV'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoadingSettlements
              ? const Center(child: CircularProgressIndicator())
              : _settlements.isEmpty
              ? const Center(child: Text('No settlements found.'))
              : Card(
                  child: ListView(
                    children: [
                      DataTable(
                        columns: const [
                          DataColumn(label: Text('ID')),
                          DataColumn(label: Text('Entity')),
                          DataColumn(label: Text('Gross')),
                          DataColumn(label: Text('Fees')),
                          DataColumn(label: Text('Net Amount')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Created Date')),
                        ],
                        rows: _settlements.map((s) {
                          return DataRow(
                            cells: [
                              DataCell(Text(s['settlementId'] ?? '')),
                              DataCell(Text(s['entityId'] ?? '')),
                              DataCell(Text('₹${s['grossAmount'] ?? 0}')),
                              DataCell(Text('₹${s['platformFees'] ?? 0}')),
                              DataCell(
                                Text(
                                  '₹${s['netAmount'] ?? 0}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(Chip(label: Text(s['status'] ?? ''))),
                              DataCell(
                                Text(
                                  s['createdAt']?.toString().split('T')[0] ??
                                      '',
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildRefundsTab() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                _exportCSV(
                  'Refund_Ledger',
                  ['Order ID', 'Amount', 'Reason', 'Status', 'Date'],
                  _refunds
                      .map(
                        (r) => [
                          r['orderId'],
                          r['amount'],
                          r['reason'],
                          r['status'],
                          r['createdAt'],
                        ],
                      )
                      .toList(),
                );
              },
              icon: const Icon(Icons.download),
              label: const Text('Export CSV'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoadingRefunds
              ? const Center(child: CircularProgressIndicator())
              : _refunds.isEmpty
              ? const Center(child: Text('No refunds found.'))
              : Card(
                  child: ListView(
                    children: [
                      DataTable(
                        columns: const [
                          DataColumn(label: Text('Order ID')),
                          DataColumn(label: Text('Amount')),
                          DataColumn(label: Text('Reason')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Requested Date')),
                        ],
                        rows: _refunds.map((r) {
                          return DataRow(
                            cells: [
                              DataCell(Text(r['orderId'] ?? '')),
                              DataCell(Text('₹${r['amount'] ?? 0}')),
                              DataCell(Text(r['reason'] ?? '')),
                              DataCell(Chip(label: Text(r['status'] ?? ''))),
                              DataCell(
                                Text(
                                  r['createdAt']?.toString().split('T')[0] ??
                                      '',
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                initialValue: _reportPeriod,
                decoration: const InputDecoration(
                  labelText: 'Report Period',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                  DropdownMenuItem(
                    value: 'Quarterly',
                    child: Text('Quarterly'),
                  ),
                  DropdownMenuItem(value: 'Yearly', child: Text('Yearly')),
                ],
                onChanged: (v) {
                  setState(() => _reportPeriod = v!);
                  _fetchReports();
                },
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _exportCSV(
                  'Finance_Report_$_reportPeriod',
                  ['Date', 'Revenue', 'Commission', 'Settlements', 'Refunds'],
                  _reports
                      .map(
                        (r) => [
                          r['date'],
                          r['revenue'],
                          r['commission'],
                          r['settlements'],
                          r['refunds'],
                        ],
                      )
                      .toList(),
                );
              },
              icon: const Icon(Icons.download),
              label: const Text('Export Report to CSV'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoadingReports
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
              ? const Center(child: Text('No report data found.'))
              : Card(
                  child: ListView(
                    children: [
                      DataTable(
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Revenue')),
                          DataColumn(label: Text('Commission')),
                          DataColumn(label: Text('Settlements')),
                          DataColumn(label: Text('Refunds')),
                        ],
                        rows: _reports.map((r) {
                          return DataRow(
                            cells: [
                              DataCell(Text(r['date'] ?? '')),
                              DataCell(Text('₹${r['revenue'] ?? 0}')),
                              DataCell(Text('₹${r['commission'] ?? 0}')),
                              DataCell(Text('₹${r['settlements'] ?? 0}')),
                              DataCell(Text('₹${r['refunds'] ?? 0}')),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
