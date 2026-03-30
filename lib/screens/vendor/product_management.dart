import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/state_views.dart';
import 'add_product_screen.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({
    super.key,
    required this.storeId,
  });

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

  List<Product> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _products.where((product) {
      final matchesStatus = _statusFilter == 'All' ||
          (_statusFilter == 'Active' && product.isActive) ||
          (_statusFilter == 'Hidden' && !product.isActive);
      final matchesCategory = _categoryFilter == 'All' || product.category == _categoryFilter;
      final haystack = '${product.name} ${product.brand} ${product.category}'.toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesStatus && matchesCategory && matchesQuery;
    }).toList()
      ..sort((a, b) {
        final left = a.createdAt ?? '';
        final right = b.createdAt ?? '';
        return right.compareTo(left);
      });
    return filtered;
  }

  List<Product> get _visibleProducts {
    final start = _page * _pageSize;
    final filtered = _filteredProducts;
    if (start >= filtered.length) {
      return const [];
    }
    final end = (start + _pageSize).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  int get _pageCount {
    final count = _filteredProducts.length;
    if (count == 0) {
      return 1;
    }
    return (count / _pageSize).ceil();
  }

  List<String> get _categories {
    final values = _products.map((product) => product.category).where((value) => value.trim().isNotEmpty).toSet().toList()
      ..sort();
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
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() => _page = 0);
  }

  Future<void> _loadProducts() async {
    final actor = context.read<AuthProvider>().user;
    final products = await _db.getProductsByStore(widget.storeId);
    if (!mounted) {
      return;
    }
    setState(() {
      _products = products;
      _loading = false;
      _page = 0;
    });
    if (actor == null) {
      return;
    }
  }

  Future<void> _deleteProduct(Product product) async {
    await _db.deleteProduct(product.id, actor: context.read<AuthProvider>().user);
    await _loadProducts();
  }

  Future<void> _openProductEditor({Product? product}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          storeId: widget.storeId,
          existingProduct: product,
        ),
      ),
    );
    await _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCount = _filteredProducts.length;
    final activeCount = _products.where((product) => product.isActive).length;
    final hiddenCount = _products.length - activeCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PRODUCT MANAGEMENT'),
        actions: [
          IconButton(
            onPressed: () => _openProductEditor(),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add product',
          ),
        ],
      ),
      body: _loading
          ? const AbzioLoadingView(
              title: 'Loading catalog',
              subtitle: 'Preparing inventory controls, product status, and pricing.',
            )
          : RefreshIndicator(
              onRefresh: _loadProducts,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _SummaryMetric(
                        label: 'Total products',
                        value: '${_products.length}',
                      ),
                      _SummaryMetric(
                        label: 'Active',
                        value: '$activeCount',
                      ),
                      _SummaryMetric(
                        label: 'Hidden',
                        value: '$hiddenCount',
                      ),
                      _SummaryMetric(
                        label: 'Filtered',
                        value: '$filteredCount',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Catalog filters',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search by name, brand, or category',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: 180,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _statusFilter,
                                  decoration: const InputDecoration(labelText: 'Status'),
                                  items: const ['All', 'Active', 'Hidden']
                                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                                      .toList(),
                                  onChanged: (value) => setState(() {
                                    _statusFilter = value ?? 'All';
                                    _page = 0;
                                  }),
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _categoryFilter,
                                  decoration: const InputDecoration(labelText: 'Category'),
                                  items: _categories
                                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                                      .toList(),
                                  onChanged: (value) => setState(() {
                                    _categoryFilter = value ?? 'All';
                                    _page = 0;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_filteredProducts.isEmpty)
                    AbzioEmptyCard(
                      title: _products.isEmpty ? 'No products yet' : 'No products match the current filters',
                      subtitle: _products.isEmpty
                          ? 'Start building your premium catalog and the first collection will appear here.'
                          : 'Adjust the filters or add a new product to expand the catalog.',
                      ctaLabel: 'ADD PRODUCT',
                      onTap: () => _openProductEditor(),
                    )
                  else ...[
                    ..._visibleProducts.map(_buildProductCard),
                    const SizedBox(height: 16),
                    _PaginationBar(
                      currentPage: _page,
                      pageCount: _pageCount,
                      pageSize: _pageSize,
                      totalItems: filteredCount,
                      onPrevious: _page > 0 ? () => setState(() => _page -= 1) : null,
                      onNext: _page + 1 < _pageCount ? () => setState(() => _page += 1) : null,
                    ),
                  ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('ADD PRODUCT'),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final originalPrice = product.originalPrice;
    final hasDiscount = originalPrice != null && originalPrice > product.price;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 84,
                height: 84,
                child: AbzioNetworkImage(
                  imageUrl: product.images.isNotEmpty ? product.images.first : 'https://via.placeholder.com/200',
                  fallbackLabel: product.name,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                  if (product.brand.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      product.brand,
                      style: GoogleFonts.inter(fontSize: 13, color: Theme.of(context).hintColor),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TagChip(label: product.category),
                      _TagChip(label: product.isActive ? 'Active' : 'Hidden'),
                      _TagChip(label: 'Stock ${product.stock}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: 'Rs ${product.price.toInt()}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        if (hasDiscount) ...[
                          TextSpan(
                            text: '   Rs ${originalPrice.toInt()}',
                            style: GoogleFonts.inter(
                              color: Theme.of(context).hintColor,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                IconButton(
                  onPressed: () => _openProductEditor(product: product),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit product',
                ),
                IconButton(
                  onPressed: () => _deleteProduct(product),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete product',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(color: Theme.of(context).hintColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.pageCount,
    required this.pageSize,
    required this.totalItems,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int pageCount;
  final int pageSize;
  final int totalItems;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final start = totalItems == 0 ? 0 : (currentPage * pageSize) + 1;
    final end = ((currentPage + 1) * pageSize).clamp(0, totalItems);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Showing $start-$end of $totalItems',
            style: GoogleFonts.inter(color: Theme.of(context).hintColor),
          ),
        ),
        TextButton.icon(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
          label: const Text('Previous'),
        ),
        Text(
          '${currentPage + 1} / $pageCount',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        TextButton.icon(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          label: const Text('Next'),
        ),
      ],
    );
  }
}
