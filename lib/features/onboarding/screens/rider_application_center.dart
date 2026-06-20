import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as prov;
import '../../../providers/auth_provider.dart';
import '../../../core/widgets/rider_glow_button.dart';

class RiderApplicationCenter extends StatefulWidget {
  const RiderApplicationCenter({super.key});

  @override
  State<RiderApplicationCenter> createState() => _RiderApplicationCenterState();
}

class _RiderApplicationCenterState extends State<RiderApplicationCenter> {
  bool _isRefreshing = false;

  void _logout(BuildContext context) async {
    final auth = prov.Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    if (context.mounted) {
      context.go('/login');
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _isRefreshing = true);
    final authProvider = prov.Provider.of<AuthProvider>(context, listen: false);
    await authProvider.refreshCurrentUser();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = prov.Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final riderOnboarding = user?.riderOnboarding ?? {};
    final status = (riderOnboarding['status'] ?? 'pending').toString().toLowerCase();
    final adminNotes = riderOnboarding['adminNotes'];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Application Center',
          style: TextStyle(
            color: Color(0xFFD4AF37),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () => _logout(context),
            tooltip: 'Log out',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusIcon(status),
              const SizedBox(height: 32),
              Text(
                _getStatusHeading(status),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _getStatusMessage(status),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              if (adminNotes != null && adminNotes.toString().isNotEmpty) ...[
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Color(0xFFD4AF37),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Action Required',
                            style: TextStyle(
                              color: Color(0xFFF5E7C1),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        adminNotes.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: RiderGlowButton(
                  label: _isRefreshing ? 'Refreshing...' : 'Refresh Status',
                  onPressed: _isRefreshing ? null : _refreshStatus,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    Color iconColor;
    IconData iconData;
    Color bgColor;

    switch (status.toLowerCase()) {
      case 'approved':
        iconColor = Colors.greenAccent;
        iconData = Icons.check_circle_outline_rounded;
        bgColor = Colors.green.withValues(alpha: 0.1);
        break;
      case 'rejected':
        iconColor = Colors.redAccent;
        iconData = Icons.cancel_outlined;
        bgColor = Colors.red.withValues(alpha: 0.1);
        break;
      case 'training_pending':
        iconColor = Colors.blueAccent;
        iconData = Icons.school_outlined;
        bgColor = Colors.blue.withValues(alpha: 0.1);
        break;
      case 'submitted':
      case 'pending':
      default:
        iconColor = const Color(0xFFD4AF37);
        iconData = Icons.hourglass_empty_rounded;
        bgColor = const Color(0xFFD4AF37).withValues(alpha: 0.1);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Icon(iconData, size: 64, color: iconColor),
    );
  }

  String _getStatusHeading(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Application Approved!';
      case 'rejected':
        return 'Application Issue';
      case 'training_pending':
        return 'Training Required';
      case 'submitted':
      case 'pending':
      default:
        return 'Review in Progress';
    }
  }

  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Your application has been approved. You are ready to start receiving delivery requests.';
      case 'rejected':
        return 'There was an issue with your application. Please review the notes below and contact support.';
      case 'training_pending':
        return 'Your application is approved, but you must complete the required safety training before you can go online.';
      case 'submitted':
      case 'pending':
      default:
        return 'Our onboarding team is reviewing your documents and background check. This usually takes 24-48 hours.';
    }
  }
}
