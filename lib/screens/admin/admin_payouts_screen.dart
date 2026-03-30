import 'package:flutter/material.dart';

import 'admin_web_panel.dart';

class AdminPayoutsScreen extends StatelessWidget {
  const AdminPayoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminWebPanel(initialSection: AdminWebSection.payouts);
  }
}
