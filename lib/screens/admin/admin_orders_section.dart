import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme.dart';
import '../../../widgets/state_views.dart';
import 'widgets/admin_stat_card.dart';
import 'api/admin_orders_api.dart';

class AdminOrdersSection extends StatefulWidget {
  const AdminOrdersSection({super.key});

  @override
  State<AdminOrdersSection> createState() => _AdminOrdersSectionState();
}

class _AdminOrdersSectionState extends State<AdminOrdersSection> {
  final AdminOrdersApi _api = AdminOrdersApi();

  bool _loading = true;
  String? _error;

  Map<String, dynamic> _dashboardMetrics = {};
  List<Map<String, dynamic>> _queueData = [];
  Map<String, dynamic> _queueMeta = {};

  int _currentPage = 1;
  final int _currentLimit = 25;
  String _searchQuery = '';
  String _statusFilter = '';
  String _healthFilter = '';

  bool _showDrawer = false;
  Map<String, dynamic>? _activeOrderDetails;
  bool _loadingDetails = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    Object? caughtError;
    try {
      await Future.wait([_fetchDashboard(), _fetchQueue()]);
    } catch (e) {
      caughtError = e;
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          if (caughtError != null) _error = caughtError.toString();
        });
      }
    }
  }

  Future<void> _fetchDashboard() async {
    try {
      final res = await _api.getDashboard();
      if (res['success'] == true && mounted) {
        setState(
          () => _dashboardMetrics = Map<String, dynamic>.from(res['data']),
        );
      }
    } catch (e) {
      debugPrint('Error fetching order dashboard: $e');
    }
  }

  Future<void> _fetchQueue() async {
    try {
      final res = await _api.getQueue(
        page: _currentPage,
        limit: _currentLimit,
        search: _searchQuery,
        status: _statusFilter,
        health: _healthFilter,
      );
      if (res['success'] == true && mounted) {
        setState(() {
          _queueData = List<Map<String, dynamic>>.from(res['data']);
          _queueMeta = Map<String, dynamic>.from(res['meta']);
        });
      }
    } catch (e) {
      debugPrint('Error fetching order queue: $e');
    }
  }

  Future<void> _fetchOrderDetails(String id) async {
    setState(() {
      _showDrawer = true;
      _loadingDetails = true;
    });
    try {
      final res = await _api.getOrder(id);
      if (res['success'] == true && mounted) {
        setState(() {
          _activeOrderDetails = Map<String, dynamic>.from(res['data']);
        });
      }
    } catch (e) {
      debugPrint('Error fetching order details: $e');
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  void _closeDrawer() {
    setState(() {
      _showDrawer = false;
      _activeOrderDetails = null;
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
              'Order Management V2',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                fontSize: 28,
                color: AbzioTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Track live SLAs, order health, and vendor/rider performance.',
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
                    _buildQueueTable(),
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
          title: 'Total Today',
          value: '${_dashboardMetrics['totalOrdersToday'] ?? 0}',
          icon: Icons.receipt_long,
        ),
        AdminStatCard(
          title: 'Pending',
          value: '${_dashboardMetrics['pendingOrders'] ?? 0}',
          icon: Icons.hourglass_empty,
        ),
        AdminStatCard(
          title: 'Avg Health Score',
          value: '${_dashboardMetrics['averageHealthScore'] ?? 0}',
          icon: Icons.health_and_safety,
          trendUp: (_dashboardMetrics['averageHealthScore'] ?? 0) >= 80,
        ),
        AdminStatCard(
          title: 'Critical SLAs',
          value: '${_dashboardMetrics['criticalSlaCount'] ?? 0}',
          icon: Icons.warning_amber_rounded,
          trendUp: false,
        ),
        AdminStatCard(
          title: 'Warning SLAs',
          value: '${_dashboardMetrics['warningSlaCount'] ?? 0}',
          icon: Icons.error_outline,
          trendUp: false,
        ),
        AdminStatCard(
          title: 'Escalated',
          value: '${_dashboardMetrics['escalatedOrders'] ?? 0}',
          icon: Icons.priority_high,
          trendUp: false,
        ),
        AdminStatCard(
          title: 'Refund Requests',
          value: '${_dashboardMetrics['refundRequests'] ?? 0}',
          icon: Icons.money_off,
          trendUp: false,
        ),
        AdminStatCard(
          title: 'Refund Rate',
          value: '${_dashboardMetrics['refundRate'] ?? 0}%',
          icon: Icons.percent,
          trendUp: false,
        ),
      ],
    );
  }

  Widget _buildQueueTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AbzioTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Live Orders', style: context.abzioText.titleLarge),
                Row(
                  children: [
                    SizedBox(
                      width: 250,
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search ID, Name, Phone...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onSubmitted: (val) {
                          setState(() {
                            _searchQuery = val;
                            _currentPage = 1;
                          });
                          _fetchQueue();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _statusFilter.isEmpty
                          ? 'All Status'
                          : _statusFilter,
                      items:
                          [
                                'All Status',
                                'pending',
                                'created',
                                'confirmed',
                                'processing',
                                'shipped',
                                'delivered',
                                'cancelled',
                              ]
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                      onChanged: (val) {
                        setState(() {
                          _statusFilter = val == 'All Status' ? '' : val!;
                          _currentPage = 1;
                        });
                        _fetchQueue();
                      },
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
                        setState(() {
                          _healthFilter = val == 'All Health' ? '' : val!;
                          _currentPage = 1;
                        });
                        _fetchQueue();
                      },
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _fetchQueue,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading && _queueData.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_queueData.isEmpty)
              const AbzioEmptyCard(
                title: 'No orders found',
                subtitle: 'There are no active orders matching your filters.',
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Order ID')),
                    DataColumn(label: Text('Health')),
                    DataColumn(label: Text('Store')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Created')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: _queueData.map((order) {
                    final healthClass = order['healthClassification'] ?? 'N/A';
                    final healthColor = healthClass == 'Healthy'
                        ? Colors.green
                        : healthClass == 'Warning'
                        ? Colors.orange
                        : Colors.red;
                    return DataRow(
                      cells: [
                        DataCell(Text(order['_id'].toString().substring(0, 8))),
                        DataCell(
                          Row(
                            children: [
                              Icon(Icons.circle, color: healthColor, size: 12),
                              const SizedBox(width: 6),
                              Text('${order['healthScore'] ?? 0}'),
                            ],
                          ),
                        ),
                        DataCell(Text(order['storeId']?['name'] ?? 'N/A')),
                        DataCell(
                          Chip(
                            label: Text(
                              order['orderStatus']?.toString().toUpperCase() ??
                                  '',
                            ),
                          ),
                        ),
                        DataCell(Text('₹${order['totalAmount']}')),
                        DataCell(
                          Text(
                            (order['createdAt']?.toString() ?? '')
                                .split('T')
                                .first,
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => _fetchOrderDetails(order['_id']),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total: ${_queueMeta['totalCount'] ?? 0}'),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentPage > 1
                          ? () {
                              setState(() => _currentPage--);
                              _fetchQueue();
                            }
                          : null,
                    ),
                    Text(
                      'Page $_currentPage of ${_queueMeta['totalPages'] ?? 1}',
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentPage < (_queueMeta['totalPages'] ?? 1)
                          ? () {
                              setState(() => _currentPage++);
                              _fetchQueue();
                            }
                          : null,
                    ),
                  ],
                ),
              ],
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
                Text('Order Details', style: context.abzioText.titleLarge),
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
                : _activeOrderDetails == null
                ? const Center(child: Text('Failed to load details.'))
                : DefaultTabController(
                    length: 5,
                    child: Column(
                      children: [
                        const TabBar(
                          isScrollable: true,
                          tabs: [
                            Tab(text: 'Timeline & SLA'),
                            Tab(text: 'Customer'),
                            Tab(text: 'Vendor'),
                            Tab(text: 'Rider'),
                            Tab(text: 'Financials'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildTimelineTab(),
                              _buildProfileTab(
                                'customerProfile',
                                'Customer Details',
                              ),
                              _buildProfileTab('storeId', 'Store Details'),
                              _buildProfileTab('riderProfile', 'Rider Details'),
                              _buildFinancialsTab(),
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

  Widget _buildTimelineTab() {
    final order = _activeOrderDetails!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSlaCard(
          'Vendor SLA',
          order['vendorSlaStatus'],
          order['vendorSlaMinutes'],
        ),
        const SizedBox(height: 12),
        _buildSlaCard(
          'Rider SLA',
          order['riderSlaStatus'],
          order['riderSlaMinutes'],
        ),
        const SizedBox(height: 12),
        _buildSlaCard(
          'Delivery SLA',
          order['deliverySlaStatus'],
          order['deliverySlaMinutes'],
        ),
        const Divider(height: 32),
        Text('Action Workflow', style: context.abzioText.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.warning_amber),
              label: const Text('Escalate Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                foregroundColor: Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Contact Customer'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSlaCard(String title, String? status, dynamic minutes) {
    Color c = Colors.grey;
    if (status == 'Healthy') c = Colors.green;
    if (status == 'Warning') c = Colors.orange;
    if (status == 'Critical') c = Colors.red;

    return Card(
      child: ListTile(
        leading: Icon(Icons.access_time, color: c),
        title: Text(title),
        subtitle: Text(
          status == 'N/A'
              ? 'Not started'
              : '${(minutes ?? 0).toStringAsFixed(1)} minutes taken',
        ),
        trailing: Chip(
          label: Text(status ?? 'N/A'),
          backgroundColor: c.withValues(alpha: 0.1),
          labelStyle: TextStyle(color: c),
        ),
      ),
    );
  }

  Widget _buildProfileTab(String key, String title) {
    final profile = _activeOrderDetails![key];
    if (profile == null) return Center(child: Text('No $title available.'));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: context.abzioText.titleMedium),
        const SizedBox(height: 16),
        _buildDetailRow('Name', profile['name'] ?? profile['ownerId'] ?? 'N/A'),
        if (profile['phone'] != null)
          _buildDetailRow('Phone', profile['phone']),
        if (profile['email'] != null)
          _buildDetailRow('Email', profile['email']),
      ],
    );
  }

  Widget _buildFinancialsTab() {
    final order = _activeOrderDetails!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Payment History', style: context.abzioText.titleMedium),
        _buildDetailRow('Payment Status', order['paymentStatus']),
        _buildDetailRow('Payment Method', order['paymentMethod']),
        _buildDetailRow('Escrow Status', order['escrowStatus']),
        const Divider(height: 32),
        Text('Refund History', style: context.abzioText.titleMedium),
        _buildDetailRow('Refund Status', order['refundStatus']),
        _buildDetailRow('Refund ID', order['refundRequestId'] ?? 'None'),
        const Divider(height: 32),
        Text('Trial History', style: context.abzioText.titleMedium),
        _buildDetailRow('Is Trial', order['isTrialOrder']?.toString()),
        _buildDetailRow(
          'Outcome',
          order['trialOutcome']?.isEmpty ?? true
              ? 'Pending'
              : order['trialOutcome'],
        ),
      ],
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
