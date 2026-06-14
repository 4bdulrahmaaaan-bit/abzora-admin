import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_empty_state.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../models/models.dart';

class CatalogBulkEditTab extends StatefulWidget {
  final String? storeId;
  const CatalogBulkEditTab({super.key, this.storeId});

  @override
  State<CatalogBulkEditTab> createState() => _CatalogBulkEditTabState();
}

class _CatalogBulkEditTabState extends State<CatalogBulkEditTab> {
  List<Product>? _products;
  bool _isLoading = true;
  bool _isSaving = false;

  final Map<String, double> _editedPrices = {};
  final Map<String, int> _editedStock = {};
  
  // To avoid keeping too many controllers in memory, we can just use the map and create them dynamically,
  // but for proper text field behavior, it's safer to use local Focus/Controllers per row,
  // or simply update the map onChange. Using initialValue with TextFormField and onChanged is cleaner.

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) _loadData();
  }

  Future<void> _loadData() async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) return;
    try {
      final storeId = widget.storeId ?? actor.storeId;
      if (storeId != null) {
        final products = await DatabaseService().getProductsByStore(storeId);
        if (mounted) {
          setState(() {
            _products = products;
            _editedPrices.clear();
            _editedStock.clear();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAll() async {
    if (_editedPrices.isEmpty && _editedStock.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Bulk Edit'),
        content: Text('You are about to modify ${_editedPrices.keys.toSet().union(_editedStock.keys.toSet()).length} products. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: VendorTheme.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);

    int success = 0;
    int failed = 0;

    final db = DatabaseService();
    final allKeys = _editedPrices.keys.toSet().union(_editedStock.keys.toSet());

    for (final productId in allKeys) {
      try {
        final product = _products!.firstWhere((p) => p.id == productId);
        final newPrice = _editedPrices[productId] ?? product.price;
        final newStock = _editedStock[productId] ?? product.stock;

        await db.updateProduct(product.copyWith(
          price: newPrice,
          stock: newStock,
        ));
        success++;
      } catch (e) {
        failed++;
      }
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
        _editedPrices.clear();
        _editedStock.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bulk edit complete. Updated: $success, Failed: $failed'),
          backgroundColor: failed > 0 ? VendorTheme.warning : VendorTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Reload to reflect confirmed server state
      setState(() => _isLoading = true);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: VendorTheme.primary));
    }

    if (_products == null || _products!.isEmpty) {
      return const VendorEmptyState(
        title: 'No Products Found',
        subtitle: 'Add products to your catalog before you can bulk edit them.',
        icon: Icons.inventory_2_outlined,
      );
    }

    final isDirty = _editedPrices.isNotEmpty || _editedStock.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ListView.separated(
            padding: const EdgeInsets.fromLTRB(VendorTheme.spacing16, VendorTheme.spacing16, VendorTheme.spacing16, 80),
            itemCount: _products!.length,
            separatorBuilder: (context, index) => const SizedBox(height: VendorTheme.spacing12),
            itemBuilder: (context, index) {
              final product = _products![index];
              return PremiumVendorCard(
                padding: const EdgeInsets.all(VendorTheme.spacing16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Product image snippet
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 50,
                        height: 50,
                        color: VendorTheme.grey800,
                        child: product.images.isNotEmpty
                            ? Image.network(product.images.first, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, color: VendorTheme.grey400))
                            : const Icon(Icons.image, color: VendorTheme.grey400),
                      ),
                    ),
                    const SizedBox(width: VendorTheme.spacing12),
                    Expanded(
                      flex: 2,
                      child: Text(
                        product.name,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: VendorTheme.spacing12),
                    Expanded(
                      child: TextFormField(
                        initialValue: (_editedPrices[product.id] ?? product.price).toString(),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Price (₹)',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null && parsed != product.price) {
                            setState(() => _editedPrices[product.id] = parsed);
                          } else if (parsed == product.price) {
                            setState(() => _editedPrices.remove(product.id));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: VendorTheme.spacing12),
                    Expanded(
                      child: TextFormField(
                        initialValue: (_editedStock[product.id] ?? product.stock).toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && parsed != product.stock) {
                            setState(() => _editedStock[product.id] = parsed);
                          } else if (parsed == product.stock) {
                            setState(() => _editedStock.remove(product.id));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_isSaving)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: VendorTheme.primary),
                        SizedBox(height: 16),
                        Text('Saving changes...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: isDirty && !_isSaving
          ? FloatingActionButton.extended(
              onPressed: _saveAll,
              backgroundColor: VendorTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.save),
              label: Text('Save ${_editedPrices.keys.toSet().union(_editedStock.keys.toSet()).length} Changes'),
            )
          : null,
    );
  }
}
