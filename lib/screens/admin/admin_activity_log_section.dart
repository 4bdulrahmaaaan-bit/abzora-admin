import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/models.dart';
import '../../../theme.dart';
import '../../../widgets/state_views.dart';
import 'api/admin_activity_log_api.dart';

class AdminActivityLogSection extends StatefulWidget {
  const AdminActivityLogSection({super.key});

  @override
  State<AdminActivityLogSection> createState() => _AdminActivityLogSectionState();
}

class _AdminActivityLogSectionState extends State<AdminActivityLogSection> {
  bool _isLoading = true;
  String _error = '';
  List<ActivityLogEntry> _logs = [];

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  final int _limit = 25;

  final TextEditingController _actorController = TextEditingController();
  final TextEditingController _targetTypeController = TextEditingController();
  final TextEditingController _actionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final res = await AdminActivityLogApi.fetchActivityLogs(
        page: _currentPage,
        limit: _limit,
        actorId: _actorController.text.trim(),
        targetType: _targetTypeController.text.trim(),
        action: _actionController.text.trim(),
      );
      setState(() {
        _logs = res['logs'] as List<ActivityLogEntry>;
        final meta = res['meta'] as Map;
        _totalPages = meta['totalPages'] ?? 1;
        _totalCount = meta['totalCount'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearch() {
    _currentPage = 1;
    _fetchLogs();
  }

  void _showStateDiff(BuildContext context, ActivityLogEntry log) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Audit Details: ${log.action}'),
          content: SizedBox(
            width: 800,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Actor: ${log.actorId} (${log.actorRole})'),
                  Text('Target: ${log.targetType} [${log.targetId}]'),
                  Text('Timestamp: ${log.timestamp}'),
                  Text('Message: ${log.message}'),
                  const Divider(),
                  if (log.previousState != null) ...[
                    const Text('Previous State:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey.shade100,
                      child: Text(
                        const JsonEncoder.withIndent('  ').convert(log.previousState),
                        style: GoogleFonts.firaCode(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (log.newState != null) ...[
                    const Text('New State:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey.shade100,
                      child: Text(
                        const JsonEncoder.withIndent('  ').convert(log.newState),
                        style: GoogleFonts.firaCode(fontSize: 12),
                      ),
                    ),
                  ],
                  if (log.previousState == null && log.newState == null)
                    const Text('No state difference recorded for this action.'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
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
        Text(
          'Admin Activity Log',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: 28,
            color: AbzioTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Complete audit trail of all administrative and system mutations.',
          style: GoogleFonts.inter(
            color: AbzioTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _actorController,
                    decoration: const InputDecoration(
                      labelText: 'Actor ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _targetTypeController,
                    decoration: const InputDecoration(
                      labelText: 'Entity Type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _actionController,
                    decoration: const InputDecoration(
                      labelText: 'Action Type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Filter'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                  : _logs.isEmpty
                      ? const AbzioEmptyCard(
                          title: 'No activity logs found',
                          subtitle: 'Adjust your filters or check back later.',
                        )
                      : Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Showing ${_logs.length} of $_totalCount logs',
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
                                        DataColumn(label: Text('Timestamp')),
                                        DataColumn(label: Text('Action')),
                                        DataColumn(label: Text('Actor')),
                                        DataColumn(label: Text('Entity')),
                                        DataColumn(label: Text('Message')),
                                      ],
                                      rows: _logs.map((log) {
                                        return DataRow(
                                          onSelectChanged: (_) => _showStateDiff(context, log),
                                          cells: [
                                            DataCell(Text(log.timestamp.toString().split('.')[0])),
                                            DataCell(Text(log.action.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                            DataCell(Text(log.actorId)),
                                            DataCell(Text('${log.targetType}\n[${log.targetId}]')),
                                            DataCell(
                                              SizedBox(
                                                width: 300,
                                                child: Text(
                                                  log.message,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
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
                                                  _fetchLogs();
                                                }
                                              : null,
                                          child: const Text('Previous'),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton(
                                          onPressed: _currentPage < _totalPages
                                              ? () {
                                                  setState(() => _currentPage++);
                                                  _fetchLogs();
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
