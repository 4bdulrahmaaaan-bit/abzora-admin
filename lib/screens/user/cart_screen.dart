import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/text_constants.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Future<List<Product>>? _completeTheLookFuture;
  String? _anchorProductId;

  void _ensureCompleteTheLook(CartProvider cart) {
    if (cart.items.isEmpty) {
      _anchorProductId = null;
      _completeTheLookFuture = null;
      return;
    }

    final product = cart.items.first.product;
    if (_anchorProductId == product.id && _completeTheLookFuture != null) {
      return;
    }

    _anchorProductId = product.id;
    _completeTheLookFuture = DatabaseService().getCompleteTheLook(product);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AbzioThemeScope.dark(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AbzoraText.cartTitle),
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
        ),
        body: Consumer<CartProvider>(
        builder: (context, cart, child) {
          _ensureCompleteTheLook(cart);
          if (cart.items.isEmpty) {
            return AbzioEmptyCard(
              title: AbzoraText.cartEmptyTitle,
              subtitle: AbzoraText.cartEmptySubtitle,
              ctaLabel: AbzoraText.cartEmptyCta,
              onTap: () => Navigator.pop(context),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.workspace_premium_outlined, color: AbzioTheme.accentColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AbzoraText.oneStoreBagNotice,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.abzioSecondaryText),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...cart.items.map(
                      (item) => Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 86,
                                  height: 110,
                                  child: AbzioNetworkImage(
                                    imageUrl: item.product.images.isNotEmpty ? item.product.images.first : 'https://via.placeholder.com/200',
                                    fallbackLabel: item.product.name,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.product.category.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AbzioTheme.accentColor)),
                                    const SizedBox(height: 4),
                                    Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text('Size: ${item.size}'),
                                    if (item.product.isCustomTailoring && item.product.neededBy != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text('Need by: ${item.product.neededBy!.day}/${item.product.neededBy!.month}/${item.product.neededBy!.year}'),
                                      ),
                                  const SizedBox(height: 10),
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        Text('Rs ${item.product.price.toInt()}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(onPressed: () => cart.updateQuantity(item.product.id, item.size, -1), icon: const Icon(Icons.remove_circle_outline)),
                                            Text(item.quantity.toString()),
                                            IconButton(onPressed: () => cart.updateQuantity(item.product.id, item.size, 1), icon: const Icon(Icons.add_circle_outline)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => cart.removeFromCart(item.product.id, item.size),
                                        child: const Text(AbzoraText.remove),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    FutureBuilder<List<Product>>(
                      future: _completeTheLookFuture,
                      builder: (context, snapshot) {
                        final suggestions = snapshot.data ?? <Product>[];
                        if (suggestions.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            Text(AbzoraText.completeTheLookTitle, style: Theme.of(context).textTheme.labelMedium),
                            const SizedBox(height: 10),
                            ...suggestions.take(3).map(
                              (product) => Card(
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: AbzioNetworkImage(
                                        imageUrl: product.images.first,
                                        fallbackLabel: product.name,
                                      ),
                                    ),
                                  ),
                                  title: Text(product.name),
                                  subtitle: Text('Rs ${product.price.toInt()}'),
                                  trailing: TextButton(
                                    onPressed: () {
                                      final result = context.read<CartProvider>().addToCart(product, product.sizes.first);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          behavior: SnackBarBehavior.floating,
                                          content: Text(
                                            result == CartAddResult.storeConflict
                                                ? 'Your bag already has items from another store.'
                                                : '${product.name} added to your bag.',
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text(AbzoraText.addToBag),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        runSpacing: 6,
                        children: [
                          const Text(AbzoraText.total, style: TextStyle(fontWeight: FontWeight.w800)),
                          Text('Rs ${cart.totalAmount.toInt()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () async {
                          final user = auth.user;
                          if (user == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text('Sign in to save a reminder for this bag.'),
                              ),
                            );
                            return;
                          }
                          final items = cart.items
                              .map(
                                (item) => OrderItem(
                                  productId: item.product.id,
                                  productName: item.product.name,
                                  quantity: item.quantity,
                                  price: item.product.price,
                                  size: item.size,
                                  imageUrl: item.product.images.isNotEmpty ? item.product.images.first : '',
                                ),
                              )
                              .toList();
                          await DatabaseService().createAbandonedCartReminder(user: user, items: items);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text(AbzoraText.bagReminderSuccess),
                              ),
                            );
                          }
                        },
                        child: const Text(AbzoraText.remindMeLater),
                      ),
                      const SizedBox(height: 4),
                      ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/checkout'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                        child: const Text(AbzoraText.proceedToCheckout),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        ),
      ),
    );
  }
}
