import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme.dart';
import '../../../widgets/state_views.dart';
import 'widgets/admin_stat_card.dart';
import 'api/admin_trials_api.dart';

class AdminTrialsSection extends StatefulWidget {
  const AdminTrialsSection({super.key});

  @override
  State<AdminTrialsSection> createState() => _AdminTrialsSectionState();
}

class _AdminTrialsSectionState extends State<AdminTrialsSection> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminTrialsApi _api = AdminTrialsApi();
  
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _dashboardMetrics = {};
  List<Map<String, dynamic>> _queueData = [];
  Map<String, dynamic> _queueMeta = {};
  Map<String, dynamic> _analyticsData = {};

  int _currentPage = 1;
  int _currentLimit = 25; // ignore: prefer_final_fields
  String _searchQuery = '';
  String _statusFilter = '';
  String _outcomeFilter = ''; // ignore: prefer_final_fields
  String _paymentFilter = ''; // ignore: prefer_final_fields
  
  bool _showDrawer = false;
  String? _activeTrialId;
  Map<String, dynamic>? _activeTrialDetails;
  bool _loadingDetails = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        if (_tabController.index == 1 && _analyticsData.isEmpty) {
          _fetchAnalytics();
        }
      }
    });
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait([
        _fetchDashboard(),
        _fetchQueue(),
      ]);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchDashboard() async {
    try {
      final res = await _api.getDashboard();
      if (res['success'] == true) {
        setState(() => _dashboardMetrics = Map<String, dynamic>.from(res['data']));
      }
    } catch (e) {
      debugPrint('Error fetching trial dashboard: $e');
    }
  }

  Future<void> _fetchQueue() async {
    try {
      final res = await _api.getQueue(
        page: _currentPage,
        limit: _currentLimit,
        search: _searchQuery,
        status: _statusFilter,
        trialOutcome: _outcomeFilter,
        paymentStatus: _paymentFilter,
      );
      if (res['success'] == true) {
        setState(() {
          _queueData = List<Map<String, dynamic>>.from(res['data']);
          _queueMeta = Map<String, dynamic>.from(res['meta']);
        });
      }
    } catch (e) {
      debugPrint('Error fetching trial queue: $e');
    }
  }

  Future<void> _fetchAnalytics() async {
    try {
      final res = await _api.getAnalytics();
      if (res['success'] == true) {
        setState(() => _analyticsData = Map<String, dynamic>.from(res['data']));
      }
    } catch (e) {
      debugPrint('Error fetching trial analytics: $e');
    }
  }

  Future<void> _fetchTrialDetails(String id) async {
    setState(() {
      _activeTrialId = id;
      _showDrawer = true;
      _loadingDetails = true;
    });
    try {
      final res = await _api.getTrial(id);
      if (res['success'] == true) {
        setState(() {
          _activeTrialDetails = Map<String, dynamic>.from(res['data']);
        });
      }
    } catch (e) {
      debugPrint('Error fetching trial details: $e');
    } finally {
      setState(() => _loadingDetails = false);
    }
  }

  Future<void> _performAction(String action, String trialId) async {
    try {
      if (action == 'assign') {
        // Implement rider assignment modal logic here
        await _api.assignRider(trialId: trialId, riderId: 'mock_rider_id');
      } else if (action == 'reschedule') {
        await _api.reschedule(trialId: trialId, deliverySlot: 'Tomorrow');
      } else if (action == 'cancel') {
        await _api.cancelTrial(trialId: trialId, reason: 'Admin override');
      } else if (action == 'purchased') {
        await _api.markPurchased(trialId: trialId, keptItems: []);
      } else if (action == 'returned') {
        await _api.markReturned(trialId: trialId, returnedItems: []);
      }
      _fetchAll();
      if (_activeTrialId == trialId) {
        _fetchTrialDetails(trialId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    }
  }

  void _closeDrawer() {
    setState(() {
      _showDrawer = false;
      _activeTrialId = null;
      _activeTrialDetails = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trial Command Center',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        color: AbzioTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manage Try Before You Buy (TBYB) logistics, monitor conversions, and track returns.',
                      style: GoogleFonts.inter(
                        color: AbzioTheme.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Analytics'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_loading && _dashboardMetrics.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_error != null && _dashboardMetrics.isEmpty)
              Center(child: Text('Error: $_error'))
            else
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildAnalyticsTab(),
                  ],
                ),
              ),
          ],
        ),
        if (_showDrawer)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: _buildDetailsDrawer(),
          ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      children: [
        _buildDashboardGrid(),
        const SizedBox(height: 32),
        _buildQueueTable(),
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
          title: 'Active Trials',
          value: '${_dashboardMetrics['activeTrials'] ?? 0}',
          icon: Icons.dry_cleaning_outlined,
        ),
        AdminStatCard(
          title: 'Trials Today',
          value: '${_dashboardMetrics['trialsToday'] ?? 0}',
          icon: Icons.today_rounded,
        ),
        AdminStatCard(
          title: 'Completed',
          value: '${_dashboardMetrics['completedTrials'] ?? 0}',
          icon: Icons.check_circle_outline,
        ),
        AdminStatCard(
          title: 'Conversion Rate',
          value: '${_dashboardMetrics['conversionRate'] ?? 0}%',
          icon: Icons.percent_rounded,
        ),
        AdminStatCard(
          title: 'Return Rate',
          value: '${_dashboardMetrics['returnRate'] ?? 0}%',
          icon: Icons.assignment_return_outlined,
          trendUp: false,
        ),
        AdminStatCard(
          title: 'Avg. Duration',
          value: '${_dashboardMetrics['averageTrialDuration'] ?? 0} mins',
          icon: Icons.timer_outlined,
        ),
        AdminStatCard(
          title: 'Trial Revenue',
          value: '₹${_dashboardMetrics['trialRevenue'] ?? 0}',
          icon: Icons.account_balance_wallet_outlined,
        ),
        AdminStatCard(
          title: 'Pending Returns',
          value: '${_dashboardMetrics['pendingReturns'] ?? 0}',
          icon: Icons.assignment_late_outlined,
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
                Text(
                  'Trial Queue',
                  style: context.abzioText.titleLarge,
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 250,
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search Trials...',
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
                      value: _statusFilter.isEmpty ? 'All Status' : _statusFilter,
                      items: ['All Status', 'Scheduled', 'Assigned', 'Trial Active', 'Purchased', 'Returned', 'Cancelled', 'Closed']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
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
                title: 'No active trials',
                subtitle: 'There are no ongoing TBYB sessions matching your criteria.',
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Trial ID')),
                    DataColumn(label: Text('Customer')),
                    DataColumn(label: Text('Vendor')),
                    DataColumn(label: Text('Rider')),
                    DataColumn(label: Text('Fee')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Created')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: _queueData.map((trial) {
                    return DataRow(
                      cells: [
                        DataCell(Text(trial['id'].toString().substring(0, 8))),
                        DataCell(Text('${trial['customerName']}\n${trial['customerPhone']}')),
                        DataCell(Text(trial['vendorName']?.toString() ?? '')),
                        DataCell(Text(trial['riderName']?.toString() ?? 'Unassigned')),
                        DataCell(Text('₹${trial['trialFee']}')),
                        DataCell(Chip(label: Text(trial['status']?.toString() ?? ''))),
                        DataCell(Text((trial['createdAt']?.toString() ?? '').split('T').first)),
                        DataCell(
                          PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'view') {
                                _fetchTrialDetails(trial['id']);
                              } else {
                                _performAction(val, trial['id']);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'view', child: Text('View Details')),
                              PopupMenuItem(value: 'assign', child: Text('Assign Rider')),
                              PopupMenuItem(value: 'reschedule', child: Text('Reschedule')),
                              PopupMenuItem(value: 'cancel', child: Text('Cancel Trial')),
                              PopupMenuItem(value: 'purchased', child: Text('Mark Purchased')),
                              PopupMenuItem(value: 'returned', child: Text('Mark Returned')),
                            ],
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
                      onPressed: _currentPage > 1 ? () {
                        setState(() => _currentPage--);
                        _fetchQueue();
                      } : null,
                    ),
                    Text('Page $_currentPage of ${_queueMeta['totalPages'] ?? 1}'),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentPage < (_queueMeta['totalPages'] ?? 1) ? () {
                        setState(() => _currentPage++);
                        _fetchQueue();
                      } : null,
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
      width: 500,
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Trial Details', style: context.abzioText.titleLarge),
                IconButton(icon: const Icon(Icons.close), onPressed: _closeDrawer),
              ],
            ),
          ),
          Expanded(
            child: _loadingDetails
                ? const Center(child: CircularProgressIndicator())
                : _activeTrialDetails == null
                    ? const Center(child: Text('Failed to load details.'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildDetailRow('Trial ID', _activeTrialDetails!['id']),
                          _buildDetailRow('Status', _activeTrialDetails!['status']),
                          _buildDetailRow('Outcome', _activeTrialDetails!['trialOutcome'] ?? 'Pending'),
                          const Divider(),
                          Text('Customer', style: context.abzioText.titleMedium),
                          _buildDetailRow('Name', _activeTrialDetails!['customer']?['name']),
                          _buildDetailRow('Phone', _activeTrialDetails!['customer']?['phone']),
                          const Divider(),
                          Text('Vendor & Rider', style: context.abzioText.titleMedium),
                          _buildDetailRow('Vendor', _activeTrialDetails!['vendor']?['name']),
                          _buildDetailRow('Rider', _activeTrialDetails!['rider']?['name']),
                          const Divider(),
                          Text('Timeline', style: context.abzioText.titleMedium),
                          ...(_activeTrialDetails!['timeline'] as List? ?? []).map((t) {
                            return ListTile(
                              title: Text(t['type']?.toString().toUpperCase() ?? ''),
                              subtitle: Text(t['note'] ?? ''),
                              trailing: Text((t['createdAt']?.toString() ?? '').split('T').first),
                              contentPadding: EdgeInsets.zero,
                            );
                          }),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(value?.toString() ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    if (_analyticsData.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final funnel = _analyticsData['trialFunnel'] ?? {};
    
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trial Funnel', style: context.abzioText.titleLarge),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildFunnelStage('Scheduled', funnel['scheduled']),
                    const Icon(Icons.arrow_forward),
                    _buildFunnelStage('Started', funnel['started']),
                    const Icon(Icons.arrow_forward),
                    _buildFunnelStage('Completed', funnel['completed']),
                    const Icon(Icons.arrow_forward),
                    _buildFunnelStage('Purchased', funnel['purchased']),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Most Converted Products', style: context.abzioText.titleMedium),
                      const SizedBox(height: 8),
                      ...(_analyticsData['mostConvertedProducts'] as List? ?? []).map((item) {
                        return ListTile(
                          title: Text('Product ID: ${item['_id']}'),
                          trailing: Text('${item['count']} conversions'),
                          contentPadding: EdgeInsets.zero,
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Most Returned Products', style: context.abzioText.titleMedium),
                      const SizedBox(height: 8),
                      ...(_analyticsData['mostReturnedProducts'] as List? ?? []).map((item) {
                        return ListTile(
                          title: Text('Product ID: ${item['_id']}'),
                          trailing: Text('${item['count']} returns'),
                          contentPadding: EdgeInsets.zero,
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildFunnelStage(String label, dynamic value) {
    return Column(
      children: [
        Text(value?.toString() ?? '0', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
