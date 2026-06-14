import 'package:flutter/material.dart';

import '../../core/vendor/theme/vendor_theme.dart';
import 'vendor_reviews_center_screen.dart';
import 'vendor_returns_center_screen.dart';
import 'vendor_support_center_screen.dart';

class VendorCustomerCenterScreen extends StatelessWidget {
  const VendorCustomerCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: VendorTheme.background,
        appBar: AppBar(
          title: const Text('Customer Center'),
          bottom: const TabBar(
            isScrollable: false,
            labelColor: VendorTheme.primary,
            unselectedLabelColor: VendorTheme.grey400,
            indicatorColor: VendorTheme.primary,
            tabs: [
              Tab(text: 'Reviews'),
              Tab(text: 'Returns'),
              Tab(text: 'Support'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            VendorReviewsCenterScreen(),
            VendorReturnsCenterScreen(),
            VendorSupportCenterScreen(),
          ],
        ),
      ),
    );
  }
}
