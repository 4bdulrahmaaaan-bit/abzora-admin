import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

import '../../../theme.dart';
import 'api/admin_inventory_api.dart';

class AdminInventorySection extends StatefulWidget {
  const AdminInventorySection({super.key});

  @override
  State<AdminInventorySection> createState() => _AdminInventorySectionState();
}

class _AdminInventorySectionState extends State<AdminInventorySection> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoadingDashboard = true;
  String _dashboardError = '';
  Map<String, dynamic> _kpis = {};
  List<Map<String, dynamic>> _alerts = [];

  bool _isLoadingProducts = false;
  List<Map<String, dynamic>> _products = [];
  int _productsPage = 1;
  int _productsTotalPages = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchDashboard();
    _fetchProducts();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      if (_tabController.index == 0) {
        _fetchDashboard();
      } else if (_tabController.index == 1) {
        _fetchProducts();
      }
    }
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _isLoadingDashboard = true;
      _dashboardError = '';
    });
    try {
      final res = await AdminInventoryApi.fetchDashboard();
      if (mounted) {
        setState(() {
          _kpis = res['kpis'] ?? {};
          _alerts = (res['alerts'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  Future<void> _fetchProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final res = await AdminInventoryApi.fetchProducts(page: _productsPage, limit: 50);
      if (mounted) {
        setState(() {
          _products = res['products'] as List<Map<String, dynamic>>;
          _productsTotalPages = res['meta']['totalPages'] ?? 1;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  void _openAdjustDialog(Map<String, dynamic> product) {
    final availableCtrl = TextEditingController(text: product['inventory']?['available']?.toString() ?? '0');
    final reservedCtrl = TextEditingController(text: product['inventory']?['reserved']?.toString() ?? '0');
    final trialReservedCtrl = TextEditingController(text: product['inventory']?['trialReserved']?.toString() ?? '0');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Adjust Inventory for ${product['sku'] ?? 'Unknown'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: availableCtrl, decoration: const InputDecoration(labelText: 'Available Stock'), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              TextField(controller: reservedCtrl, decoration: const InputDecoration(labelText: 'Reserved Stock'), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              TextField(controller: trialReservedCtrl, decoration: const InputDecoration(labelText: 'Trial Reserved'), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                try {
                  await AdminInventoryApi.adjustInventory(product['_id'], {
                    'available': int.tryParse(availableCtrl.text) ?? 0,
                    'reserved': int.tryParse(reservedCtrl.text) ?? 0,
                    'trialReserved': int.tryParse(trialReservedCtrl.text) ?? 0,
                  });
                  if (mounted) {
                    navigator.pop();
                  }
                  _fetchProducts();
                  _fetchDashboard();
                } catch (e) {
                  if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportCSV() async {
    String csv = 'ID,Name,SKU,Vendor,Price,Available,Reserved,Trial Reserved,Status\n';
    for (final row in _products) {
      final inv = row['inventory'] ?? {};
      final data = [
        row['_id'], row['name'], row['sku'], row['vendorId'], row['price'],
        inv['available'] ?? 0, inv['reserved'] ?? 0, inv['trialReserved'] ?? 0, row['status']
      ];
      final line = data.map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',');
      csv += '$line\n';
    }

    final bytes = utf8.encode(csv);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Inventory_Products.csv');
      await file.writeAsBytes(bytes);
      if (mounted) {
        await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], text: 'Exported Inventory_Products.csv');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save file: $e')),
        );
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
                  'Inventory Command Center',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: AbzioTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Centralized intelligence and stock monitoring platform.',
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
            Tab(text: 'Dashboard & Alerts'),
            Tab(text: 'Product Inventory'),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDashboardTab(),
              _buildProductsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardTab() {
    if (_isLoadingDashboard) return const Center(child: CircularProgressIndicator());
    if (_dashboardError.isNotEmpty) return Center(child: Text('Error: $_dashboardError'));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildMetricCard('Total Inventory', '${_kpis['totalInventory'] ?? 0}', Colors.blue.shade50),
              const SizedBox(width: 16),
              _buildMetricCard('Available', '${_kpis['availableInventory'] ?? 0}', Colors.green.shade50),
              const SizedBox(width: 16),
              _buildMetricCard('Reserved', '${_kpis['reservedInventory'] ?? 0}', Colors.orange.shade50),
              const SizedBox(width: 16),
              _buildMetricCard('Trial Reserved', '${_kpis['trialReservedInventory'] ?? 0}', Colors.purple.shade50),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetricCard('Low Stock Products', '${_kpis['lowStockProducts'] ?? 0}', Colors.amber.shade50),
              const SizedBox(width: 16),
              _buildMetricCard('Out Of Stock', '${_kpis['outOfStockProducts'] ?? 0}', Colors.red.shade50),
              const SizedBox(width: 16),
              _buildMetricCard('Dead Stock', '${_kpis['deadStockProducts'] ?? 0}', Colors.grey.shade200),
              const SizedBox(width: 16),
              _buildMetricCard('Inventory Value', '₹${_kpis['inventoryValue'] ?? 0}', Colors.teal.shade50),
            ],
          ),
          const SizedBox(height: 32),
          Text('Inventory Alerts', style: context.abzioText.titleMedium),
          const SizedBox(height: 16),
          if (_alerts.isEmpty) const Text('No active inventory alerts.') else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _alerts.length,
            itemBuilder: (context, index) {
              final alert = _alerts[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    Icons.warning,
                    color: alert['severity'] == 'Critical' ? Colors.red : Colors.orange,
                  ),
                  title: Text(alert['type'] ?? 'Alert', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(alert['message'] ?? ''),
                  trailing: Text(alert['createdAt']?.toString().split('T')[0] ?? ''),
                ),
              );
            },
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
            Text(title, style: GoogleFonts.inter(color: Colors.black54, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsTab() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: _exportCSV,
              icon: const Icon(Icons.download),
              label: const Text('Export CSV'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoadingProducts
              ? const Center(child: CircularProgressIndicator())
              : _products.isEmpty
                  ? const Center(child: Text('No products found.'))
                  : Card(
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('SKU')),
                                    DataColumn(label: Text('Name')),
                                    DataColumn(label: Text('Vendor')),
                                    DataColumn(label: Text('Available')),
                                    DataColumn(label: Text('Reserved')),
                                    DataColumn(label: Text('Trial Rsvd')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: _products.map((p) {
                                    final inv = p['inventory'] ?? {};
                                    return DataRow(cells: [
                                      DataCell(Text(p['sku'] ?? 'N/A')),
                                      DataCell(Text(p['name'] ?? '')),
                                      DataCell(Text(p['vendorId'] ?? '')),
                                      DataCell(Text('${inv['available'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(Text('${inv['reserved'] ?? 0}')),
                                      DataCell(Text('${inv['trialReserved'] ?? 0}')),
                                      DataCell(Chip(label: Text(p['status'] ?? ''))),
                                      DataCell(
                                        TextButton(
                                          onPressed: () => _openAdjustDialog(p),
                                          child: const Text('Adjust'),
                                        ),
                                      ),
                                    ]);
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
                                Text('Page $_productsPage of $_productsTotalPages'),
                                Row(
                                  children: [
                                    OutlinedButton(
                                      onPressed: _productsPage > 1
                                          ? () {
                                              setState(() => _productsPage--);
                                              _fetchProducts();
                                            }
                                          : null,
                                      child: const Text('Previous'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: _productsPage < _productsTotalPages
                                          ? () {
                                              setState(() => _productsPage++);
                                              _fetchProducts();
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
