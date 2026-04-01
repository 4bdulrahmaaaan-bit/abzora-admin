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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: context.abzioBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
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
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, height: 1.15),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.inter(color: context.abzioSecondaryText, height: 1.45),
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
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
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
