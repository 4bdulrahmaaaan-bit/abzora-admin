import 'package:flutter/material.dart';

import 'admin_web_panel.dart';

class AdminVendorsScreen extends StatelessWidget {
  const AdminVendorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminWebPanel(initialSection: AdminWebSection.vendors);
  }
}
