import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme.dart';
import '../../../widgets/state_views.dart';
import 'widgets/admin_stat_card.dart';
import 'api/admin_vendors_api.dart';

class AdminVendorsSection extends StatefulWidget {
  const AdminVendorsSection({super.key});

  @override
  State<AdminVendorsSection> createState() => _AdminVendorsSectionState();
}

class _AdminVendorsSectionState extends State<AdminVendorsSection> {
  final AdminVendorsApi _api = AdminVendorsApi();

  bool _loading = true;
  String? _error;

  Map<String, dynamic> _dashboardMetrics = {};

  bool _showDrawer = false;
  Map<String, dynamic>? _activeVendorDetails;
  bool _loadingDetails = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _healthFilter = '';

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getDashboard();
      if (res['success'] == true && mounted) {
        setState(
          () => _dashboardMetrics = Map<String, dynamic>.from(res['data']),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchVendorDetails(String id) async {
    setState(() {
      _showDrawer = true;
      _loadingDetails = true;
    });
    try {
      final res = await Future.wait([
        _api.getVendor(id),
        _api.getPayouts(id),
        _api.getComplaints(id),
      ]);

      if (res[0]['success'] == true && mounted) {
        setState(() {
          _activeVendorDetails = Map<String, dynamic>.from(res[0]['data']);
          _activeVendorDetails!['payouts'] = res[1]['data'];
          _activeVendorDetails!['complaints'] = res[2]['data'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching vendor details: $e');
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  void _closeDrawer() {
    setState(() {
      _showDrawer = false;
      _activeVendorDetails = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vendor Intelligence V2',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                fontSize: 28,
                color: AbzioTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Live monitoring of vendor health scores, risk levels, and revenue performance.',
              style: GoogleFonts.inter(
                color: AbzioTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (_loading && _dashboardMetrics.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_error != null && _dashboardMetrics.isEmpty)
              Center(child: Text('Error: $_error'))
            else
              Expanded(
                child: ListView(
                  children: [
                    _buildDashboardGrid(),
                    const SizedBox(height: 32),
                    _buildVendorTable(),
                  ],
                ),
              ),
          ],
        ),
        if (_showDrawer)
          Positioned(top: 0, right: 0, bottom: 0, child: _buildDetailsDrawer()),
      ],
    );
  }

  Widget _buildDashboardGrid() {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      children: [
        AdminStatCard(
          title: 'Total Vendors',
          value: '${_dashboardMetrics['totalVendors'] ?? 0}',
          icon: Icons.storefront,
        ),
        AdminStatCard(
          title: 'Avg Health Score',
          value: '${_dashboardMetrics['avgHealthScore'] ?? 0}',
          icon: Icons.monitor_heart,
          trendUp: (_dashboardMetrics['avgHealthScore'] ?? 0) >= 80,
        ),
        AdminStatCard(
          title: 'Critical Risk',
          value: '${_dashboardMetrics['criticalVendors'] ?? 0}',
          icon: Icons.warning_amber_rounded,
          trendUp: false,
        ),
        AdminStatCard(
          title: 'Warning Risk',
          value: '${_dashboardMetrics['warningVendors'] ?? 0}',
          icon: Icons.error_outline,
          trendUp: false,
        ),
      ],
    );
  }

  Widget _buildVendorTable() {
    List<dynamic> vendors = _dashboardMetrics['vendors'] ?? [];

    if (_searchQuery.isNotEmpty) {
      vendors = vendors
          .where(
            (v) =>
                (v['name']?.toString().toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false) ||
                (v['_id']?.toString().toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false),
          )
          .toList();
    }

    if (_healthFilter.isNotEmpty) {
      vendors = vendors
          .where((v) => v['healthClassification'] == _healthFilter)
          .toList();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AbzioTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Vendor Index', style: context.abzioText.titleLarge),
                Row(
                  children: [
                    SizedBox(
                      width: 250,
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search Name or ID...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _healthFilter.isEmpty
                          ? 'All Health'
                          : _healthFilter,
                      items: ['All Health', 'Healthy', 'Warning', 'Critical']
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(
                          () => _healthFilter = val == 'All Health' ? '' : val!,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _fetchDashboard,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (vendors.isEmpty)
              const AbzioEmptyCard(
                title: 'No vendors found',
                subtitle: 'There are no vendors matching your filters.',
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Vendor ID')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Health Score')),
                    DataColumn(label: Text('Risk Score')),
                    DataColumn(label: Text('Total Rev')),
                    DataColumn(label: Text('Trials')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: vendors.map((v) {
                    final hClass = v['healthClassification'] ?? 'N/A';
                    final rClass = v['riskClassification'] ?? 'N/A';
                    return DataRow(
                      cells: [
                        DataCell(Text(v['_id'].toString().substring(0, 8))),
                        DataCell(Text(v['name'] ?? 'N/A')),
                        DataCell(
                          Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 12,
                                color: hClass == 'Healthy'
                                    ? Colors.green
                                    : hClass == 'Warning'
                                    ? Colors.orange
                                    : Colors.red,
                              ),
                              const SizedBox(width: 6),
                              Text('${v['healthScore'] ?? 0}'),
                            ],
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              Icon(
                                Icons.warning,
                                size: 16,
                                color: rClass == 'Critical'
                                    ? Colors.red
                                    : rClass == 'Warning'
                                    ? Colors.orange
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text('${v['riskScore'] ?? 0}'),
                            ],
                          ),
                        ),
                        DataCell(
                          Text('₹${v['analytics']?['totalRevenue'] ?? 0}'),
                        ),
                        DataCell(
                          Text('${v['analytics']?['totalTrials'] ?? 0}'),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => _fetchVendorDetails(v['_id']),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsDrawer() {
    return Container(
      width: 600,
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Vendor Profile', style: context.abzioText.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _closeDrawer,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loadingDetails
                ? const Center(child: CircularProgressIndicator())
                : _activeVendorDetails == null
                ? const Center(child: Text('Failed to load details.'))
                : DefaultTabController(
                    length: 4,
                    child: Column(
                      children: [
                        const TabBar(
                          isScrollable: true,
                          tabs: [
                            Tab(text: 'Health & Risk'),
                            Tab(text: 'Analytics'),
                            Tab(text: 'Payouts'),
                            Tab(text: 'Complaints'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildHealthRiskTab(),
                              _buildAnalyticsTab(),
                              _buildPayoutsTab(),
                              _buildComplaintsTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRiskTab() {
    final v = _activeVendorDetails!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildScoreCard(
          'Health Score',
          v['healthScore'],
          v['healthClassification'],
        ),
        const SizedBox(height: 12),
        _buildScoreCard('Risk Score', v['riskScore'], v['riskClassification']),
        const Divider(height: 32),
        Text('Fraud Flags', style: context.abzioText.titleMedium),
        const SizedBox(height: 12),
        if ((v['fraudFlags'] as List?)?.isEmpty ?? true)
          const Text(
            'No fraud flags detected.',
            style: TextStyle(color: Colors.green),
          )
        else
          ...(v['fraudFlags'] as List).map(
            (f) => ListTile(
              leading: const Icon(Icons.flag, color: Colors.red),
              title: Text(f),
            ),
          ),
      ],
    );
  }

  Widget _buildScoreCard(String title, dynamic score, String classification) {
    Color c = Colors.grey;
    if (classification == 'Healthy') c = Colors.green;
    if (classification == 'Warning') c = Colors.orange;
    if (classification == 'Critical') c = Colors.red;

    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Chip(
          label: Text('$score - $classification'),
          backgroundColor: c.withValues(alpha: 0.1),
          labelStyle: TextStyle(color: c),
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final a = _activeVendorDetails!['analytics'] ?? {};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDetailRow('Total Revenue', '₹${a['totalRevenue'] ?? 0}'),
        _buildDetailRow('Total Orders', a['totalOrders']),
        const Divider(),
        _buildDetailRow('Cancellation Rate', a['cancellationRate']),
        _buildDetailRow('Complaint Rate', a['complaintRate']),
        const Divider(),
        _buildDetailRow('Total Trials', a['totalTrials']),
        _buildDetailRow('Trial Conversion Rate', a['trialConversionRate']),
      ],
    );
  }

  Widget _buildPayoutsTab() {
    final payouts = _activeVendorDetails!['payouts'] as List? ?? [];
    if (payouts.isEmpty) {
      return const Center(child: Text('No payouts recorded.'));
    }

    return ListView.builder(
      itemCount: payouts.length,
      itemBuilder: (context, i) {
        final p = payouts[i];
        return ListTile(
          title: Text('Amount: ₹${p['vendorEarnings'] ?? 0}'),
          subtitle: Text('ID: ${p['payoutId'] ?? 'N/A'}'),
          trailing: Chip(label: Text(p['payoutStatus'] ?? 'none')),
        );
      },
    );
  }

  Widget _buildComplaintsTab() {
    final complaints = _activeVendorDetails!['complaints'] as List? ?? [];
    if (complaints.isEmpty) {
      return const Center(
        child: Text(
          'No complaints recorded.',
          style: TextStyle(color: Colors.green),
        ),
      );
    }

    return ListView.builder(
      itemCount: complaints.length,
      itemBuilder: (context, i) {
        final c = complaints[i];
        return ListTile(
          leading: const Icon(Icons.warning, color: Colors.orange),
          title: Text('Order: ${c['_id'].toString().substring(0, 8)}'),
          subtitle: Text(
            'Refund: ${c['refundStatus']} | Qty Rating: ${c['customerQualityRating'] ?? 'N/A'}',
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text(value?.toString() ?? 'N/A'),
        ],
      ),
    );
  }
}
