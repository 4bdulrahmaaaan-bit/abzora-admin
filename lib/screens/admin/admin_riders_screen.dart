import 'package:flutter/material.dart';

import 'admin_web_panel.dart';

class AdminRidersScreen extends StatelessWidget {
  const AdminRidersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminWebPanel(initialSection: AdminWebSection.riders);
  }
}
