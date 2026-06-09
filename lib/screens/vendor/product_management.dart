import 'package:flutter/material.dart';


import '../../models/models.dart';

import '../../services/database_service.dart';
import '../../widgets/state_views.dart';

// V2 Design System Imports
import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_metric_card.dart';
import '../../core/vendor/widgets/vendor_status_badge.dart';
import '../../core/vendor/widgets/vendor_empty_state.dart';
import '../../core/vendor/widgets/vendor_buttons.dart';

import 'add_product_screen.dart';
import 'pricing_management_screen.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key, required this.storeId});
  final String storeId;

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  static const int _pageSize = 8;
  final _db = DatabaseService();
  final _searchController = TextEditingController();
  
  List<Product> _products = [];
  bool _loading = true;
  String _statusFilter = 'All';
  String _categoryFilter = 'All';
  int _page = 0;
  Set<String> _selectedProducts = {};

  List<Product> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();
    return _products.where((product) {
      final matchesStatus = _statusFilter == 'All' ||
          (_statusFilter == 'Active' && product.status == ProductStatus.active) ||
          (_statusFilter == 'Draft' && product.status == ProductStatus.draft) ||
          (_statusFilter == 'Hidden' && product.status != ProductStatus.active) ||
          (_statusFilter == 'Out of Stock' && product.stock <= 0);
      final matchesCategory = _categoryFilter == 'All' || product.category == _categoryFilter;
      final haystack = '${product.name} ${product.brand} ${product.category}'.toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesStatus && matchesCategory && matchesQuery;
    }).toList()..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
  }

  List<Product> get _visibleProducts {
    final start = _page * _pageSize;
    final filtered = _filteredProducts;
    if (start >= filtered.length) return const [];
    return filtered.sublist(start, (start + _pageSize).clamp(0, filtered.length));
  }

  int get _pageCount => _filteredProducts.isEmpty ? 1 : (_filteredProducts.length / _pageSize).ceil();

  List<String> get _categories {
    final values = _products.map((p) => p.category).where((c) => c.trim().isNotEmpty).toSet().toList()..sort();
    return ['All', ...values];
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    setState(() => _page = 0);
  }

  Future<void> _loadProducts() async {
    final products = await _db.getProductsByStore(widget.storeId, includeInactive: true);
    if (!mounted) return;
    setState(() {
      _products = products;
      _loading = false;
      _page = 0;
      _selectedProducts.clear();
    });
  }

  Future<void> _openProductEditor({Product? product}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(storeId: widget.storeId, existingProduct: product),
      ),
    );
    await _loadProducts();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedProducts.contains(id)) {
        _selectedProducts.remove(id);
      } else {
        _selectedProducts.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedProducts.length == _filteredProducts.length) {
        _selectedProducts.clear();
      } else {
        _selectedProducts = _filteredProducts.map((p) => p.id).toSet();
      }
    });
  }

  int _calculateQualityScore(Product p) {
    int score = 40; // Base score
    if (p.images.length > 2) {
      score += 20;
    } else if (p.images.isNotEmpty) {
      score += 10;
    }
    if (p.description.length > 50) score += 15;
    if (p.brand.isNotEmpty) score += 10;
    if (p.specifications.isNotEmpty) score += 15;
    return score.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _products.where((p) => p.status == ProductStatus.active).length;
    final outOfStockCount = _products.where((p) => p.stock <= 0).length;
    final draftCount = _products.where((p) => p.status == ProductStatus.draft).length;

    return Scaffold(
      backgroundColor: VendorTheme.background,
      appBar: AppBar(
        title: const Text('Catalog Pro'),
        actions: [
          if (_selectedProducts.isNotEmpty)
            TextButton.icon(
              onPressed: () {}, // Bulk operations hook
              icon: const Icon(Icons.flash_on),
              label: Text('Bulk Actions (${_selectedProducts.length})'),
              style: TextButton.styleFrom(foregroundColor: VendorTheme.info),
            ),
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PricingManagementScreen(storeId: widget.storeId))),
            icon: const Icon(Icons.price_change_outlined),
            tooltip: 'Pricing Intelligence',
          ),
          IconButton(
            onPressed: _openProductEditor,
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Product',
          ),
        ],
      ),
      body: _loading
          ? const AbzioLoadingView(title: 'Loading Catalog', subtitle: 'Fetching products and performance metrics.')
          : RefreshIndicator(
              color: VendorTheme.primary,
              onRefresh: _loadProducts,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: VendorTheme.spacing16, vertical: VendorTheme.spacing24),
                children: [
                  _buildCatalogOverview(activeCount, draftCount, outOfStockCount),
                  const SizedBox(height: VendorTheme.spacing24),
                  _buildSmartFilters(),
                  const SizedBox(height: VendorTheme.spacing24),
                  if (_filteredProducts.isEmpty)
                    VendorEmptyState(
                      title: _products.isEmpty ? 'Empty Catalog' : 'No matches found',
                      subtitle: _products.isEmpty ? 'List your first premium product.' : 'Try adjusting your smart filters.',
                      icon: Icons.inventory_2_outlined,
                      primaryActionLabel: _products.isEmpty ? 'Add Product' : null,
                      onPrimaryAction: _products.isEmpty ? _openProductEditor : null,
                    )
                  else ...[
                    _buildListHeader(),
                    ..._visibleProducts.map(_buildProductCard),
                    const SizedBox(height: VendorTheme.spacing16),
                    _buildPagination(),
                  ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openProductEditor,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product'),
      ),
    );
  }

  Widget _buildCatalogOverview(int active, int draft, int oos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CATALOG OVERVIEW', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: VendorTheme.spacing12),
        Row(
          children: [
            Expanded(child: VendorMetricCard(title: 'Total', value: '${_products.length}')),
            const SizedBox(width: VendorTheme.spacing12),
            Expanded(child: VendorMetricCard(title: 'Active', value: '$active')),
          ],
        ),
        const SizedBox(height: VendorTheme.spacing12),
        Row(
          children: [
            Expanded(child: VendorMetricCard(title: 'Draft', value: '$draft')),
            const SizedBox(width: VendorTheme.spacing12),
            Expanded(child: VendorMetricCard(title: 'Out of Stock', value: '$oos')),
          ],
        ),
      ],
    );
  }

  Widget _buildSmartFilters() {
    return PremiumVendorCard(
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by Name, SKU, Brand',
              prefixIcon: const Icon(Icons.search_rounded),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(VendorTheme.radiusSmall), borderSide: BorderSide(color: VendorTheme.grey200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(VendorTheme.radiusSmall), borderSide: BorderSide(color: VendorTheme.grey200)),
            ),
          ),
          const SizedBox(height: VendorTheme.spacing16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: const ['All', 'Active', 'Hidden', 'Draft', 'Out of Stock']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() { _statusFilter = v ?? 'All'; _page = 0; }),
                ),
              ),
              const SizedBox(width: VendorTheme.spacing12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _categoryFilter,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: _categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() { _categoryFilter = v ?? 'All'; _page = 0; }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: VendorTheme.spacing12, left: VendorTheme.spacing8),
      child: Row(
        children: [
          Checkbox(
            value: _selectedProducts.length == _filteredProducts.length && _filteredProducts.isNotEmpty,
            onChanged: (v) => _selectAll(),
            activeColor: VendorTheme.primary,
          ),
          Text('${_filteredProducts.length} Products Found', style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product p) {
    final qualityScore = _calculateQualityScore(p);
    final isSelected = _selectedProducts.contains(p.id);
    final conversionRate = p.viewCount > 0 ? (p.purchaseCount / p.viewCount * 100).toStringAsFixed(1) : '0.0';

    return PremiumVendorCard(
      margin: const EdgeInsets.only(bottom: VendorTheme.spacing16),
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      hasBorder: isSelected,
      backgroundColor: isSelected ? VendorTheme.secondary.withValues(alpha: 0.05) : null,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(p.id),
                activeColor: VendorTheme.primary,
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
                child: SizedBox(
                  width: 72,
                  height: 72,
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
                    Text(p.name, style: Theme.of(context).textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (p.brand.isNotEmpty) Text(p.brand, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: VendorTheme.spacing8),
                    Row(
                      children: [
                        Text('₹${p.price.toInt()}', style: Theme.of(context).textTheme.titleLarge),
                        if (p.originalPrice != null && p.originalPrice! > p.price) ...[
                          const SizedBox(width: VendorTheme.spacing8),
                          Text('₹${p.originalPrice!.toInt()}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(decoration: TextDecoration.lineThrough)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _openProductEditor(product: p),
                    tooltip: 'Edit',
                  ),
                  VendorStatusBadge(
                    label: p.status == ProductStatus.active ? 'Active' : 'Hidden',
                    type: p.status == ProductStatus.active ? VendorBadgeType.success : VendorBadgeType.neutral,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing16),
          const Divider(height: 1),
          const SizedBox(height: VendorTheme.spacing16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(label: 'Views', value: '${p.viewCount}'),
              _StatItem(label: 'Cart Adds', value: '${p.cartCount}'),
              _StatItem(label: 'Purchases', value: '${p.purchaseCount}'),
              _StatItem(label: 'Conv. Rate', value: '$conversionRate%'),
              _StatItem(label: 'Quality', value: '$qualityScore/100', highlight: qualityScore < 50),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing16),
          Wrap(
            spacing: VendorTheme.spacing8,
            runSpacing: VendorTheme.spacing8,
            children: [
              if (p.stock <= 0) const VendorStatusBadge(label: 'Out of Stock', type: VendorBadgeType.error),
              if (p.stock > 0 && p.stock <= 5) const VendorStatusBadge(label: 'Low Stock', type: VendorBadgeType.warning),
              if (p.purchaseCount > 50) const VendorStatusBadge(label: 'Best Seller', type: VendorBadgeType.info),
              if (conversionRate == '0.0' && p.viewCount > 100) const VendorStatusBadge(label: 'Slow Moving', type: VendorBadgeType.error),
              VendorStatusBadge(label: 'Stock: ${p.stock}', type: VendorBadgeType.neutral),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        VendorSecondaryButton(
          label: 'Prev',
          icon: Icons.chevron_left,
          onTap: _page > 0 ? () => setState(() => _page--) : null,
        ),
        Text('Page ${_page + 1} of $_pageCount', style: Theme.of(context).textTheme.labelLarge),
        VendorSecondaryButton(
          label: 'Next',
          icon: Icons.chevron_right,
          onTap: _page + 1 < _pageCount ? () => setState(() => _page++) : null,
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: highlight ? VendorTheme.error : VendorTheme.primary)),
        const SizedBox(height: VendorTheme.spacing4),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
