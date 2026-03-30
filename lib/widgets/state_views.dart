import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(color: AbzioTheme.accentColor, strokeWidth: 2.2),
            ),
            const SizedBox(height: 18),
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: GoogleFonts.inter(color: context.abzioSecondaryText, height: 1.4),
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

  const AbzioEmptyCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.inter(color: context.abzioSecondaryText, height: 1.45),
            ),
            if (ctaLabel != null && onTap != null) ...[
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: onTap,
                child: Text(ctaLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AbzioNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? overlay;
  final String fallbackLabel;

  const AbzioNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.overlay,
    this.fallbackLabel = 'ABZORA',
  });

  @override
  Widget build(BuildContext context) {
    final overlayWidget = overlay;
    final overlayChildren = overlayWidget == null ? const <Widget>[] : <Widget>[overlayWidget];
    final child = Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: fit,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) {
              return child;
            }
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: child,
            );
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return child;
            }
            return const _AbzioImagePlaceholder();
          },
          errorBuilder: (context, error, stackTrace) => _AbzioImageFallback(
            label: fallbackLabel,
          ),
        ),
        ...overlayChildren,
      ],
    );

    if (borderRadius == null) {
      return child;
    }

    return ClipRRect(
      borderRadius: borderRadius!,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
            Theme.of(context).inputDecorationTheme.fillColor ?? Theme.of(context).cardColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AbzioTheme.accentColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.36)),
              ),
              child: Text(
                'PREMIUM EDIT',
                style: GoogleFonts.poppins(
                  color: AbzioTheme.accentColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
