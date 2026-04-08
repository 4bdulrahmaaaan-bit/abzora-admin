import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/text_constants.dart';
import '../../models/models.dart';
import '../../providers/wishlist_provider.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';
import 'product_detail_screen.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AbzoraText.wishlistTitle)),
      body: Consumer<WishlistProvider>(
        builder: (context, wishlist, child) {
          if (wishlist.isLoading) {
            return const AbzioLoadingView(
              title: AbzoraText.wishlistLoadingTitle,
              subtitle: AbzoraText.wishlistLoadingSubtitle,
            );
          }

          if (wishlist.items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: AbzioEmptyCard(
                  title: AbzoraText.wishlistEmptyTitle,
                  subtitle: AbzoraText.wishlistEmptySubtitle,
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: wishlist.items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childAspectRatio: 0.7,
            ),
            itemBuilder: (context, index) {
              final item = wishlist.items[index];
              return _WishlistTile(item: item);
            },
          );
        },
      ),
    );
  }
}

class _WishlistTile extends StatelessWidget {
  const _WishlistTile({required this.item});

  final WishlistItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              product: Product(
                id: item.productId,
                storeId: item.storeId,
                name: item.name,
                description: '',
                price: item.price,
                images: item.image.isEmpty ? const [] : [item.image],
                sizes: const ['M'],
                stock: 1,
                category: 'Fashion',
                rating: 0,
                reviewCount: 0,
                isCustomTailoring: false,
              ),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.abzioBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AbzioNetworkImage(
                    imageUrl: item.image,
                    fallbackLabel: item.name,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Theme.of(context).cardColor.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(99),
                      child: IconButton(
                        onPressed: () => context.read<WishlistProvider>().removeFromWishlist(item.productId),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('Rs ${item.price.toInt()}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'Verified seller | Easy returns',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: context.abzioSecondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
