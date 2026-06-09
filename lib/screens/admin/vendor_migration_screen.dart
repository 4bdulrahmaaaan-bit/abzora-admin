import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/state_views.dart';

class VendorMigrationScreen extends StatefulWidget {
  const VendorMigrationScreen({super.key});

  @override
  State<VendorMigrationScreen> createState() => _VendorMigrationScreenState();
}

class _VendorMigrationScreenState extends State<VendorMigrationScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isRunning = false;
  String? _resultMessage;

  Future<void> _runMigration() async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null || !actor.roles.containsKey('super_admin')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Super Admin access required.')),
      );
      return;
    }

    setState(() {
      _isRunning = true;
      _resultMessage = null;
    });

    try {
      await _db.runVendorMigration(actor: actor);
      if (!mounted) return;
      setState(() {
        _resultMessage = 'Migration completed successfully. Legacy records synchronized.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resultMessage = 'Migration failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Data Migration'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AbzioEmptyCard(
                title: 'Legacy Data Migration',
                subtitle:
                    'This tool scans all vendor records and synchronizes storeId, roles, and approval status to establish a single source of truth.',
              ),
              const SizedBox(height: 24),
              if (_isRunning)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: _runMigration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text('RUN MIGRATION', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              if (_resultMessage != null) ...[
                const SizedBox(height: 24),
                Text(
                  _resultMessage!,
                  style: TextStyle(
                    color: _resultMessage!.startsWith('Migration completed') ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
