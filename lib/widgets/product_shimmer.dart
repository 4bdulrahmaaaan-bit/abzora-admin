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
        const baseColor = Color(0xFFECE8E1);
        const highlightColor = Color(0xFFF7F5F1);

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
                color: const Color(0xFFFAFAF7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE8E1D7)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
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
                          ShimmerBox(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(20),
                            ),
                            baseColor: baseColor,
                            highlightColor: highlightColor,
                            period: const Duration(milliseconds: 1350),
                          ),
                          Positioned(
                            left: 8,
                            top: 8,
                            child: ShimmerBox(
                              width: 42,
                              height: 16,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(999),
                              ),
                              baseColor: baseColor,
                              highlightColor: highlightColor,
                              period: const Duration(milliseconds: 1350),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBF9F5).withValues(
                                  alpha: 0.94,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: ShimmerBox(
                                width: 30,
                                height: 30,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(999),
                                ),
                                baseColor: baseColor,
                                highlightColor: highlightColor,
                                period: const Duration(milliseconds: 1350),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ShimmerBox(
                    width: 74,
                    height: 12,
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    period: const Duration(milliseconds: 1350),
                  ),
                  const SizedBox(height: 6),
                  ShimmerBox(
                    height: 14,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    period: const Duration(milliseconds: 1350),
                  ),
                  const SizedBox(height: 4),
                  ShimmerBox(
                    width: 112,
                    height: 14,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    period: const Duration(milliseconds: 1350),
                  ),
                  const SizedBox(height: 8),
                  ShimmerBox(
                    width: 88,
                    height: 18,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    period: const Duration(milliseconds: 1350),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ShimmerBox(
                        width: 44,
                        height: 12,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(999),
                        ),
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                        period: const Duration(milliseconds: 1350),
                      ),
                      const SizedBox(width: 8),
                      ShimmerBox(
                        width: 34,
                        height: 12,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(999),
                        ),
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                        period: const Duration(milliseconds: 1350),
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
