import 'package:flutter/material.dart';

import '../../core/vendor/theme/vendor_theme.dart';
import 'customer_insights_screen.dart';
import 'promotion_analytics_screen.dart';
import 'business_health_center_screen.dart';
import 'store_performance_score_screen.dart';
import 'analytics_product_tab.dart';
import '../../widgets/lazy_indexed_tab_view.dart';

class VendorAnalyticsHubScreen extends StatelessWidget {
  const VendorAnalyticsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: VendorTheme.background,
        appBar: AppBar(
          title: const Text('Analytics Hub'),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: VendorTheme.primary,
            unselectedLabelColor: VendorTheme.grey400,
            indicatorColor: VendorTheme.primary,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Customers'),
              Tab(text: 'Products'),
              Tab(text: 'Marketing'),
              Tab(text: 'Health'),
            ],
          ),
        ),
        body: LazyIndexedTabView(
          length: 5,
          itemBuilder: (context, index) {
            switch (index) {
              case 0:
                return const StorePerformanceScoreScreen();
              case 1:
                return const CustomerInsightsScreen();
              case 2:
                return const AnalyticsProductTab();
              case 3:
                return const PromotionAnalyticsScreen();
              case 4:
                return const BusinessHealthCenterScreen();
              default:
                return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }
}
