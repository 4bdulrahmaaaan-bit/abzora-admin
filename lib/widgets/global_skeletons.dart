import 'package:flutter/material.dart';

import '../theme.dart';
import 'shimmer_box.dart';

class ShimmerWrapper extends StatelessWidget {
  const ShimmerWrapper({
    super.key,
    required this.isLoading,
    required this.child,
    required this.shimmer,
  });

  final bool isLoading;
  final Widget child;
  final Widget shimmer;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: isLoading ? shimmer : child,
    );
  }
}

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({
    super.key,
    this.height = 120,
    this.padding = const EdgeInsets.all(16),
  });

  final double height;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 120, height: 14, borderRadius: BorderRadius.all(Radius.circular(8))),
          const SizedBox(height: 12),
          SizedBox(
            height: height,
            width: double.infinity,
            child: ShimmerBox(
              width: double.infinity,
              height: height,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerListItem extends StatelessWidget {
  const ShimmerListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Row(
        children: [
          ShimmerBox(
            width: 68,
            height: 68,
            borderRadius: BorderRadius.circular(16),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 150, height: 14, borderRadius: BorderRadius.all(Radius.circular(8))),
                SizedBox(height: 10),
                ShimmerBox(width: 110, height: 12, borderRadius: BorderRadius.all(Radius.circular(8))),
                SizedBox(height: 10),
                ShimmerBox(width: 72, height: 12, borderRadius: BorderRadius.all(Radius.circular(8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerProfileHeader extends StatelessWidget {
  const ShimmerProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF171517), Color(0xFF231F22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBox(
                width: 72,
                height: 72,
                borderRadius: BorderRadius.all(Radius.circular(36)),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 150, height: 16, borderRadius: BorderRadius.all(Radius.circular(8))),
                    SizedBox(height: 10),
                    ShimmerBox(width: 110, height: 12, borderRadius: BorderRadius.all(Radius.circular(8))),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          ShimmerBox(width: double.infinity, height: 14, borderRadius: BorderRadius.all(Radius.circular(8))),
          SizedBox(height: 10),
          ShimmerBox(width: 220, height: 14, borderRadius: BorderRadius.all(Radius.circular(8))),
        ],
      ),
    );
  }
}

class ShimmerProductGrid extends StatelessWidget {
  const ShimmerProductGrid({
    super.key,
    this.itemCount = 4,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.68,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.abzioBorder.withValues(alpha: 0.8)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(
                child: ShimmerBox(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
              ),
              SizedBox(height: 12),
              ShimmerBox(width: 120, height: 14, borderRadius: BorderRadius.all(Radius.circular(8))),
              SizedBox(height: 8),
              ShimmerBox(width: 72, height: 12, borderRadius: BorderRadius.all(Radius.circular(8))),
            ],
          ),
        );
      },
    );
  }
}

class ShimmerCategoryRow extends StatelessWidget {
  const ShimmerCategoryRow({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return const Column(
            children: [
              ShimmerBox(
                width: 56,
                height: 56,
                borderRadius: BorderRadius.all(Radius.circular(28)),
              ),
              SizedBox(height: 8),
              ShimmerBox(width: 44, height: 10, borderRadius: BorderRadius.all(Radius.circular(8))),
            ],
          );
        },
      ),
    );
  }
}

class ShimmerBannerBlock extends StatelessWidget {
  const ShimmerBannerBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(
      width: double.infinity,
      height: 180,
      borderRadius: BorderRadius.circular(24),
    );
  }
}
