import 'package:flutter/material.dart';

import '../../core/widgets/rider_glass_card.dart';

class RiderHelpSupportScreen extends StatelessWidget {
  const RiderHelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16),
        child: RiderGlassCard(
          child: ListTile(
            title: Text('Help & Support'),
            subtitle: Text('For urgent delivery issues contact support from dashboard help actions.'),
          ),
        ),
      ),
    );
  }
}
