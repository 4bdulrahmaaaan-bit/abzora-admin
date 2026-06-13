import 'package:flutter/material.dart';
import 'dart:async';
import 'api/admin_backup_api.dart';
import 'package:intl/intl.dart';

class AdminBackupSection extends StatefulWidget {
  const AdminBackupSection({super.key});

  @override
  State<AdminBackupSection> createState() => _AdminBackupSectionState();
}

class _AdminBackupSectionState extends State<AdminBackupSection> {
  List<AdminBackupModel> _backups = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final data = await AdminBackupApi.getBackups();
      if (mounted) {
        setState(() {
          _backups = data;
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

  Future<void> _triggerBackup() async {
    try {
      await AdminBackupApi.triggerBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Backup triggered successfully. It will run in the background.',
            ),
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to trigger backup: $e')));
      }
    }
  }

  Future<void> _restoreBackup(AdminBackupModel backup) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restore Backup'),
          content: const Text(
            'WARNING: Restoring a backup will overwrite the current database. This action cannot be undone from the UI.\n\nAre you sure you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await AdminBackupApi.restoreBackup();
                } catch (e) {
                  if (mounted) {
                    showDialog(
                      context: this.context,
                      builder: (c) => AlertDialog(
                        title: const Text('Operation Denied'),
                        content: Text(e.toString()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
              child: const Text('RESTORE'),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'failed':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _backups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _backups.isEmpty) {
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
        title: const Text('Backup & Recovery Center'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'System Snapshots',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _triggerBackup,
                  icon: const Icon(Icons.backup),
                  label: const Text('CREATE SNAPSHOT NOW'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _backups.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final backup = _backups[index];
                  final statusColor = _getStatusColor(backup.status);
                  return ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withValues(alpha: 0.1),
                      child: Icon(
                        backup.status == 'completed'
                            ? Icons.check_circle
                            : (backup.status == 'in_progress'
                                  ? Icons.sync
                                  : Icons.error),
                        color: statusColor,
                      ),
                    ),
                    title: Text(
                      backup.backupId,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Triggered By: ${backup.triggeredBy} • Type: ${backup.type.toUpperCase()}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat(
                            'MMM dd, yyyy HH:mm:ss',
                          ).format(backup.createdAt.toLocal()),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        if (backup.errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              backup.errorMessage,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (backup.status == 'completed')
                          Text(
                            '${backup.fileSizeMb} MB',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        const SizedBox(width: 16),
                        if (backup.status == 'completed')
                          OutlinedButton.icon(
                            onPressed: () => _restoreBackup(backup),
                            icon: const Icon(Icons.restore, size: 18),
                            label: const Text('RESTORE'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        if (backup.status == 'in_progress')
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
