import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/widgets/rider_glass_card.dart';
import '../legal/account_deletion_request_screen.dart';
import '../legal/legal_consent_screen.dart';
import '../legal/legal_document_registry.dart';
import '../legal/legal_policy_hub_screen.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/payout_account_dialog.dart';

class RiderSettingsScreen extends StatefulWidget {
  const RiderSettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<RiderSettingsScreen> createState() => _RiderSettingsScreenState();
}

class _RiderSettingsScreenState extends State<RiderSettingsScreen> {
  static const String _notifKey = 'rider_notifications_enabled';
  bool _notificationsEnabled = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool(_notifKey) ?? true;
    });
  }

  Future<void> _setNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifKey, value);
    if (!mounted) return;
    setState(() => _notificationsEnabled = value);
  }

  Future<void> _managePayout() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final db = DatabaseService();
      final profile = await db.getRiderPayoutProfile(actor: user);
      if (!mounted) return;
      final formValue = await showPayoutAccountDialog(
        context: context,
        title: 'Rider payout account',
        initialValue: profile,
      );
      if (formValue == null) return;
      await db.saveRiderPayoutProfile(
        actor: user,
        methodType: formValue.methodType,
        accountHolderName: formValue.accountHolderName,
        upiId: formValue.upiId,
        bankAccountNumber: formValue.bankAccountNumber,
        bankIfsc: formValue.bankIfsc,
        bankName: formValue.bankName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payout account updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF101010),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help & Support',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text('Email: rider-support@abianzo.com'),
            SizedBox(height: 4),
            Text('Phone: +91 90000 00000'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final content = <Widget>[
      if (_loading) const LinearProgressIndicator(color: Color(0xFFD4AF37)),
      RiderGlassCard(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Notifications'),
          subtitle: const Text('Delivery updates, payout and alerts'),
          value: _notificationsEnabled,
          onChanged: _setNotifications,
        ),
      ),
      const SizedBox(height: 12),
      RiderGlassCard(
        child: ListTile(
          title: const Text('Payout Account'),
          subtitle: const Text('Manage bank/UPI for withdrawals'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _loading ? null : _managePayout,
        ),
      ),
      const SizedBox(height: 12),
      RiderGlassCard(
        child: ListTile(
          title: const Text('Help & Support'),
          subtitle: const Text('Chat / Email / Call support'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showHelp,
        ),
      ),
      const SizedBox(height: 12),
      RiderGlassCard(
        child: ListTile(
          title: const Text('Referral Program'),
          subtitle: Text(
            'Your code: RIDER-${(user?.id ?? '0000').substring(0, (user?.id.length ?? 4) >= 4 ? 4 : (user?.id.length ?? 0))}',
          ),
        ),
      ),
      const SizedBox(height: 12),
      RiderGlassCard(
        child: ListTile(
          title: const Text('Legal & Policies'),
          subtitle: const Text(
            'Terms, privacy, agreements, delivery and refund policies',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const LegalPolicyHubScreen(
                audience: LegalAudience.rider,
                title: 'Rider Legal Center',
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      RiderGlassCard(
        child: ListTile(
          title: const Text('Legal Consent'),
          subtitle: const Text('Review and accept Terms and Privacy'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const LegalConsentScreen(audience: LegalAudience.rider),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      RiderGlassCard(
        child: ListTile(
          title: const Text('Request Account Deletion'),
          subtitle: const Text('Send deletion request to support'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const AccountDeletionRequestScreen(roleLabel: 'Rider'),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      RiderGlassCard(
        child: ListTile(
          title: const Text('Logout'),
          trailing: const Icon(Icons.logout),
          onTap: () async {
            await context.read<AuthProvider>().logout(resetNavigation: true);
          },
        ),
      ),
    ];

    if (widget.embedded) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(children: content),
      );
    }

    return ListView(padding: const EdgeInsets.all(16), children: content);
  }
}
