import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class VendorOnboardingStatusScreen extends StatefulWidget {
  const VendorOnboardingStatusScreen({super.key});

  @override
  State<VendorOnboardingStatusScreen> createState() => _VendorOnboardingStatusScreenState();
}

class _VendorOnboardingStatusScreenState extends State<VendorOnboardingStatusScreen> {
  bool _isRefreshing = false;

  void _logout(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    if (context.mounted) {
      context.go('/login');
    }
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.refreshCurrentUser();
    if (mounted) setState(() => _isRefreshing = false);
  }

  int _calculateCurrentStage(String status) {
    switch (status.toLowerCase()) {
      case 'rejected':
        return -1;
      case 'pending':
      case 'submitted':
        return 2; // Assume Document Verification is next
      case 'reviewing':
        return 3;
      case 'onboarding':
        return 4;
      case 'approved':
        return 5;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final vendorOnboarding = user?.vendorOnboarding ?? {};
    final status = vendorOnboarding['status']?.toString().toLowerCase() ?? 'pending';
    final adminNotes = vendorOnboarding['adminNotes']?.toString();
    
    final currentStage = _calculateCurrentStage(status);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('Application Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: Colors.black,
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (status == 'rejected')
                _buildRejectedBanner(adminNotes)
              else ...[
                const Text(
                  'Track your progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We are reviewing your profile. Once approved, you can start selling on Abzora.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                _buildTimeline(currentStage),
              ],
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isRefreshing ? null : _refresh,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isRefreshing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : const Text(
                          'Refresh Status',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedBanner(String? notes) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
              SizedBox(width: 12),
              Text(
                'Application Rejected',
                style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Unfortunately, your application was not approved at this time. Please review the feedback below:',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                notes,
                style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildTimeline(int currentStage) {
    final stages = [
      {'title': 'Application Submitted', 'subtitle': 'Your details are securely received.'},
      {'title': 'Document Verification', 'subtitle': 'AI & Manual KYC checks.'},
      {'title': 'Portfolio Review', 'subtitle': 'Quality check of your craft.'},
      {'title': 'Store Onboarding', 'subtitle': 'Creating your digital storefront.'},
      {'title': 'Final Approval', 'subtitle': 'Ready to go live.'},
    ];

    return Column(
      children: List.generate(stages.length, (index) {
        final step = index + 1;
        final isCompleted = step < currentStage;
        final isActive = step == currentStage;
        final isLast = index == stages.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? Colors.green
                        : isActive
                            ? Colors.white
                            : Colors.white12,
                    border: Border.all(
                      color: isActive ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check : isActive ? Icons.hourglass_bottom : Icons.circle,
                    color: isCompleted
                        ? Colors.white
                        : isActive
                            ? Colors.black
                            : Colors.transparent,
                    size: 18,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 48,
                    color: isCompleted ? Colors.green : Colors.white12,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stages[index]['title']!,
                      style: TextStyle(
                        color: isCompleted || isActive ? Colors.white : Colors.white38,
                        fontSize: 16,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stages[index]['subtitle']!,
                      style: TextStyle(
                        color: isCompleted || isActive ? Colors.white70 : Colors.white24,
                        fontSize: 13,
                      ),
                    ),
                    if (!isLast) const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
