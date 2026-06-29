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
        final isCompact = width <= 380;
        final aspectRatio = isCompact ? 0.50 : 0.54;

        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: physics ?? const NeverScrollableScrollPhysics(),
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          padding: EdgeInsets.zero,
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 20,
            crossAxisSpacing: 14,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFB89A57).withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.028),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ShimmerBox(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          Positioned(
                            left: 8,
                            top: 8,
                            child: ShimmerBox(
                              width: 60,
                              height: 28,
                              borderRadius: const BorderRadius.all(Radius.circular(14)),
                              baseColor: Colors.white.withValues(alpha: 0.72),
                              highlightColor: Colors.white,
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: ShimmerBox(
                              width: 32,
                              height: 32,
                              borderRadius: const BorderRadius.all(Radius.circular(16)),
                              baseColor: Colors.white.withValues(alpha: 0.9),
                              highlightColor: Colors.white,
                            ),
                          ),
                          Positioned(
                            left: 10,
                            bottom: 10,
                            child: ShimmerBox(
                              width: 70,
                              height: 24,
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                              baseColor: Colors.white.withValues(alpha: 0.72),
                              highlightColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const ShimmerBox(
                    width: 74,
                    height: 12,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                  const SizedBox(height: 6),
                  const ShimmerBox(
                    width: double.infinity,
                    height: 17,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                  const SizedBox(height: 4),
                  const ShimmerBox(
                    width: 120,
                    height: 17,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const ShimmerBox(
                        width: 70,
                        height: 18,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      const SizedBox(width: 8),
                      ShimmerBox(
                        width: 40,
                        height: 14,
                        borderRadius: const BorderRadius.all(Radius.circular(4)),
                        baseColor: const Color(0xFFECE8E1).withValues(alpha: 0.5),
                        highlightColor: const Color(0xFFF7F5F1).withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const ShimmerBox(
                    width: 130,
                    height: 30,
                    borderRadius: BorderRadius.all(Radius.circular(15)),
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
