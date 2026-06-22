import 'package:flutter/material.dart';

import '../../core/vendor/theme/vendor_theme.dart';
import 'vendor_reviews_center_screen.dart';
import 'vendor_returns_center_screen.dart';
import 'vendor_support_center_screen.dart';
import '../../widgets/lazy_indexed_tab_view.dart';

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
        body: LazyIndexedTabView(
          length: 3,
          itemBuilder: (context, index) {
            switch (index) {
              case 0:
                return const VendorReviewsCenterScreen();
              case 1:
                return const VendorReturnsCenterScreen();
              case 2:
                return const VendorSupportCenterScreen();
              default:
                return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }
}
