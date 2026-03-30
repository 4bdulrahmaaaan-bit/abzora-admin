import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/state_views.dart';
import 'add_product_screen.dart';

class VendorProductListScreen extends StatefulWidget {
  final String storeId;

  const VendorProductListScreen({
    super.key,
    required this.storeId,
  });

  @override
  State<VendorProductListScreen> createState() => _VendorProductListScreenState();
}

class _VendorProductListScreenState extends State<VendorProductListScreen> {
  final _db = DatabaseService();
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    final products = await _db.getProductsByStore(widget.storeId);
    if (!mounted) {
      return;
    }
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  Future<void> _deleteProduct(String productId) async {
    await _db.deleteProduct(productId, actor: context.read<AuthProvider>().user);
    await _fetchProducts();
  }

  void _openAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddProductScreen(storeId: widget.storeId)),
    ).then((_) => _fetchProducts());
  }

  void _openEditProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          storeId: widget.storeId,
          existingProduct: product,
        ),
      ),
    ).then((_) => _fetchProducts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MY PRODUCTS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _openAddProduct,
          ),
        ],
      ),
      body: _isLoading
          ? const AbzioLoadingView(
              title: 'Loading products',
              subtitle: 'Gathering your latest catalog, inventory, and pricing.',
            )
          : _products.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchProducts,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _products.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildProductCard(_products[index]),
                  ),
                ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 64,
            height: 64,
            child: AbzioNetworkImage(
              imageUrl: product.images.isNotEmpty ? product.images.first : 'https://via.placeholder.com/200',
              fallbackLabel: product.name,
            ),
          ),
        ),
        title: Text(product.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${product.brand.isNotEmpty ? '${product.brand} | ' : ''}Rs ${product.price.toInt()} | ${product.category} | Stock ${product.stock} | ${product.isActive ? 'Active' : 'Hidden'}',
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              onPressed: () => _openEditProduct(product),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: () => _deleteProduct(product.id),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AbzioEmptyCard(
          title: 'No products yet',
          subtitle: 'Start building your premium catalog and the first collection will appear here.',
          ctaLabel: 'ADD FIRST PRODUCT',
          onTap: _openAddProduct,
        ),
      ),
    );
  }
}
