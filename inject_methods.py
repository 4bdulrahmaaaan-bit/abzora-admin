import os

file_path = r'c:\Users\AAA\Documents\abzio\lib\screens\vendor\add_product_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

new_methods = """
  Future<void> _fetchRelatedProducts() async {
    try {
      final products = await _database.getProductsByStore(widget.storeId, includeInactive: true);
      if (mounted) {
        setState(() {
          _vendorProducts = products.where((p) => p.id != widget.existingProduct?.id).toList();
          if (widget.existingProduct != null && widget.existingProduct!.completeLookProductIds.isNotEmpty) {
            _relatedProducts = _vendorProducts
                .where((p) => widget.existingProduct!.completeLookProductIds.contains(p.id))
                .toList();
          }
          _isLoadingRelated = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRelated = false);
    }
  }

  void _showRelatedProductsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Related Products',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_relatedProducts.length}/5',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _relatedProducts.length == 5 ? Colors.red : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: _vendorProducts.isEmpty
                        ? const Center(child: Text('No products available'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _vendorProducts.length,
                            itemBuilder: (context, index) {
                              final p = _vendorProducts[index];
                              final isSelected = _relatedProducts.any((rp) => rp.id == p.id);
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                activeColor: const Color(0xFF0D0D0D),
                                value: isSelected,
                                onChanged: (val) {
                                  if (val == true) {
                                    if (_relatedProducts.length < 5) {
                                      setSheetState(() => _relatedProducts.add(p));
                                      setState(() {});
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('You can select up to 5 related products.')),
                                      );
                                    }
                                  } else {
                                    setSheetState(() => _relatedProducts.removeWhere((rp) => rp.id == p.id));
                                    setState(() {});
                                  }
                                },
                                title: Row(
                                  children: [
                                    if (p.imageUrls.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          p.imageUrls.first,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        p.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Done',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRelatedProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Related Products',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B1B1B),
              ),
            ),
            TextButton.icon(
              onPressed: _isLoadingRelated ? null : _showRelatedProductsSheet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0D0D0D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoadingRelated)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_relatedProducts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F7F1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7DDCA)),
            ),
            child: const Text(
              'No related products added (Optional)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          )
        else
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _relatedProducts.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final rp = _relatedProducts[index];
                return Container(
                  padding: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      if (rp.imageUrls.isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(30)),
                          child: Image.network(
                            rp.imageUrls.first,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: Text(
                          rp.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          setState(() {
                            _relatedProducts.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
"""

target = """  Widget _buildPremiumCommerceSection() {"""
replace = new_methods + "\n" + target

content = content.replace(target, replace)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Injected related products methods.")
