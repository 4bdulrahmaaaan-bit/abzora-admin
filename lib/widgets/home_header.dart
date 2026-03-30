import 'package:flutter/material.dart';

import '../constants/text_constants.dart';
import 'brand_logo.dart';
import 'tap_scale.dart';

class HomeHeader extends StatelessWidget implements PreferredSizeWidget {
  const HomeHeader({
    super.key,
    required this.onSearchTap,
    required this.onWishlistTap,
    required this.onCartTap,
  });

  final VoidCallback onSearchTap;
  final VoidCallback onWishlistTap;
  final VoidCallback onCartTap;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          const BrandLogo(size: 34, radius: 8),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AbzoraText.brandName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2),
              ),
              Text(
                AbzoraText.brandTagline,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        _HeaderIconButton(icon: Icons.search_rounded, onTap: onSearchTap),
        _HeaderIconButton(icon: Icons.favorite_border_rounded, onTap: onWishlistTap),
        _HeaderIconButton(icon: Icons.shopping_bag_outlined, onTap: onCartTap),
        const SizedBox(width: 8),
      ],
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
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: TapScale(
        onTap: onTap,
        scale: 0.92,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(99),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
