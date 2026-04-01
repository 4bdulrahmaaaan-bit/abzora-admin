import 'package:flutter/material.dart';

import '../constants/text_constants.dart';
import 'brand_logo.dart';
import 'tap_scale.dart';

class HomeHeader extends StatelessWidget implements PreferredSizeWidget {
  const HomeHeader({
    super.key,
    required this.location,
    required this.onSearchTap,
    required this.onWishlistTap,
    required this.onCartTap,
    required this.onLocationTap,
    this.isScrolled = false,
  });

  final String location;
  final VoidCallback onSearchTap;
  final VoidCallback onWishlistTap;
  final VoidCallback onCartTap;
  final VoidCallback onLocationTap;
  final bool isScrolled;

  @override
  Size get preferredSize => Size.fromHeight(isScrolled ? 102 : 112);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      elevation: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(16, isScrolled ? 6 : 8, 16, isScrolled ? 8 : 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isScrolled ? 0.07 : 0.04),
              blurRadius: isScrolled ? 12 : 18,
              offset: Offset(0, isScrolled ? 3 : 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.all(isScrolled ? 3 : 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F3E8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: BrandLogo(size: isScrolled ? 30 : 34, radius: 8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AbzoraText.brandName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: isScrolled ? 18 : 19,
                                letterSpacing: 0.7,
                              ),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 180),
                                opacity: isScrolled ? 0 : 1,
                                child: isScrolled
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          AbzoraText.brandTagline,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.58),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HeaderIconButton(
                      icon: Icons.search_rounded,
                      onTap: onSearchTap,
                    ),
                    const SizedBox(width: 6),
                    _HeaderIconButton(
                      icon: Icons.favorite_border_rounded,
                      onTap: onWishlistTap,
                    ),
                    const SizedBox(width: 6),
                    _HeaderIconButton(
                      icon: Icons.shopping_bag_outlined,
                      onTap: onCartTap,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              offset: Offset(0, isScrolled ? -0.04 : 0),
              child: _LocationBar(
                location: location,
                onTap: onLocationTap,
                collapsed: isScrolled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scale: 0.92,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.all(10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.onSurface,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationBar extends StatelessWidget {
  const _LocationBar({
    required this.location,
    required this.onTap,
    this.collapsed = false,
  });

  final String location;
  final VoidCallback onTap;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scale: 0.985,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: collapsed ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F3),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: collapsed ? 0.015 : 0.02),
                  blurRadius: collapsed ? 6 : 10,
                  offset: Offset(0, collapsed ? 2 : 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: Color(0xFFC9A74E),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF202020),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
