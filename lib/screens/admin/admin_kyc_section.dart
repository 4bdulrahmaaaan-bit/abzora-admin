import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

import '../../../theme.dart';
import 'api/admin_kyc_api.dart';

class AdminKycSection extends StatefulWidget {
  const AdminKycSection({super.key});

  @override
  State<AdminKycSection> createState() => _AdminKycSectionState();
}

class _AdminKycSectionState extends State<AdminKycSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoadingDashboard = true;
  String _dashboardError = '';
  Map<String, dynamic> _kpis = {};

  bool _isLoadingApps = false;
  List<Map<String, dynamic>> _apps = [];
  int _appsPage = 1;
  int _appsTotalPages = 1;
  String _appTypeFilter = 'Vendor';
  String? _appStatusFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchDashboard();
    _fetchApps();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      if (_tabController.index == 0) {
        _fetchDashboard();
      } else if (_tabController.index == 1) {
        setState(() {
          _appTypeFilter = 'Vendor';
          _appsPage = 1;
        });
        _fetchApps();
      } else if (_tabController.index == 2) {
        setState(() {
          _appTypeFilter = 'Rider';
          _appsPage = 1;
        });
        _fetchApps();
      }
    }
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _isLoadingDashboard = true;
      _dashboardError = '';
    });
    try {
      final res = await AdminKycApi.fetchDashboard();
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

  Future<void> _fetchApps() async {
    setState(() => _isLoadingApps = true);
    try {
      final res = await AdminKycApi.fetchApplications(
        page: _appsPage,
        limit: 25,
        type: _appTypeFilter,
        status: _appStatusFilter,
      );
      if (mounted) {
        setState(() {
          _apps = res['applications'] as List<Map<String, dynamic>>;
          _appsTotalPages = res['meta']['totalPages'] ?? 1;
          _isLoadingApps = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching apps: $e');
      if (mounted) setState(() => _isLoadingApps = false);
    }
  }

  Future<void> _exportCSV() async {
    String csv = 'ID,Name/Store,Email,Phone,Status,Submitted At\n';
    for (final row in _apps) {
      final name = row['storeName'] ?? row['name'] ?? 'N/A';
      final line = [
        row['_id'],
        name,
        row['email'],
        row['phone'],
        row['kycStatus'],
        row['kycSubmittedAt'],
      ].map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',');
      csv += '$line\n';
    }

    final bytes = utf8.encode(csv);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/KYC_${_appTypeFilter}_Applications.csv');
      await file.writeAsBytes(bytes);
      if (mounted) {
        await Share.shareXFiles([
          XFile(file.path, mimeType: 'text/csv'),
        ], text: 'Exported KYC_${_appTypeFilter}_Applications.csv');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save file: $e')));
      }
    }
  }

  void _openReviewDialog(Map<String, dynamic> app) {
    final statusCtrl = TextEditingController(
      text: app['kycStatus'] ?? 'Pending',
    );
    final notesCtrl = TextEditingController(text: app['kycNotes'] ?? '');

    // Attempt to extract docs
    final docs = app['kycDocuments'] as Map? ?? {};

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Review KYC: ${app['storeName'] ?? app['name'] ?? 'Unknown'}',
          ),
          content: SizedBox(
            width: 800,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Uploaded Documents',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      if (docs.isEmpty)
                        const Text('No documents uploaded.')
                      else
                        ...docs.entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: InkWell(
                              onTap: () {
                                // html.window.open(e.value.toString(), '_blank');
                                // In a real app with cross platform support, you'd use url_launcher here
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.file_present),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text('${e.key}: ${e.value}'),
                                    ),
                                    const Icon(Icons.open_in_new, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue:
                            [
                              'Pending',
                              'Approved',
                              'Rejected',
                            ].contains(statusCtrl.text)
                            ? statusCtrl.text
                            : 'Pending',
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Pending',
                            child: Text('Pending'),
                          ),
                          DropdownMenuItem(
                            value: 'Approved',
                            child: Text('Approved'),
                          ),
                          DropdownMenuItem(
                            value: 'Rejected',
                            child: Text('Rejected'),
                          ),
                        ],
                        onChanged: (v) => statusCtrl.text = v ?? 'Pending',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Review Notes',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                try {
                  await AdminKycApi.reviewApplication(
                    app['_id'],
                    _appTypeFilter,
                    statusCtrl.text,
                    notesCtrl.text,
                  );
                  if (mounted) {
                    navigator.pop();
                  }
                  _fetchApps();
                  _fetchDashboard();
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              },
              child: const Text('Submit Review'),
            ),
          ],
        );
      },
    );
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
                  'KYC Command Center',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: AbzioTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Document verification and compliance operations for vendors and riders.',
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
            Tab(text: 'Overview & KPIs'),
            Tab(text: 'Vendor KYC'),
            Tab(text: 'Rider KYC'),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDashboardTab(),
              _buildAppsTab('Vendor'),
              _buildAppsTab('Rider'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardTab() {
    if (_isLoadingDashboard)
      return const Center(child: CircularProgressIndicator());
    if (_dashboardError.isNotEmpty)
      return Center(child: Text('Error: $_dashboardError'));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildMetricCard(
                'Pending Requests',
                '${_kpis['pendingRequests'] ?? 0}',
                Colors.orange.shade50,
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                'Approved Requests',
                '${_kpis['approvedRequests'] ?? 0}',
                Colors.green.shade50,
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                'Rejected Requests',
                '${_kpis['rejectedRequests'] ?? 0}',
                Colors.red.shade50,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetricCard(
                'Avg Approval Time',
                '${_kpis['averageApprovalTimeHours'] ?? 0} hrs',
                Colors.blue.shade50,
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                'Success Rate',
                '${_kpis['verificationSuccessRate']?.toStringAsFixed(1) ?? 0}%',
                Colors.teal.shade50,
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                'Expired Documents',
                '${_kpis['expiredDocuments'] ?? 0}',
                Colors.grey.shade200,
              ),
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

  Widget _buildAppsTab(String type) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                initialValue: _appStatusFilter,
                decoration: const InputDecoration(
                  labelText: 'Status Filter',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                ],
                onChanged: (v) {
                  setState(() {
                    _appStatusFilter = v;
                    _appsPage = 1;
                  });
                  _fetchApps();
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
          child: _isLoadingApps
              ? const Center(child: CircularProgressIndicator())
              : _apps.isEmpty
              ? Center(child: Text('No $type applications found.'))
              : Card(
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: [
                                DataColumn(
                                  label: Text(
                                    type == 'Vendor' ? 'Store Name' : 'Name',
                                  ),
                                ),
                                const DataColumn(label: Text('Email')),
                                const DataColumn(label: Text('Phone')),
                                const DataColumn(label: Text('Status')),
                                const DataColumn(label: Text('Submitted')),
                                const DataColumn(label: Text('Actions')),
                              ],
                              rows: _apps.map((p) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        p['storeName'] ?? p['name'] ?? 'N/A',
                                      ),
                                    ),
                                    DataCell(Text(p['email'] ?? '')),
                                    DataCell(Text(p['phone'] ?? '')),
                                    DataCell(
                                      Chip(label: Text(p['kycStatus'] ?? '')),
                                    ),
                                    DataCell(
                                      Text(
                                        p['kycSubmittedAt']?.toString().split(
                                              'T',
                                            )[0] ??
                                            '',
                                      ),
                                    ),
                                    DataCell(
                                      TextButton(
                                        onPressed: () => _openReviewDialog(p),
                                        child: const Text('Review Docs'),
                                      ),
                                    ),
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
                            Text('Page $_appsPage of $_appsTotalPages'),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: _appsPage > 1
                                      ? () {
                                          setState(() => _appsPage--);
                                          _fetchApps();
                                        }
                                      : null,
                                  child: const Text('Previous'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: _appsPage < _appsTotalPages
                                      ? () {
                                          setState(() => _appsPage++);
                                          _fetchApps();
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
