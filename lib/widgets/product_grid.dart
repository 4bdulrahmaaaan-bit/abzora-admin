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

    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.64,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          onTap: () => onProductTap(product),
        );
      },
    );
  }
}
