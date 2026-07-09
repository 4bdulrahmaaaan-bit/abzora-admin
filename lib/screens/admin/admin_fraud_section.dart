import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme.dart';
import '../../services/app_config.dart';
import '../../../widgets/state_views.dart';
import 'widgets/admin_stat_card.dart';
import 'api/admin_fraud_api.dart';

class AdminFraudSection extends StatefulWidget {
  const AdminFraudSection({super.key});

  @override
  State<AdminFraudSection> createState() => _AdminFraudSectionState();
}

class _AdminFraudSectionState extends State<AdminFraudSection> {
  final AdminFraudApi _api = AdminFraudApi();

  bool _loading = true;
  String? _error;

  Map<String, dynamic> _dashboard = {};

  String _activeTab =
      'highestRisk'; // highestRisk, customers, vendors, riders, orders
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

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
        setState(() => _dashboard = Map<String, dynamic>.from(res['data']));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _performAction(String type, String id, String action) async {
    try {
      final res = await _api.actionEntity(
        type: type.toLowerCase(),
        id: id,
        action: action,
        reason: 'Admin Dashboard Action',
      );
      if (res['success'] == true && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Action successful.')));
        _fetchDashboard();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fraud & Risk Engine',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: 28,
            color: AbzioTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Analytical overview of system risk. Actions are manual-only during pilot phase.',
          style: GoogleFonts.inter(
            color: AbzioTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        if (_loading && _dashboard.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (_error != null && _dashboard.isEmpty)
          Center(child: Text('Error: $_error'))
        else
          Expanded(
            child: ListView(
              children: [
                _buildDashboardGrid(),
                const SizedBox(height: 32),
                _buildRiskTable(),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDashboardGrid() {
    return GridView.count(
      crossAxisCount: AppConfig.enableLocalRiderDelivery ? 5 : 4,
      shrinkWrap: true,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.0,
      children: [
        AdminStatCard(
          title: 'Highest Risk',
          value: '${(_dashboard['highestRisk'] as List?)?.length ?? 0}',
          icon: Icons.priority_high,
          trendUp: false,
        ),
        AdminStatCard(
          title: 'Flagged Customers',
          value: '${_dashboard['flaggedCustomers'] ?? 0}',
          icon: Icons.person_off,
          trendUp: false,
        ),
        AdminStatCard(
          title: 'Flagged Vendors',
          value: '${_dashboard['flaggedVendors'] ?? 0}',
          icon: Icons.store_mall_directory,
          trendUp: false,
        ),
        if (AppConfig.enableLocalRiderDelivery)
          AdminStatCard(
            title: 'Flagged Riders',
            value: '${_dashboard['flaggedRiders'] ?? 0}',
            icon: Icons.delivery_dining,
            trendUp: false,
          ),
        AdminStatCard(
          title: 'Flagged Orders',
          value: '${_dashboard['flaggedOrders'] ?? 0}',
          icon: Icons.receipt_long,
          trendUp: false,
        ),
      ],
    );
  }

  Widget _buildRiskTable() {
    List<dynamic> data = _dashboard[_activeTab] ?? [];

    if (_searchQuery.isNotEmpty) {
      data = data
          .where(
            (v) =>
                (v['name']?.toString().toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false) ||
                (v['id']?.toString().toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false) ||
                (v['uid']?.toString().toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false),
          )
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
                Row(
                  children: [
                    _buildTabBtn('Highest Risk', 'highestRisk'),
                    _buildTabBtn('Customers', 'customers'),
                    _buildTabBtn('Vendors', 'vendors'),
                    if (AppConfig.enableLocalRiderDelivery)
                      _buildTabBtn('Riders', 'riders'),
                    _buildTabBtn('Orders', 'orders'),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 250,
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search ID or Name...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
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
            if (data.isEmpty)
              const AbzioEmptyCard(
                title: 'No entities found',
                subtitle:
                    'There are no flagged entities matching your criteria.',
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Entity ID')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Risk Score')),
                    DataColumn(label: Text('Fraud Flags')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: data.map((entity) {
                    final rClass = entity['classification'] ?? 'N/A';
                    final rColor = rClass == 'Critical'
                        ? Colors.red
                        : rClass == 'Warning'
                        ? Colors.orange
                        : Colors.green;
                    final type =
                        entity['type'] ??
                        _activeTab.replaceAll(
                          's',
                          '',
                        ); // fallback simple un-plural

                    return DataRow(
                      cells: [
                        DataCell(
                          Chip(label: Text(type.toString().toUpperCase())),
                        ),
                        DataCell(
                          Text(
                            entity['uid']?.toString().substring(0, 8) ??
                                entity['id'].toString().substring(0, 8),
                          ),
                        ),
                        DataCell(Text(entity['name'] ?? 'N/A')),
                        DataCell(
                          Row(
                            children: [
                              Icon(Icons.warning, size: 16, color: rColor),
                              const SizedBox(width: 6),
                              Text('${entity['riskScore'] ?? 0}'),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            (entity['flags'] as List?)?.join(', ') ?? 'None',
                          ),
                        ),
                        DataCell(
                          PopupMenuButton<String>(
                            onSelected: (val) =>
                                _performAction(type, entity['id'], val),
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'review',
                                child: Text('Mark for Review'),
                              ),
                              PopupMenuItem(
                                value: 'suspend',
                                child: Text('Suspend'),
                              ),
                              PopupMenuItem(
                                value: 'block',
                                child: Text(
                                  'Block',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'whitelist',
                                child: Text(
                                  'Whitelist',
                                  style: TextStyle(color: Colors.green),
                                ),
                              ),
                            ],
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

  Widget _buildTabBtn(String label, String value) {
    final active = _activeTab == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: active,
        onSelected: (b) => setState(() {
          _activeTab = value;
          _searchQuery = '';
          _searchController.clear();
        }),
      ),
    );
  }
}
