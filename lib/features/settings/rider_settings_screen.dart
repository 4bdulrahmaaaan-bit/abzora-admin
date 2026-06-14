import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/widgets/rider_glass_card.dart';
import '../legal/legal_document_registry.dart';
import '../legal/legal_policy_hub_screen.dart';
import '../../providers/auth_provider.dart';

class RiderSettingsScreen extends StatefulWidget {
  const RiderSettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<RiderSettingsScreen> createState() => _RiderSettingsScreenState();
}

class _RiderSettingsScreenState extends State<RiderSettingsScreen> {
  static const String _notifKey = 'rider_notifications_enabled';
  bool _notificationsEnabled = true;

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


  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF8D6A2E),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final content = <Widget>[
      _buildSectionHeader('ACCOUNT'),
      RiderGlassCard(
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Name'),
              subtitle: Text(user?.name ?? 'Not set'),
              trailing: const Icon(Icons.chevron_right, size: 20),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Email'),
              subtitle: Text(user?.email ?? 'Not set'),
              trailing: const Icon(Icons.chevron_right, size: 20),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Phone'),
              subtitle: Text(user?.phone ?? 'Not set'),
              trailing: const Icon(Icons.chevron_right, size: 20),
            ),
          ],
        ),
      ),

      _buildSectionHeader('NOTIFICATIONS'),
      RiderGlassCard(
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Delivery Alerts'),
              value: _notificationsEnabled,
              onChanged: _setNotifications,
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Earnings Alerts'),
              value: true,
              onChanged: (val) {},
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Promotions'),
              value: false,
              onChanged: (val) {},
            ),
          ],
        ),
      ),

      _buildSectionHeader('PRIVACY'),
      RiderGlassCard(
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Permissions'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {},
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data Controls'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {},
            ),
          ],
        ),
      ),

      _buildSectionHeader('APP'),
      RiderGlassCard(
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Theme'),
              trailing: const Text('System', style: TextStyle(color: Colors.grey)),
              onTap: () {},
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Language'),
              trailing: const Text('English', style: TextStyle(color: Colors.grey)),
              onTap: () {},
            ),
          ],
        ),
      ),

      _buildSectionHeader('SECURITY & LEGAL'),
      RiderGlassCard(
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Device Sessions'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {},
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Legal & Policies'),
              trailing: const Icon(Icons.chevron_right, size: 20),
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
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Logout'),
              trailing: const Icon(Icons.logout, size: 20, color: Colors.red),
              onTap: () async {
                await context.read<AuthProvider>().logout(resetNavigation: true);
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),
    ];

    if (widget.embedded) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ListView(children: content),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      backgroundColor: const Color(0xFFF8F5EF),
      body: ListView(padding: const EdgeInsets.all(16), children: content),
    );
  }
}
