import 'package:flutter/material.dart';

import 'shimmer_box.dart';

class ProductShimmer extends StatelessWidget {
  const ProductShimmer({
    super.key,
    this.itemCount = 2,
    this.shrinkWrap = false,
    this.physics,
    this.scrollDirection = Axis.vertical,
  });

  final int itemCount;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Axis scrollDirection;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: scrollDirection,
      shrinkWrap: shrinkWrap,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      padding: EdgeInsets.zero,
      itemCount: itemCount == 4 && scrollDirection == Axis.vertical ? 2 : itemCount,
      separatorBuilder: (context, index) => SizedBox(
        height: scrollDirection == Axis.vertical ? 20 : 0,
        width: scrollDirection == Axis.horizontal ? 12 : 0,
      ),
      itemBuilder: (context, index) {
        return SizedBox(
          width: scrollDirection == Axis.horizontal ? 150 : null,
          child: Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ShimmerBox(
                          borderRadius: BorderRadius.zero,
                        ),
                        // Only add minimal elements to avoid oversized filler content
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
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerBox(
                        width: 80,
                        height: 12,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        baseColor: Color(0xFFE3DCCF),
                        highlightColor: Color(0xFFF7F5F1),
                      ),
                      const SizedBox(height: 8),
                      const FractionallySizedBox(
                        widthFactor: 0.9,
                        child: ShimmerBox(
                          height: 16,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const FractionallySizedBox(
                        widthFactor: 0.6,
                        child: ShimmerBox(
                          height: 16,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const ShimmerBox(
                        width: 120,
                        height: 18,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
