import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/banner_model.dart';
import '../providers/banner_provider.dart';
import '../services/image_url_service.dart';
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
      viewportFraction: 1.0,
      initialPage: _initialPage,
    );
    _scheduleAutoScroll();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheHero());
  }

  @override
  void didUpdateWidget(covariant BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      context.read<BannerProvider>().setActiveIndex(0);
      _scheduleAutoScroll();
      WidgetsBinding.instance.addPostFrameCallback((_) => _precacheHero());
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

  void _precacheHero() {
    if (!mounted || widget.banners.isEmpty) {
      return;
    }
    final first = widget.banners.first;
    final url = ImageUrlService.optimizeForDelivery(
      first.imageUrl,
      width: 1200,
      quality: 'good',
    );
    precacheImage(CachedNetworkImageProvider(url), context);
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
                return _BannerCard(
                  banner: banner,
                  onTap: () => widget.onBannerTap(banner),
                );
              },
              onPageChanged: (index) {
                context.read<BannerProvider>().setActiveIndex(
                  index % widget.banners.length,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        Consumer<BannerProvider>(
          builder: (context, provider, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.banners.length, (index) {
                final active = provider.activeIndex == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? AbzioTheme.accentColor
                        : context.abzioBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.onTap});

  final BannerModel banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.06),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.zero,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final dpr = MediaQuery.of(context).devicePixelRatio;
                  final targetHeight = constraints.maxHeight;
                  final targetWidth = constraints.maxWidth;
                  final memCacheHeight = (targetHeight * dpr).round();
                  final memCacheWidth = (targetWidth * dpr).round();
                  return CachedNetworkImage(
                    imageUrl: ImageUrlService.optimizeForDelivery(
                      banner.imageUrl,
                      width: memCacheWidth,
                      quality: 'good',
                    ),
                    fit: BoxFit.cover,
                    memCacheHeight: memCacheHeight,
                    memCacheWidth: memCacheWidth,
                    fadeInDuration: const Duration(milliseconds: 250),
                    placeholder: (context, url) => const ShimmerBox(),
                    errorWidget: (context, url, error) => Container(
                      color: Theme.of(context).cardColor,
                      alignment: Alignment.center,
                      child: Text(
                        banner.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
