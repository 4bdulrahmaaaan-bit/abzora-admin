import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/banner_model.dart';
import '../providers/banner_provider.dart';
import '../theme.dart';
import 'banner_shimmer.dart';
import 'shimmer_box.dart';

class BannerCarousel extends StatefulWidget {
  const BannerCarousel({
    super.key,
    required this.banners,
    required this.onBannerTap,
    this.isLoading = false,
    this.height = 220,
    this.autoScrollInterval = const Duration(seconds: 4),
  });

  final List<BannerModel> banners;
  final ValueChanged<BannerModel> onBannerTap;
  final bool isLoading;
  final double height;
  final Duration autoScrollInterval;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  static const int _loopSeed = 1000;

  int get _initialPage {
    if (widget.banners.isEmpty) {
      return 0;
    }
    return widget.banners.length * _loopSeed;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.92,
      initialPage: _initialPage,
    );
    _scheduleAutoScroll();
  }

  @override
  void didUpdateWidget(covariant BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      context.read<BannerProvider>().setActiveIndex(0);
      _scheduleAutoScroll();
    }
  }

  void _scheduleAutoScroll() {
    _autoScrollTimer?.cancel();
    if (widget.banners.length <= 1) {
      return;
    }
    _autoScrollTimer = Timer.periodic(widget.autoScrollInterval, (_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _pauseAutoScroll() {
    _autoScrollTimer?.cancel();
  }

  void _resumeAutoScroll() {
    _scheduleAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return BannerShimmer(height: widget.height);
    }

    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: Listener(
            onPointerDown: (_) => _pauseAutoScroll(),
            onPointerUp: (_) => _resumeAutoScroll(),
            onPointerCancel: (_) => _resumeAutoScroll(),
            child: PageView.builder(
              controller: _pageController,
              itemBuilder: (context, index) {
                final banner = widget.banners[index % widget.banners.length];
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    var scale = 1.0;
                    if (_pageController.position.hasContentDimensions) {
                      final page = _pageController.page ?? _pageController.initialPage.toDouble();
                      final distance = (page - index).abs().clamp(0.0, 1.0);
                      scale = 1 - (distance * 0.06);
                    }

                    return Transform.scale(
                      scale: scale,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: child,
                      ),
                    );
                  },
                  child: _BannerCard(
                    banner: banner,
                    onTap: () => widget.onBannerTap(banner),
                  ),
                );
              },
              onPageChanged: (index) {
                context.read<BannerProvider>().setActiveIndex(index % widget.banners.length);
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        Consumer<BannerProvider>(
          builder: (context, provider, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.banners.length,
                (index) {
                  final active = provider.activeIndex == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? AbzioTheme.accentColor : context.abzioBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.banner,
    required this.onTap,
  });

  final BannerModel banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: banner.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const ShimmerBox(),
                  errorWidget: (context, url, error) => Container(
                    color: Theme.of(context).cardColor,
                    alignment: Alignment.center,
                    child: Text(
                      banner.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.82),
                          Colors.black.withValues(alpha: 0.28),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              banner.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    height: 1.05,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              banner.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.86),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AbzioTheme.accentColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(banner.ctaText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
