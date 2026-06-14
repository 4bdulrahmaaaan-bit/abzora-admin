import 'package:flutter/material.dart';

import '../../core/vendor/theme/vendor_theme.dart';
import 'product_management.dart';
import 'inventory_center_screen.dart';
import 'pricing_management_screen.dart';
import 'catalog_bulk_edit_tab.dart';

class VendorCatalogManagerScreen extends StatelessWidget {
  final String storeId;
  const VendorCatalogManagerScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: VendorTheme.background,
        appBar: AppBar(
          title: const Text('Catalog Manager'),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: VendorTheme.primary,
            unselectedLabelColor: VendorTheme.grey400,
            indicatorColor: VendorTheme.primary,
            tabs: [
              Tab(text: 'Products'),
              Tab(text: 'Inventory'),
              Tab(text: 'Pricing'),
              Tab(text: 'Bulk Edit'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Embedded existing screens as modules
            ProductManagementScreen(storeId: storeId),
            InventoryCenterScreen(storeId: storeId),
            PricingManagementScreen(storeId: storeId),
            CatalogBulkEditTab(storeId: storeId),
          ],
        ),
      ),
    );
  }
}
