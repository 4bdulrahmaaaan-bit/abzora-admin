import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/state_views.dart';

import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_metric_card.dart';
import '../../core/vendor/widgets/vendor_status_badge.dart';
import '../../core/vendor/widgets/vendor_empty_state.dart';

import 'add_product_screen.dart';

class InventoryCenterScreen extends StatefulWidget {
  const InventoryCenterScreen({super.key, required this.storeId});
  final String storeId;

  @override
  State<InventoryCenterScreen> createState() => _InventoryCenterScreenState();
}

class _InventoryCenterScreenState extends State<InventoryCenterScreen> {
  final _db = DatabaseService();
  bool _loading = true;
  List<Product> _products = [];
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    final products = await _db.getProductsByStore(widget.storeId, includeInactive: true);
    if (!mounted) return;
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  List<Product> get _filteredProducts {
    return _products.where((p) {
      if (_filter == 'All') return true;
      if (_filter == 'Low Stock') return p.stock > 0 && p.stock <= 5;
      if (_filter == 'Out of Stock') return p.stock <= 0;
      if (_filter == 'Healthy') return p.stock > 5;
      return true;
    }).toList()..sort((a, b) => a.stock.compareTo(b.stock));
  }

  int _calculateHealthScore() {
    if (_products.isEmpty) return 0;
    int healthy = _products.where((p) => p.stock > 5).length;
    return ((healthy / _products.length) * 100).toInt();
  }

  Future<void> _restockProduct(Product p) async {
    // Navigate to AddProductScreen to edit stock, or use a dialog
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(storeId: widget.storeId, existingProduct: p),
      ),
    );
    await _loadInventory();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: VendorTheme.background,
        body: AbzioLoadingView(title: 'Loading Inventory', subtitle: 'Analyzing stock levels...'),
      );
    }

    final lowStock = _products.where((p) => p.stock > 0 && p.stock <= 5).length;
    final outOfStock = _products.where((p) => p.stock <= 0).length;
    final totalStock = _products.fold<int>(0, (sum, p) => sum + p.stock);

    return Scaffold(
      backgroundColor: VendorTheme.background,
      appBar: AppBar(
        title: const Text('Inventory Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInventory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: VendorTheme.primary,
        onRefresh: _loadInventory,
        child: ListView(
          padding: const EdgeInsets.all(VendorTheme.spacing16),
          children: [
            _buildInventoryHealth(lowStock, outOfStock, totalStock),
            const SizedBox(height: VendorTheme.spacing24),
            _buildFilters(),
            const SizedBox(height: VendorTheme.spacing24),
            if (_filteredProducts.isEmpty)
              const VendorEmptyState(
                title: 'No inventory to show',
                subtitle: 'Adjust your filters or add products to your catalog.',
                icon: Icons.inventory_2_outlined,
              )
            else
              ..._filteredProducts.map(_buildInventoryItem),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryHealth(int lowStock, int outOfStock, int totalStock) {
    final score = _calculateHealthScore();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumVendorCard(
          backgroundColor: VendorTheme.primary,
          padding: const EdgeInsets.all(VendorTheme.spacing24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inventory Health Score', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white70)),
                    const SizedBox(height: VendorTheme.spacing8),
                    Text('$score / 100', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: VendorTheme.spacing8),
                    Text(
                      score >= 80 ? 'Excellent Stock Management' : score >= 50 ? 'Needs Attention' : 'Critical Action Required',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.analytics_outlined, size: 64, color: Colors.white24),
            ],
          ),
        ),
        const SizedBox(height: VendorTheme.spacing16),
        Row(
          children: [
            Expanded(child: VendorMetricCard(title: 'Total Units', value: '$totalStock', icon: Icons.inventory_2_outlined)),
            const SizedBox(width: VendorTheme.spacing12),
            Expanded(child: VendorMetricCard(title: 'Low Stock', value: '$lowStock', icon: Icons.warning_amber_rounded)),
            const SizedBox(width: VendorTheme.spacing12),
            Expanded(child: VendorMetricCard(title: 'Out of Stock', value: '$outOfStock', icon: Icons.error_outline)),
          ],
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['All', 'Low Stock', 'Out of Stock', 'Healthy'].map((f) {
          final isSelected = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: VendorTheme.spacing8),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (_) => setState(() => _filter = f),
              selectedColor: VendorTheme.primary,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInventoryItem(Product p) {
    VendorBadgeType badgeType = VendorBadgeType.neutral;
    String badgeLabel = 'Healthy';

    if (p.stock <= 0) {
      badgeType = VendorBadgeType.error;
      badgeLabel = 'Out of Stock';
    } else if (p.stock <= 5) {
      badgeType = VendorBadgeType.warning;
      badgeLabel = 'Low Stock';
    } else if (p.purchaseCount > 20) {
      badgeType = VendorBadgeType.info;
      badgeLabel = 'Fast Moving';
    }

    return PremiumVendorCard(
      margin: const EdgeInsets.only(bottom: VendorTheme.spacing16),
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
            child: SizedBox(
              width: 64,
              height: 64,
              child: AbzioNetworkImage(
                imageUrl: p.images.isNotEmpty ? p.images.first : 'https://via.placeholder.com/150',
                fallbackLabel: p.name,
              ),
            ),
          ),
          const SizedBox(width: VendorTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: VendorTheme.spacing4),
                Text('SKU: ${p.id.substring(0, 8)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VendorTheme.grey500)),
                const SizedBox(height: VendorTheme.spacing8),
                Row(
                  children: [
                    VendorStatusBadge(label: badgeLabel, type: badgeType),
                    const SizedBox(width: VendorTheme.spacing8),
                    Text('${p.stock} in stock', style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _restockProduct(p),
            icon: const Icon(Icons.add_shopping_cart, size: 18),
            label: const Text('Restock'),
            style: OutlinedButton.styleFrom(
              foregroundColor: VendorTheme.primary,
              side: const BorderSide(color: VendorTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
