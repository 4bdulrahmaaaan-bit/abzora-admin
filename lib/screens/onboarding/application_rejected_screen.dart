import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class ApplicationRejectedScreen extends StatelessWidget {
  const ApplicationRejectedScreen({super.key});

  void _logout(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    if (context.mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final vendorOnboarding = user?.vendorOnboarding ?? {};
    final riderOnboarding = user?.riderOnboarding ?? {};

    final isVendorRejected = vendorOnboarding['status'] == 'rejected';
    final isRiderRejected = riderOnboarding['status'] == 'rejected';

    String reason =
        'Unfortunately, your application did not meet our requirements at this time.';
    if (isVendorRejected && vendorOnboarding['adminNotes'] != null) {
      reason = vendorOnboarding['adminNotes'];
    } else if (isRiderRejected && riderOnboarding['adminNotes'] != null) {
      reason = riderOnboarding['adminNotes'];
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel, size: 80, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                'Application Rejected',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                reason,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => _logout(context),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
