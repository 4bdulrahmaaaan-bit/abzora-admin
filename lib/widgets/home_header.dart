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
  Size get preferredSize => const Size.fromHeight(124);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: const Color(0xFFF8F8F8),
      elevation: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(color: Color(0xFFF8F8F8)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const BrandLogo(
                  size: 30,
                  radius: 8,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  shadows: [],
                  gradient: null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AbzoraText.brandName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          letterSpacing: 0.3,
                          color: const Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        AbzoraText.brandTagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF666666),
                          fontSize: 9,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.15,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
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
            const SizedBox(height: 8),
            AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              offset: const Offset(0, 0),
              child: _LocationBar(location: location, onTap: onLocationTap),
            ),
          ],
        ),
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
      scale: 0.92,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: Icon(icon, color: const Color(0xFF222222), size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationBar extends StatelessWidget {
  const _LocationBar({required this.location, required this.onTap});

  final String location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scale: 0.985,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE7E2D7)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: Color(0xFFC6A769),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: const Color(0xFF111111),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 64),
                    child: Text(
                      'Change',
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFC6A769),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
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
