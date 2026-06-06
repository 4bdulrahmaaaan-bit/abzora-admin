import 'package:flutter/material.dart';

import '../constants/text_constants.dart';
import 'brand_logo.dart';
import 'tap_scale.dart';

class HomeHeader extends StatelessWidget implements PreferredSizeWidget {
  const HomeHeader({
    super.key,
    required this.locationTitle,
    required this.onSearchTap,
    required this.onWishlistTap,
    required this.onCartTap,
    required this.onLocationTap,
    this.isScrolled = false,
  });

  final String locationTitle;
  final VoidCallback onSearchTap;
  final VoidCallback onWishlistTap;
  final VoidCallback onCartTap;
  final VoidCallback onLocationTap;
  final bool isScrolled;

  @override
  Size get preferredSize => const Size.fromHeight(82);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4ED),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE8DCC2).withValues(
              alpha: isScrolled ? 0.65 : 0.30,
            ),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isScrolled ? 0.035 : 0.012),
            blurRadius: isScrolled ? 12 : 8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const BrandLogo(
                size: 44,
                radius: 11,
                padding: EdgeInsets.zero,
                backgroundColor: Color(0xFF050505),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AbianzoText.brandName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        letterSpacing: -0.2,
                        color: const Color(0xFF121212),
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AbianzoText.brandTagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF7C7265),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              _HeaderIconButton(icon: Icons.search_rounded, onTap: onSearchTap),
              const SizedBox(width: 8),
              _HeaderIconButton(
                icon: Icons.favorite_border_rounded,
                onTap: onWishlistTap,
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(icon: Icons.shopping_bag_outlined, onTap: onCartTap),
            ],
          ),
          const SizedBox(height: 4),
          TapScale(
            scale: 0.985,
            onTap: onLocationTap,
            child: SizedBox(
              width: double.infinity,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Color(0xFFC2A15E),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      locationTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF171411),
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: const Color(0xFFC2A15E).withValues(alpha: isScrolled ? 0.9 : 0.72),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scale: 0.94,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Icon(
                icon,
                color: const Color(0xFF1E1B17),
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
