import 'package:flutter/material.dart';

import '../../core/vendor/theme/vendor_theme.dart';
import 'customer_insights_screen.dart';
import 'promotion_analytics_screen.dart';
import 'business_health_center_screen.dart';
import 'store_performance_score_screen.dart';
import 'analytics_product_tab.dart';

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
        body: const TabBarView(
          children: [
            // Overview Tab
            StorePerformanceScoreScreen(),
            // Customers Tab
            CustomerInsightsScreen(),
            // Products Tab
            AnalyticsProductTab(),
            // Marketing Tab
            PromotionAnalyticsScreen(),
            // Health Tab
            BusinessHealthCenterScreen(),
          ],
        ),
      ),
    );
  }
}
