import 'package:flutter/material.dart';

import 'shimmer_box.dart';

class ProductShimmer extends StatelessWidget {
  const ProductShimmer({
    super.key,
    this.itemCount = 4,
    this.shrinkWrap = false,
    this.physics,
  });

  final int itemCount;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
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
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: ShimmerBox(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: const ShimmerBox(
                            width: 44,
                            height: 20,
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                            ),
                            child: const ShimmerBox(
                              width: 34,
                              height: 34,
                              borderRadius: BorderRadius.all(
                                Radius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const ShimmerBox(
                    width: 72,
                    height: 10,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  const SizedBox(height: 8),
                  const ShimmerBox(
                    height: 14,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  const SizedBox(height: 6),
                  const ShimmerBox(
                    width: 110,
                    height: 14,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      ShimmerBox(
                        width: 64,
                        height: 16,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      SizedBox(width: 8),
                      ShimmerBox(
                        width: 44,
                        height: 12,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      SizedBox(width: 8),
                      ShimmerBox(
                        width: 48,
                        height: 12,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
