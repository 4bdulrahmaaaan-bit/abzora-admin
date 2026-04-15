import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/image_url_service.dart';
import '../theme.dart';
import 'shimmer_box.dart';

class AbzioLoadingView extends StatelessWidget {
  final String title;
  final String? subtitle;

  const AbzioLoadingView({
    super.key,
    this.title = 'Loading',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D8),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AbzioTheme.accentColor.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: AbzioTheme.accentColor,
                    strokeWidth: 2.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AbzioTheme.textPrimary,
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.abzioSecondaryText,
                      height: 1.4,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AbzioEmptyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onTap;
  final IconData illustrationIcon;

  const AbzioEmptyCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onTap,
    this.illustrationIcon = Icons.auto_awesome_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFFFFDF8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: context.abzioBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D8),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AbzioTheme.accentColor.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Icon(
                      Icons.star_rounded,
                      size: 12,
                      color: AbzioTheme.accentColor.withValues(alpha: 0.45),
                    ),
                  ),
                  Icon(
                    illustrationIcon,
                    color: AbzioTheme.accentColor,
                    size: 24,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: AbzioTheme.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.abzioSecondaryText,
                    height: 1.45,
                  ),
            ),
            if (ctaLabel != null && onTap != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AbzioTheme.accentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  ctaLabel!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AbzioNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? overlay;
  final String fallbackLabel;
  final bool priority;
  final int? maxWidth;
  final int? maxHeight;
  final String quality;

  const AbzioNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.overlay,
    this.fallbackLabel = 'ABZORA',
    this.priority = false,
    this.maxWidth,
    this.maxHeight,
    this.quality = 'eco',
  });

  @override
  State<AbzioNetworkImage> createState() => _AbzioNetworkImageState();
}

class _AbzioNetworkImageState extends State<AbzioNetworkImage> {
  String? _prefetchedUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.priority || widget.imageUrl.trim().isEmpty) {
      return;
    }
    final url = _optimizedUrl(widget.maxWidth ?? 1400);
    if (_prefetchedUrl == url) {
      return;
    }
    _prefetchedUrl = url;
    precacheImage(CachedNetworkImageProvider(url), context);
  }

  String _optimizedUrl(int width) {
    final quality = widget.priority ? 'good' : widget.quality;
    return ImageUrlService.optimizeForDelivery(
      widget.imageUrl,
      width: width,
      quality: quality,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.trim().isEmpty) {
      return _AbzioImageFallback(label: widget.fallbackLabel);
    }

    final overlayWidget = widget.overlay;
    final overlayChildren =
        overlayWidget == null ? const <Widget>[] : <Widget>[overlayWidget];

    final child = LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        int? cacheWidth;
        int? cacheHeight;
        if (constraints.hasBoundedWidth) {
          cacheWidth = (constraints.maxWidth * dpr).round();
        }
        if (constraints.hasBoundedHeight) {
          cacheHeight = (constraints.maxHeight * dpr).round();
        }
        if (widget.maxWidth != null) {
          cacheWidth =
              cacheWidth == null ? widget.maxWidth : math.min(cacheWidth, widget.maxWidth!);
        }
        if (widget.maxHeight != null) {
          cacheHeight = cacheHeight == null
              ? widget.maxHeight
              : math.min(cacheHeight, widget.maxHeight!);
        }
        final resolvedWidth = cacheWidth ?? widget.maxWidth ?? 1400;
        final url = _optimizedUrl(resolvedWidth);

        return Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: url,
              fit: widget.fit,
              memCacheWidth: cacheWidth,
              memCacheHeight: cacheHeight,
              useOldImageOnUrlChange: true,
              fadeInDuration: const Duration(milliseconds: 220),
              fadeOutDuration: const Duration(milliseconds: 140),
              placeholder: (context, url) => const _AbzioImagePlaceholder(),
              errorWidget: (context, url, error) => _AbzioImageFallback(
                label: widget.fallbackLabel,
              ),
            ),
            ...overlayChildren,
          ],
        );
      },
    );

    if (widget.borderRadius == null) {
      return child;
    }

    return ClipRRect(
      borderRadius: widget.borderRadius!,
      child: child,
    );
  }
}

class _AbzioImagePlaceholder extends StatelessWidget {
  const _AbzioImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ShimmerBox();
  }
}

class _AbzioImageFallback extends StatelessWidget {
  final String label;

  const _AbzioImageFallback({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = constraints.biggest.shortestSide;
        final compact = shortestSide < 64;
        final ultraCompact = shortestSide < 40;
        final iconSize = ultraCompact ? 14.0 : (compact ? 18.0 : 28.0);
        final labelText = label.trim().isEmpty ? 'ABZORA' : label.trim();

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surface.withValues(alpha: 0.92),
                theme.inputDecorationTheme.fillColor ?? theme.cardColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(ultraCompact ? 4 : (compact ? 8 : 16)),
              child: compact
                  ? Icon(
                      Icons.image_outlined,
                      size: iconSize,
                      color: AbzioTheme.accentColor.withValues(alpha: 0.78),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: iconSize,
                          color: AbzioTheme.accentColor.withValues(alpha: 0.82),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          labelText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
