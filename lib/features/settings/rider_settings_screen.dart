import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/rider_glass_card.dart';
import '../../providers/auth_provider.dart';

class RiderSettingsScreen extends StatelessWidget {
  const RiderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const RiderGlassCard(
          child: ListTile(
            title: Text('Notifications'),
            trailing: Icon(Icons.chevron_right),
          ),
        ),
        const SizedBox(height: 12),
        const RiderGlassCard(
          child: ListTile(
            title: Text('Help & Support'),
            subtitle: Text('Chat / Email / Call support'),
          ),
        ),
        const SizedBox(height: 12),
        const RiderGlassCard(
          child: ListTile(
            title: Text('Referral Program'),
            subtitle: Text('Invite riders and earn bonuses'),
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
      ],
    );
  }
}
