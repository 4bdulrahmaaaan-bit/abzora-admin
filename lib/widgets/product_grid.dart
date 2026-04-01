import 'package:flutter/material.dart';

import '../models/models.dart';
import 'product_card.dart';
import 'product_shimmer.dart';
import 'state_views.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
    this.isLoading = false,
    this.shrinkWrap = false,
    this.physics,
    this.emptyTitle = 'Start exploring styles near you',
    this.emptySubtitle = 'Curated picks from nearby fashion stores will appear here.',
  });

  final List<Product> products;
  final ValueChanged<Product> onProductTap;
  final bool isLoading;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    if (isLoading && products.isEmpty) {
      return ProductShimmer(
        shrinkWrap: shrinkWrap,
        physics: physics,
      );
    }

    if (products.isEmpty) {
      return AbzioEmptyCard(
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 360;
        final crossAxisCount = width >= 720 ? 3 : 2;
        final spacing = isCompact ? 10.0 : 12.0;
        final aspectRatio = width >= 720
            ? 0.7
            : isCompact
            ? 0.62
            : 0.66;

        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: physics ?? const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductCard(
              product: product,
              onTap: () => onProductTap(product),
            );
          },
        );
      },
    );
  }
}
