import 'package:flutter/material.dart';

import 'admin_web_panel.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminWebPanel(initialSection: AdminWebSection.analytics);
  }
}
