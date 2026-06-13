import 'package:flutter/material.dart';
import 'api/admin_automation_api.dart';
import 'package:intl/intl.dart';

class AdminAutomationSection extends StatefulWidget {
  const AdminAutomationSection({super.key});

  @override
  State<AdminAutomationSection> createState() => _AdminAutomationSectionState();
}

class _AdminAutomationSectionState extends State<AdminAutomationSection> {
  List<AdminAutomationModel> _automations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted)
      setState(() {
        _isLoading = true;
        _error = null;
      });
    try {
      final data = await AdminAutomationApi.getAutomations();
      if (mounted) {
        setState(() {
          _automations = data;
          _isLoading = false;
          _error = null;
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

  Future<void> _toggleAutomation(
    AdminAutomationModel automation,
    bool enabled,
  ) async {
    try {
      final updated = await AdminAutomationApi.toggleAutomation(
        automation.id,
        enabled,
      );
      setState(() {
        final index = _automations.indexWhere((a) => a.id == automation.id);
        if (index != -1) {
          _automations[index] = updated;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Automation ${enabled ? 'enabled' : 'disabled'}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  void _showScheduleDialog(AdminAutomationModel automation) {
    final controller = TextEditingController(text: automation.cronExpression);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Schedule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter a valid CRON expression:'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '* * * * *',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Format: min hour dom month dow',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newCron = controller.text.trim();
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                try {
                  final updated = await AdminAutomationApi.updateSchedule(
                    automation.id,
                    newCron,
                  );
                  setState(() {
                    final index = _automations.indexWhere(
                      (a) => a.id == automation.id,
                    );
                    if (index != -1) _automations[index] = updated;
                  });
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Schedule updated')),
                  );
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Failed to update schedule: $e')),
                  );
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  void _showHistoryDialog(AdminAutomationModel automation) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${automation.name} History'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: automation.executionHistory.isEmpty
                ? const Center(child: Text('No execution history.'))
                : ListView.builder(
                    itemCount: automation.executionHistory.length,
                    itemBuilder: (context, index) {
                      final h = automation.executionHistory.reversed
                          .toList()[index];
                      return ListTile(
                        leading: Icon(
                          h.status == 'success'
                              ? Icons.check_circle
                              : Icons.error,
                          color: h.status == 'success'
                              ? Colors.green
                              : Colors.red,
                        ),
                        title: Text(h.details),
                        subtitle: Text(
                          DateFormat(
                            'yyyy-MM-dd HH:mm:ss',
                          ).format(h.executedAt.toLocal()),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            ElevatedButton(onPressed: _loadData, child: const Text('RETRY')),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operational Automation Engine'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Background Workflows',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _automations.length,
              itemBuilder: (context, index) {
                final automation = _automations[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    automation.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    automation.description,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: automation.enabled,
                              onChanged: (val) =>
                                  _toggleAutomation(automation, val),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Schedule (CRON)',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      automation.cronExpression,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 16),
                                      onPressed: () =>
                                          _showScheduleDialog(automation),
                                      tooltip: 'Edit Schedule',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Last Run',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  automation.lastRunAt != null
                                      ? DateFormat('MMM dd, HH:mm').format(
                                          automation.lastRunAt!.toLocal(),
                                        )
                                      : 'Never',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Success Rate',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${automation.successCount} / ${automation.successCount + automation.failureCount}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: automation.failureCount > 0
                                        ? Colors.orange
                                        : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showHistoryDialog(automation),
                              icon: const Icon(Icons.history, size: 18),
                              label: const Text('History'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
