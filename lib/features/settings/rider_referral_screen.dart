import 'package:flutter/material.dart';

import '../../core/widgets/rider_glass_card.dart';

class RiderReferralScreen extends StatelessWidget {
  const RiderReferralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16),
        child: RiderGlassCard(
          child: ListTile(
            title: Text('Referral Program'),
            subtitle: Text('Share code ABZRIDE and earn bonuses on verified rider joins.'),
          ),
        ),
      ),
    );
  }
}
