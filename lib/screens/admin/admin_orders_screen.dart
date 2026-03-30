import 'package:flutter/material.dart';

import 'admin_web_panel.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminWebPanel(initialSection: AdminWebSection.orders);
  }
}
