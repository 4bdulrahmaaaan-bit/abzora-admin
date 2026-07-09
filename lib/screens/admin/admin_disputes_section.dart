import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_config.dart';
import '../../../models/models.dart';
import '../../../theme.dart';
import '../../../widgets/state_views.dart';
import 'api/admin_disputes_api.dart';

class AdminDisputesSection extends StatefulWidget {
  const AdminDisputesSection({super.key});

  @override
  State<AdminDisputesSection> createState() => _AdminDisputesSectionState();
}

class _AdminDisputesSectionState extends State<AdminDisputesSection> {
  bool _isLoading = true;
  String _error = '';
  List<AdminDispute> _disputes = [];
  Map<String, dynamic> _dashboardStats = {};

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  final int _limit = 25;

  String? _filterStatus;
  String? _filterPriority;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
    _fetchDisputes();
  }

  Future<void> _fetchDashboard() async {
    try {
      final res = await AdminDisputesApi.fetchDisputesDashboard();
      if (mounted) {
        setState(() {
          _dashboardStats = res;
        });
      }
    } catch (e) {
      debugPrint('Failed to load dispute dashboard: $e');
    }
  }

  Future<void> _fetchDisputes() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final res = await AdminDisputesApi.fetchDisputes(
        page: _currentPage,
        limit: _limit,
        status: _filterStatus,
        priority: _filterPriority,
      );
      if (mounted) {
        setState(() {
          _disputes = res['disputes'] as List<AdminDispute>;
          final meta = res['meta'] as Map;
          _totalPages = meta['totalPages'] ?? 1;
          _totalCount = meta['totalCount'] ?? 0;
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

  void _onSearch() {
    _currentPage = 1;
    _fetchDisputes();
  }

  void _openDetails(AdminDispute dispute) {
    showDialog(
      context: context,
      builder: (context) => _DisputeDetailsDialog(
        dispute: dispute,
        onDisputeUpdated: (updatedDispute) {
          _fetchDashboard();
          _fetchDisputes();
        },
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return Colors.red;
      case 'High':
        return Colors.orange;
      case 'Medium':
        return Colors.blue;
      case 'Low':
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dispute Resolution Center',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: 28,
            color: AbzioTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Centralized operational workflow for all platform disputes.',
          style: GoogleFonts.inter(
            color: AbzioTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _buildStatCard(
              'Open Disputes',
              _dashboardStats['openDisputes']?.toString() ?? '-',
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Escalated Cases',
              _dashboardStats['escalatedCases']?.toString() ?? '-',
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Resolved Today',
              _dashboardStats['resolvedToday']?.toString() ?? '-',
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Avg Resolution Time',
              _dashboardStats['avgResolutionTime']?.toString() ?? '-',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _filterStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('All Statuses'),
                      ),
                      DropdownMenuItem(value: 'Open', child: Text('Open')),
                      DropdownMenuItem(
                        value: 'Investigating',
                        child: Text('Investigating'),
                      ),
                      DropdownMenuItem(
                        value: 'Escalated',
                        child: Text('Escalated'),
                      ),
                      DropdownMenuItem(
                        value: 'Resolved',
                        child: Text('Resolved'),
                      ),
                      DropdownMenuItem(value: 'Closed', child: Text('Closed')),
                    ],
                    onChanged: (v) => setState(() => _filterStatus = v),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _filterPriority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('All Priorities'),
                      ),
                      DropdownMenuItem(value: 'Low', child: Text('Low')),
                      DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'High', child: Text('High')),
                      DropdownMenuItem(
                        value: 'Critical',
                        child: Text('Critical'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _filterPriority = v),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Filter'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
              ? Center(child: Text('Error: $_error'))
              : _disputes.isEmpty
              ? const AbzioEmptyCard(
                  title: 'No disputes found',
                  subtitle: 'Your queue is empty.',
                )
              : Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Showing ${_disputes.length} of $_totalCount disputes',
                          style: context.abzioText.titleMedium,
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              showCheckboxColumn: false,
                              columns: const [
                                DataColumn(label: Text('ID')),
                                DataColumn(label: Text('Type')),
                                DataColumn(label: Text('Priority')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Customer')),
                                DataColumn(label: Text('Vendor')),
                                if (AppConfig.enableLocalRiderDelivery)
                                  DataColumn(label: Text('Rider')),
                                DataColumn(label: Text('Created')),
                              ],
                              rows: _disputes.map((dispute) {
                                return DataRow(
                                  onSelectChanged: (_) => _openDetails(dispute),
                                  cells: [
                                    DataCell(Text(dispute.id)),
                                    DataCell(Text(dispute.type)),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getPriorityColor(
                                            dispute.priority,
                                          ).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          dispute.priority,
                                          style: TextStyle(
                                            color: _getPriorityColor(
                                              dispute.priority,
                                            ),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(dispute.status)),
                                    DataCell(
                                      Text(
                                        dispute.userId.isEmpty
                                            ? '-'
                                            : dispute.userId,
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        dispute.storeId.isEmpty
                                            ? '-'
                                            : dispute.storeId,
                                      ),
                                    ),
                                    if (AppConfig.enableLocalRiderDelivery)
                                      DataCell(
                                        Text(
                                          dispute.riderId.isEmpty
                                              ? '-'
                                              : dispute.riderId,
                                        ),
                                      ),
                                    DataCell(
                                      Text(
                                        dispute.createdAt.toString().split(
                                          ' ',
                                        )[0],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Page $_currentPage of $_totalPages'),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: _currentPage > 1
                                      ? () {
                                          setState(() => _currentPage--);
                                          _fetchDisputes();
                                        }
                                      : null,
                                  child: const Text('Previous'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: _currentPage < _totalPages
                                      ? () {
                                          setState(() => _currentPage++);
                                          _fetchDisputes();
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

  Widget _buildStatCard(String title, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: AbzioTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisputeDetailsDialog extends StatefulWidget {
  final AdminDispute dispute;
  final ValueChanged<AdminDispute> onDisputeUpdated;

  const _DisputeDetailsDialog({
    required this.dispute,
    required this.onDisputeUpdated,
  });

  @override
  State<_DisputeDetailsDialog> createState() => _DisputeDetailsDialogState();
}

class _DisputeDetailsDialogState extends State<_DisputeDetailsDialog> {
  late AdminDispute _dispute;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dispute = widget.dispute;
  }

  Future<void> _escalate() async {
    setState(() => _isSaving = true);
    try {
      final updated = await AdminDisputesApi.escalateDispute(_dispute.id);
      setState(() => _dispute = updated);
      widget.onDisputeUpdated(updated);
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _resolve() async {
    setState(() => _isSaving = true);
    try {
      final updated = await AdminDisputesApi.resolveDispute(
        _dispute.id,
        resolutionDetails: 'Resolved from UI',
      );
      setState(() => _dispute = updated);
      widget.onDisputeUpdated(updated);
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Dispute: ${_dispute.id}'),
      content: SizedBox(
        width: 800,
        height: 600,
        child: _isSaving
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(label: Text('Status: ${_dispute.status}')),
                        const SizedBox(width: 8),
                        Chip(label: Text('Priority: ${_dispute.priority}')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Type: ${_dispute.type}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Reason: ${_dispute.reason}'),
                    const SizedBox(height: 16),
                    const Text(
                      'Entities Involved:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Customer: ${_dispute.userId}'),
                    Text('Vendor: ${_dispute.storeId}'),
                    if (AppConfig.enableLocalRiderDelivery)
                      Text('Rider: ${_dispute.riderId}'),
                    Text('Order: ${_dispute.orderId}'),
                    const Divider(),
                    const Text(
                      'Timeline:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (_dispute.timeline.isEmpty)
                      const Text('No timeline events yet.'),
                    ..._dispute.timeline.map(
                      (t) => ListTile(
                        dense: true,
                        title: Text(t['action'] ?? ''),
                        subtitle: Text(t['note'] ?? ''),
                        trailing: Text(t['timestamp'] ?? ''),
                      ),
                    ),
                    const Divider(),
                    const Text(
                      'Resolution History:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (_dispute.resolutionHistory.isEmpty)
                      const Text('No resolution history.'),
                    ..._dispute.resolutionHistory.map(
                      (h) => ListTile(
                        dense: true,
                        title: Text(h['resolutionDetails'] ?? ''),
                        subtitle: Text('By: ${h['resolvedBy']}'),
                        trailing: Text(h['timestamp'] ?? ''),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        if (_dispute.status != 'Escalated' &&
            _dispute.status != 'Resolved' &&
            _dispute.status != 'Closed')
          TextButton(
            onPressed: _isSaving ? null : _escalate,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Escalate'),
          ),
        if (_dispute.status != 'Resolved' && _dispute.status != 'Closed')
          TextButton(
            onPressed: _isSaving ? null : _resolve,
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Resolve'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
