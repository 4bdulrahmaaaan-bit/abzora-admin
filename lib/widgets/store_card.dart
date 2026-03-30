import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../theme.dart';
import 'bouncy_button.dart';
import 'state_views.dart';

class StoreCard extends StatelessWidget {
  final Store store;
  final VoidCallback onTap;

  const StoreCard({
    super.key,
    required this.store,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BouncyButton(
      scaleLowerBound: 0.94,
      onPressed: onTap,
      child: Container(
        width: 84,
        margin: const EdgeInsets.only(right: 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: AbzioNetworkImage(
                  imageUrl: store.imageUrl.isNotEmpty ? store.imageUrl : 'https://via.placeholder.com/100?text=Store',
                  fallbackLabel: store.name,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              store.name.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: textTheme.bodyLarge?.color,
                letterSpacing: 1.0,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (store.tagline.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                store.tagline,
                style: GoogleFonts.inter(
                  color: context.abzioSecondaryText,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
