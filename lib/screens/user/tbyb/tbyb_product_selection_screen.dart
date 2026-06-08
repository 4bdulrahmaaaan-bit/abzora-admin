import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/trial_cart_provider.dart';
import '../../../theme.dart';
import 'tbyb_scheduling_screen.dart';
import '../../../models/models.dart';
import '../../../models/trial_session.dart';

class TbybProductSelectionScreen extends StatefulWidget {
  const TbybProductSelectionScreen({super.key});

  @override
  State<TbybProductSelectionScreen> createState() => _TbybProductSelectionScreenState();
}

class _TbybProductSelectionScreenState extends State<TbybProductSelectionScreen> {

  void _onContinue() {
    final trialCart = context.read<TrialCartProvider>();
    if (trialCart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your trial cart is empty. Please add items.')),
      );
      return;
    }

    final selectedProducts = trialCart.items.map((item) => Product(
      id: item.productId,
      storeId: item.storeId,
      name: item.name,
      description: '',
      brand: '',
      category: '',
      subcategory: '',
      basePrice: item.price,
      price: item.price,
      stock: 1,
      images: [item.imageUrl],
      sizes: [item.recommendedSize],
    )).toList(); // Reconstruct a stub product list for compatibility with downstream screens.

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TbybSchedulingScreen(
          selectedItems: selectedProducts,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trialCart = context.watch<TrialCartProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(
        title: const Text('Trial Cart'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: Colors.white,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Try Before You Buy Selection',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review your selected items and schedule delivery.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AbzioTheme.grey500,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: trialCart.isEmpty
                ? Center(
                    child: Text(
                      'Your trial cart is empty.',
                      style: TextStyle(color: AbzioTheme.grey500),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: trialCart.itemCount,
                    itemBuilder: (context, index) {
                      final item = trialCart.items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _TbybCartCard(
                          item: item,
                          onRemove: () => trialCart.removeItem(item.productId, item.recommendedSize),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: trialCart.isEmpty ? null : _onContinue,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: AbzioTheme.accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Schedule Delivery',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TbybCartCard extends StatelessWidget {
  const _TbybCartCard({
    required this.item,
    required this.onRemove,
  });

  final TrialSessionItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 80,
              height: 100,
              color: AbzioTheme.grey200,
              child: item.imageUrl.isNotEmpty
                  ? Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AbzioTheme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Try At Home',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AbzioTheme.accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${item.price.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'Size: ${item.recommendedSize}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.delete_outline, color: AbzioTheme.grey500),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
