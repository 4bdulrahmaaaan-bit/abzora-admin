import 'package:flutter/material.dart';

import '../theme.dart';
import 'shimmer_widget.dart';

class BannerShimmer extends StatelessWidget {
  const BannerShimmer({
    super.key,
    this.height = 220,
    this.itemCount = 1,
  });

  final double height;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: itemCount,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return SizedBox(
                width: MediaQuery.of(context).size.width * 0.86,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ShimmerWidget(radius: 20),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 18,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ShimmerWidget(width: 140, height: 14, radius: 99),
                            const SizedBox(height: 14),
                            const ShimmerWidget(width: 220, height: 24, radius: 10),
                            const SizedBox(height: 10),
                            const ShimmerWidget(width: 180, height: 14, radius: 10),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 110,
                                height: 46,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: AbzioTheme.accentColor.withValues(alpha: 0.15),
                                ),
                                child: const ShimmerWidget(radius: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            4,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: index == 0 ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: index == 0 ? AbzioTheme.accentColor.withValues(alpha: 0.45) : Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
