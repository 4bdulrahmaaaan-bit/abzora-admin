import 'package:flutter/material.dart';

import '../../features/onboarding/rider_training_module_screen.dart';
import '../../features/profile/rider_profile_screen.dart';
import '../../features/settings/rider_help_support_screen.dart';
import '../../features/settings/rider_settings_screen.dart';

class RiderOperationsHubScreen extends StatelessWidget {
  const RiderOperationsHubScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: initialIndex,
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F5EF),
        appBar: AppBar(
          title: const Text('Operations Hub'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'Training'),
              Tab(text: 'Support'),
              Tab(text: 'Settings'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RiderProfileScreen(embedded: true),
            RiderTrainingModuleScreen(embeddedMode: true),
            RiderHelpSupportScreen(embeddedMode: true),
            RiderSettingsScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}
