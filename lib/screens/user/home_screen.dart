import 'dart:async';
import '../../widgets/product_shimmer.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/text_constants.dart';
import '../../models/category_management_model.dart';
import '../../models/banner_model.dart';
import '../../models/models.dart';
import '../../models/outfit_recommendation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/banner_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/backend_api_client.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../utils/soft_auth_gate.dart';
import '../../widgets/global_skeletons.dart';
import '../../widgets/home_header.dart';
import '../../widgets/product_card.dart';
import '../../widgets/product_grid.dart';
import '../../widgets/shimmer_box.dart';
import '../../widgets/state_views.dart';
import '../../widgets/tap_scale.dart';
import 'ai_stylist_screen.dart';
import 'location_bottom_sheet.dart';
import 'order_tracking_screen.dart';
import 'product_detail_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'store_detail_screen.dart';
import 'wishlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  static const String _hasUsedAiKey = 'abianzo_has_used_ai_stylist';
  late final List<Widget?> _lazyScreens = List<Widget?>.filled(4, null);

  bool _hasUsedAi = false;
  bool _isNavVisible = true;
  double _lastScrollOffset = 0;
  double _scrollDeltaAccumulator = 0;
  static const double _navToggleThreshold = 18;

  @override
  void initState() {
    super.initState();
    _restoreAiDiscoveryState();
  }
  Future<void> _restoreAiDiscoveryState() async {
    final prefs = await SharedPreferences.getInstance();
    final hasUsedAi = prefs.getBool(_hasUsedAiKey) ?? false;
    if (!mounted) {
      return;
    }
    setState(() {
      _hasUsedAi = hasUsedAi;
    });
  }

  Future<void> _markAiUsed() async {
    if (!_hasUsedAi) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasUsedAiKey, true);
      if (mounted) {
        setState(() {
          _hasUsedAi = true;
        });
      }
    }
  }

  Future<void> _openAiStylist() async {
    await _markAiUsed();
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiStylistScreen()),
    );
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) =>
              _handleScrollNotification(notification),
          child: HomeContent(onOpenAiStylist: _openAiStylist),
        );
      case 1:
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) =>
              _handleScrollNotification(notification),
          child: const CategoriesScreen(),
        );
      case 2:
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) =>
              _handleScrollNotification(notification),
          child: const OrderTrackingScreen(),
        );
      case 3:
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) =>
              _handleScrollNotification(notification),
          child: const ProfileScreen(),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth > 0) {
      return false;
    }

    final metrics = notification.metrics;
    if (metrics.pixels <= metrics.minScrollExtent + 0.5) {
      _resetNavVisibility();
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final offset = metrics.pixels;
      final delta = offset - _lastScrollOffset;
      _lastScrollOffset = offset;

      if (delta.abs() < 0.5) {
        return false;
      }

      _scrollDeltaAccumulator += delta;

      if (_scrollDeltaAccumulator >= _navToggleThreshold && _isNavVisible) {
        _setNavVisibility(false);
      } else if (_scrollDeltaAccumulator <= -_navToggleThreshold &&
          !_isNavVisible) {
        _setNavVisibility(true);
      }
    } else if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.forward) {
        _setNavVisibility(true);
      } else if (notification.direction == ScrollDirection.reverse &&
          metrics.pixels > metrics.minScrollExtent + 12) {
        _setNavVisibility(false);
      }
    }

    return false;
  }

  void _setNavVisibility(bool visible) {
    if (!mounted || _isNavVisible == visible) {
      return;
    }
    setState(() => _isNavVisible = visible);
    if (visible) {
      _scrollDeltaAccumulator = 0;
    } else {
      _scrollDeltaAccumulator = 0;
    }
  }

  void _resetNavVisibility() {
    _lastScrollOffset = 0;
    _scrollDeltaAccumulator = 0;
    if (!_isNavVisible && mounted) {
      setState(() => _isNavVisible = true);
    } else {
      _isNavVisible = true;
    }
  }

  List<Widget> _screens() {
    return List<Widget>.generate(_lazyScreens.length, (index) {
      if (index == _currentIndex) {
        return _lazyScreens[index] ??= _buildScreen(index);
      }
      return _lazyScreens[index] ?? const SizedBox.shrink();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navHeight =
        60.0 + (bottomInset > 0 ? bottomInset.clamp(0.0, 6.0) : 0.0);
    return AbzioThemeScope.light(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFF9F8F5), Color(0xFFF1EEE8)],
          ),
        ),
        child: Scaffold(
          extendBody: false,
          backgroundColor: Colors.transparent,
          body: IndexedStack(index: _currentIndex, children: _screens()),
          bottomNavigationBar: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _isNavVisible
                ? DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xFFFCFBF8),
                      border: Border(
                        top: BorderSide(color: Color(0xFFE6DFD1), width: 1),
                      ),
                    ),
                    child: SizedBox(
                      height: navHeight,
                      width: double.infinity,
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: bottomInset > 0 ? 4 : 0,
                        ),
                        child: Row(
                          children: [
                            _buildBottomNavItem(
                              index: 0,
                              icon: Icons.home_outlined,
                              selectedIcon: Icons.home_rounded,
                              label: 'Home',
                            ),
                            _buildBottomNavItem(
                              index: 1,
                              icon: Icons.category_outlined,
                              selectedIcon: Icons.category_rounded,
                              label: AbianzoText.customNavLabel,
                            ),
                            _buildBottomNavItem(
                              index: 2,
                              icon: Icons.receipt_long_outlined,
                              selectedIcon: Icons.receipt_long_rounded,
                              label: 'Orders',
                            ),
                            _buildBottomNavItem(
                              index: 3,
                              icon: Icons.person_outline_rounded,
                              selectedIcon: Icons.person_rounded,
                              label: 'Profile',
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final selected = _currentIndex == index;
    final activeColor = const Color(0xFFC9A45C);
    final inactiveColor = const Color(0xFF7A7A7A);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!mounted) {
              return;
            }
            setState(() {
              _currentIndex = index;
              _isNavVisible = true;
              _scrollDeltaAccumulator = 0;
              _lastScrollOffset = 0;
            });
          },
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 22,
                  color: selected ? activeColor : inactiveColor,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.0,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? activeColor : inactiveColor,
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

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _selectedCategory = 'View All';
  Future<_LuxuryCategoriesFeed>? _feedFuture;

  @override
  @override
  Widget build(BuildContext context) {
    final background = const Color(0xFFF9F7F2);

    return Scaffold(
      backgroundColor: background,
      body: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF9F7F2)),
        child: SafeArea(
          bottom: false,
          child: FutureBuilder<_LuxuryCategoriesFeed>(
            future: _feedFuture,
            builder: (context, snapshot) {
              final isLoading =
                  snapshot.connectionState != ConnectionState.done ||
                  !snapshot.hasData;
              final feed = snapshot.data ?? _LuxuryCategoriesFeed.curated();

              return Stack(
                children: [
                  Positioned(
                    top: -80,
                    right: -60,
                    child: IgnorePointer(
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFD9C6A3).withValues(alpha: 0.16),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 120,
                    left: -90,
                    child: IgnorePointer(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFB79A6C).withValues(alpha: 0.10),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  isLoading
                      ? _LuxuryCategoriesSkeleton(
                          selectedCategory: _selectedCategory,
                        )
                      : _LuxuryCategoriesContent(
                          feed: feed,
                          selectedCategory: _selectedCategory,
                          onCategorySelected: (category) {
                            setState(() => _selectedCategory = category);
                          },
                        ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LuxuryCategoriesContent extends StatelessWidget {
  const _LuxuryCategoriesContent({
    required this.feed,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final _LuxuryCategoriesFeed feed;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          sliver: SliverToBoxAdapter(
            child: _LuxuryHeader(selectedCategory: selectedCategory),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _LuxuryCategoryRail(
              categories: feed.categories,
              selectedCategory: selectedCategory,
              onCategorySelected: onCategorySelected,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _LuxurySectionTitle(
              overline: 'Featured collections',
              title: 'Editorial curation',
              subtitle:
                  'Luxury edits with a quieter, more considered point of view.',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          sliver: SliverToBoxAdapter(
            child: _LuxuryCollectionsSection(collections: feed.collections),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _LuxuryHeader extends StatelessWidget {
  const _LuxuryHeader({required this.selectedCategory});

  final String selectedCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = GoogleFonts.cormorantGaramond(
      fontSize: 46,
      height: 0.96,
      color: const Color(0xFF121212),
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Categories', style: titleStyle),
          const SizedBox(height: 12),
          Text(
            'A curated edit of fashion, beauty, and home essentials.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF5B5348),
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: Container(
              key: ValueKey(selectedCategory),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF8F2),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE5D8C6)),
              ),
              child: Text(
                selectedCategory == 'View All'
                    ? 'Browsing the full curated edit'
                    : 'Browsing $selectedCategory',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF252525),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LuxuryCategoryRail extends StatelessWidget {
  const _LuxuryCategoryRail({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final List<_CuratedCategory> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = screenWidth >= 900
        ? 260.0
        : screenWidth >= 600
        ? 238.0
        : 214.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LuxurySectionTitle(
          overline: 'Curated categories',
          title: 'Explore the edit',
          subtitle:
              'Only the categories that matter, presented with more breathing room.',
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 324,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            padding: const EdgeInsets.only(right: 4),
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected =
                  selectedCategory.toLowerCase() ==
                  category.label.toLowerCase();
              return _LuxuryCategoryCard(
                width: cardWidth,
                category: category,
                isSelected: isSelected,
                onTap: () => onCategorySelected(category.label),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LuxuryCollectionsSection extends StatelessWidget {
  const _LuxuryCollectionsSection({required this.collections});

  final List<_CuratedCollection> collections;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 700;

    if (isWide) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: collections.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: width >= 1050 ? 2 : 1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: width >= 1050 ? 1.72 : 2.0,
        ),
        itemBuilder: (context, index) {
          return _LuxuryEditorialBanner(collection: collections[index]);
        },
      );
    }

    return Column(
      children: [
        for (var i = 0; i < collections.length; i++) ...[
          _LuxuryEditorialBanner(collection: collections[i]),
          if (i != collections.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _LuxuryCategoryCard extends StatelessWidget {
  const _LuxuryCategoryCard({
    required this.width,
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final double width;
  final _CuratedCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? const Color(0xFFB8935A)
        : const Color(0xFFE8DDCF);
    final shadowColor = isSelected
        ? const Color(0xFFAA8851).withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.05);

    return TapScale(
      onTap: onTap,
      scale: isSelected ? 0.985 : 0.99,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AbzioNetworkImage(
                      imageUrl: category.imageUrl,
                      fallbackLabel: category.label,
                      fit: BoxFit.cover,
                      priority: true,
                      overlay: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.14),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (isSelected)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(
                              0xFFC8A96A,
                            ).withValues(alpha: 0.38),
                            width: 1.2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              category.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF171717),
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: isSelected ? 30 : 12,
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFFC8A96A),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LuxuryEditorialBanner extends StatelessWidget {
  const _LuxuryEditorialBanner({required this.collection});

  final _CuratedCollection collection;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      scale: 0.992,
      onTap: () {},
      child: Container(
        height: 224,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AbzioNetworkImage(
                imageUrl: collection.imageUrl,
                fallbackLabel: collection.title,
                fit: BoxFit.cover,
                priority: true,
                overlay: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.04),
                        Colors.black.withValues(alpha: 0.30),
                        Colors.black.withValues(alpha: 0.62),
                      ],
                      stops: const [0.0, 0.58, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Text(
                        collection.eyebrow.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      collection.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 30,
                        height: 0.94,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      collection.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LuxurySectionTitle extends StatelessWidget {
  const _LuxurySectionTitle({
    required this.overline,
    required this.title,
    required this.subtitle,
  });

  final String overline;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          overline.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF8C7A63),
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 30,
            height: 0.98,
            color: const Color(0xFF131313),
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF63594B),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _LuxuryCategoriesSkeleton extends StatelessWidget {
  const _LuxuryCategoriesSkeleton({required this.selectedCategory});

  final String selectedCategory;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = width >= 900
        ? 260.0
        : width >= 600
        ? 238.0
        : 214.0;

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: _LuxuryHeader(selectedCategory: selectedCategory),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _LuxurySectionTitle(
                overline: 'Curated categories',
                title: 'Explore the edit',
                subtitle:
                    'Only the categories that matter, presented with more breathing room.',
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 324,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: 4,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    return Container(
                      width: cardWidth,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFDF9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE8DDCF)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Column(
                        children: [
                          Expanded(
                            child: ShimmerBox(
                              width: double.infinity,
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                            ),
                          ),
                          SizedBox(height: 14),
                          ShimmerBox(
                            width: 120,
                            height: 14,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          SizedBox(height: 6),
                          ShimmerBox(
                            width: 32,
                            height: 2,
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
              const _LuxurySectionTitle(
                overline: 'Featured collections',
                title: 'Editorial curation',
                subtitle:
                    'Luxury edits with a quieter, more considered point of view.',
              ),
              const SizedBox(height: 18),
              Column(
                children: List.generate(
                  5,
                  (index) => Padding(
                    padding: EdgeInsets.only(bottom: index == 4 ? 0 : 16),
                    child: const ShimmerCard(
                      height: 176,
                      padding: EdgeInsets.all(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LuxuryCategoriesFeed {
  const _LuxuryCategoriesFeed({
    required this.categories,
    required this.collections,
  });

  final List<_CuratedCategory> categories;
  final List<_CuratedCollection> collections;

  List<String> get preloadImageUrls => [
    ...categories.map((item) => item.imageUrl),
    ...collections.map((item) => item.imageUrl),
  ];

  factory _LuxuryCategoriesFeed.curated() {
    return const _LuxuryCategoriesFeed(
      categories: [
        _CuratedCategory(
          label: 'Men',
          imageUrl:
              'https://images.unsplash.com/photo-1516826957135-700dedea698c?auto=format&fit=crop&q=80&w=1200',
        ),
        _CuratedCategory(
          label: 'Women',
          imageUrl:
              'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&q=80&w=1200',
        ),
        _CuratedCategory(
          label: 'Footwear',
          imageUrl:
              'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&q=80&w=1200',
        ),
        _CuratedCategory(
          label: 'Accessories',
          imageUrl:
              'https://images.unsplash.com/photo-1523398002811-999ca8dec234?auto=format&fit=crop&q=80&w=1200',
        ),
        _CuratedCategory(
          label: 'Beauty',
          imageUrl:
              'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&q=80&w=1200',
        ),
        _CuratedCategory(
          label: 'Wedding & Occasion',
          imageUrl:
              'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&q=80&w=1200',
        ),
        _CuratedCategory(
          label: 'Home & Living',
          imageUrl:
              'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&q=80&w=1200',
        ),
        _CuratedCategory(
          label: 'View All',
          imageUrl:
              'https://images.unsplash.com/photo-1496747611176-843222e1e57c?auto=format&fit=crop&q=80&w=1200',
        ),
      ],
      collections: [
        _CuratedCollection(
          eyebrow: 'Luxury picks',
          title: 'Luxury Picks',
          subtitle:
              'Tailored essentials, refined textures, and timeless accessories.',
          imageUrl:
              'https://images.unsplash.com/photo-1496747611176-843222e1e57c?auto=format&fit=crop&q=80&w=1400',
        ),
        _CuratedCollection(
          eyebrow: 'New arrivals',
          title: 'New Arrivals',
          subtitle:
              'Fresh silhouettes and elevated staples for the season ahead.',
          imageUrl:
              'https://images.unsplash.com/photo-1496747612613-4cf98b9d8a33?auto=format&fit=crop&q=80&w=1400',
        ),
        _CuratedCollection(
          eyebrow: 'Summer edit',
          title: 'Summer Edit',
          subtitle:
              'Linen, lightness, and understated ease in warm neutral tones.',
          imageUrl:
              'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&q=80&w=1400',
        ),
        _CuratedCollection(
          eyebrow: 'Wedding collection',
          title: 'Wedding Collection',
          subtitle:
              'Ceremony-ready looks with quiet drama and polished detail.',
          imageUrl:
              'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&q=80&w=1400',
        ),
        _CuratedCollection(
          eyebrow: 'Trending now',
          title: 'Trending Now',
          subtitle:
              'The pieces defining the mood of the moment, curated softly.',
          imageUrl:
              'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&q=80&w=1400',
        ),
      ],
    );
  }
}

class _CuratedCategory {
  const _CuratedCategory({required this.label, required this.imageUrl});

  final String label;
  final String imageUrl;
}

class _CuratedCollection {
  const _CuratedCollection({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String imageUrl;
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key, required this.onOpenAiStylist});

  final VoidCallback onOpenAiStylist;

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  bool _isHeaderScrolled = false;
  Timer? _loadMoreThrottle;
  String _selectedCategory = 'View All';

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) {
        return;
      }
      final shouldCompressHeader = _scrollController.offset > 18;
      if (shouldCompressHeader != _isHeaderScrolled && mounted) {
        setState(() => _isHeaderScrolled = shouldCompressHeader);
      }
      final max = _scrollController.position.maxScrollExtent;
      if (_scrollController.position.pixels > max - 380) {
        if (_loadMoreThrottle?.isActive ?? false) {
          return;
        }
        _loadMoreThrottle = Timer(const Duration(milliseconds: 280), () {
          if (!mounted) {
            return;
          }
          context.read<ProductProvider>().loadMoreLocationProducts();
        });
      }
    });
  }

  @override
  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _loadMoreThrottle?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<Product> _filterProductsForCategory(List<Product> products) {
    final normalized = _selectedCategory.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'view all') {
      return products;
    }

    final keywords = switch (normalized) {
      'men' => const [
        'men',
        'male',
        'mens',
        'shirt',
        'suit',
        'blazer',
        'kurta',
        'trouser',
        'jacket',
      ],
      'women' => const [
        'women',
        'female',
        'ladies',
        'dress',
        'saree',
        'kurti',
        'top',
        'skirt',
        'gown',
      ],
      'wedding' => const [
        'wedding',
        'bridal',
        'ceremony',
        'occasion',
        'lehenga',
        'sherwani',
        'tuxedo',
        'ethnic',
      ],
      'footwear' => const [
        'footwear',
        'shoe',
        'shoes',
        'sneaker',
        'sneakers',
        'loafer',
        'heel',
        'heels',
        'sandal',
        'boot',
      ],
      'beauty' => const [
        'beauty',
        'makeup',
        'skincare',
        'perfume',
        'fragrance',
        'cosmetic',
        'cosmetics',
      ],
      'accessories' => const [
        'accessory',
        'accessories',
        'watch',
        'bag',
        'belt',
        'jewelry',
        'jewellery',
        'sunglass',
      ],
      _ => const <String>[],
    };

    if (keywords.isEmpty) {
      return products;
    }

    final filtered = products.where((product) {
      final haystack =
          '${product.name} ${product.description} ${product.category} ${product.subcategory}'
              .toLowerCase();
      return keywords.any(haystack.contains);
    }).toList();

    return filtered.isEmpty ? products : filtered;
  }

  String _selectedCategoryTitle() {
    final normalized = _selectedCategory.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'view all') {
      return 'All curated picks';
    }
    return 'Best of $_selectedCategory';
  }

  String _selectedCategorySubtitle() {
    final normalized = _selectedCategory.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'view all') {
      return 'Popular pieces across the full Abianzo edit';
    }
    return 'Curated luxury pieces for $_selectedCategory';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = context.read<AuthProvider>();

    return Consumer2<ProductProvider, LocationProvider>(
      builder: (context, provider, locationProvider, child) {
        final products = provider.searchResults.isNotEmpty
            ? provider.searchResults
            : provider.locationProducts;
        final stores = provider.nearbyStores;
        final banners = context.select<BannerProvider, List<BannerModel>>(
          (bannerProvider) => bannerProvider.banners,
        );
        final headerCopy = locationProvider.hasResolvedLocation
            ? locationProvider.deliveryHeaderCopy('')
            : const DeliveryHeaderCopy(
                title: AbianzoText.locationLoggedOutTitle,
                subtitle: AbianzoText.locationLoggedOutSubtitle,
              );
        final filteredProducts = _filterProductsForCategory(products);
        final trendingProducts = filteredProducts.take(4).toList();
        final justForYouProducts = filteredProducts.skip(4).take(4).toList();
        final trendingSubtitle = _selectedCategory == 'View All'
            ? 'Popular picks from nearby stores'
            : 'Popular $_selectedCategory picks from nearby stores';
        final justForYouSubtitle = _selectedCategory == 'View All'
            ? 'Based on your style'
            : 'More $_selectedCategory inspired finds';
        final storesSection = _buildStoresSection(
          context,
          provider: provider,
          stores: stores,
          products: filteredProducts,
        );

        return SafeArea(
          top: true,
          bottom: false,
          child: Scaffold(
            backgroundColor: const Color(0xFFF8F8F8),
            appBar: HomeHeader(
              locationTitle: headerCopy.title,
              isScrolled: _isHeaderScrolled,
              onSearchTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchScreen(
                    allProducts: products,
                    selectedLocation: provider.activeLocation,
                  ),
                ),
              ),
              onWishlistTap: () async {
                final allowed = await SoftAuthGate.ensureAuthenticated(
                  context,
                  intentLabel: 'Open wishlist',
                  trigger: AuthPromptTrigger.wishlist,
                  promptStyle: AuthPromptStyle.softSheet,
                );
                if (!allowed || !context.mounted) {
                  return;
                }
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WishlistScreen()),
                );
              },
              onCartTap: () => Navigator.pushNamed(context, '/cart'),
              onLocationTap: () => showLocationBottomSheet(context),
            ),
            body: provider.isLoading && products.isEmpty
                ? const GlobalHomeSkeleton()
                : RefreshIndicator(
                    onRefresh: () => provider.fetchHomeData(
                      forceLocationRefresh: true,
                      user: auth.user,
                    ),
                    color: AbzioTheme.accentColor,
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        controller: _scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: HomeBanner(
                              fallbackBanners: banners,
                              onBannerTap: (banner) => _handleBannerTap(
                                banner,
                                products: products,
                                stores: stores,
                                selectedLocation: provider.activeLocation,
                              ),
                            ),
                          ),
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _CategoryTabsHeaderDelegate(
                              selectedTab: _resolveHomeCategoryTab(
                                _selectedCategory,
                              ),
                              onCategorySelected: (category) {
                                setState(() => _selectedCategory = category);
                              },
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                              child: CategorySection(
                                selectedCategory: _selectedCategory,
                                onCategorySelected: (category) {
                                  setState(() => _selectedCategory = category);
                                },
                              ),
                            ),
                          ),
                          if (products.isEmpty)
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: AbzioEmptyCard(
                                  title: AbianzoText.homeEmptyTitle,
                                  subtitle: AbianzoText.homeEmptySubtitle,
                                  ctaLabel: AbianzoText.homeEmptyCta,
                                  onTap: () => provider.fetchHomeData(
                                    forceLocationRefresh: true,
                                    user: auth.user,
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  104,
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 280),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: Column(
                                    key: ValueKey(_selectedCategory),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _sectionHeader(
                                        title: _selectedCategoryTitle(),
                                        subtitle: _selectedCategorySubtitle(),
                                      ),
                                      const SizedBox(height: 18),
                                      _productSection(
                                        context,
                                        title: AbianzoText.trendingNearYouTitle,
                                        subtitle: trendingSubtitle,
                                        products: trendingProducts,
                                      ),
                                      const SizedBox(height: 24),
                                      _productSection(
                                        context,
                                        title: AbianzoText.justForYouTitle,
                                        subtitle: justForYouSubtitle,
                                        products: justForYouProducts.isEmpty
                                            ? trendingProducts
                                            : justForYouProducts,
                                      ),
                                      const SizedBox(height: 24),
                                      storesSection,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: provider.isLoadingMore
                                  ? const Padding(
                                      key: ValueKey('loading-more-products'),
                                      padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
                                      child: ProductShimmer(
                                        itemCount: 4,
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(),
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('loading-more-empty'),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  void _handleBannerTap(
    BannerModel banner, {
    required List<Product> products,
    required List<NearbyStore> stores,
    required String selectedLocation,
  }) {
    switch (banner.redirectType) {
      case 'product':
        final product = products.cast<Product?>().firstWhere(
          (item) => item?.id == banner.redirectId,
          orElse: () => null,
        );
        if (product != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SearchScreen(
              allProducts: products,
              selectedLocation: selectedLocation,
              initialQuery: banner.redirectId,
            ),
          ),
        );
        return;
      case 'store':
        final store = stores.cast<NearbyStore?>().firstWhere(
          (item) => banner.redirectId.isNotEmpty
              ? item?.store.id == banner.redirectId
              : true,
          orElse: () => null,
        );
        if (store != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoreDetailScreen(store: store.store),
            ),
          );
        } else {
          showLocationBottomSheet(context);
        }
        return;
      case 'category':
      default:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SearchScreen(
              allProducts: products,
              selectedLocation: selectedLocation,
              initialQuery: banner.redirectId,
            ),
          ),
        );
    }
  }

  Widget _buildStoresSection(
    BuildContext context, {
    required ProductProvider provider,
    required List<NearbyStore> stores,
    required List<Product> products,
  }) {
    final fallbackProducts = products.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: AbianzoText.storesNearYou,
          subtitle: AbianzoText.locationSubtext,
        ),
        const SizedBox(height: 12),
        if (provider.isLocationLoading)
          const _StoreSkeletonList()
        else if (stores.isEmpty)
          _storesFallbackSection(
            context,
            provider: provider,
            products: fallbackProducts,
          )
        else
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: stores.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _storeCard(
                nearby: stores[index],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StoreDetailScreen(store: stores[index].store),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileSetupSheet extends StatefulWidget {
  const _ProfileSetupSheet({
    required this.auth,
    required this.nameController,
    required this.addressController,
    required this.onUseCurrentLocation,
    required this.onSave,
  });

  final AuthProvider auth;
  final TextEditingController nameController;
  final TextEditingController addressController;
  final Future<void> Function() onUseCurrentLocation;
  final Future<void> Function() onSave;

  @override
  State<_ProfileSetupSheet> createState() => _ProfileSetupSheetState();
}

class _ProfileSetupSheetState extends State<_ProfileSetupSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _fieldSlide;
  late final Animation<double> _buttonOpacity;
  late final FocusNode _nameFocusNode;
  late final FocusNode _addressFocusNode;

  @override
  void initState() {
    super.initState();
    _nameFocusNode = FocusNode()..addListener(_handleStateChange);
    _addressFocusNode = FocusNode()..addListener(_handleStateChange);
    widget.nameController.addListener(_handleStateChange);
    widget.addressController.addListener(_handleStateChange);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();
    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    );
    _fieldSlide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.12, 0.72, curve: Curves.easeOutCubic),
          ),
        );
    _buttonOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 1.0, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    widget.nameController.removeListener(_handleStateChange);
    widget.addressController.removeListener(_handleStateChange);
    _nameFocusNode
      ..removeListener(_handleStateChange)
      ..dispose();
    _addressFocusNode
      ..removeListener(_handleStateChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleStateChange() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _isFormValid {
    return widget.nameController.text.trim().isNotEmpty &&
        widget.addressController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.2)),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: DraggableScrollableSheet(
                initialChildSize: 0.7,
                minChildSize: 0.7,
                maxChildSize: 0.9,
                expand: false,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBF4),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 30,
                          offset: const Offset(0, -12),
                        ),
                      ],
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4D0C7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FadeTransition(
                          opacity: _titleOpacity,
                          child: Column(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFE5BF5D),
                                      Color(0xFFC69222),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AbzioTheme.accentColor.withValues(
                                        alpha: 0.28,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.content_cut_rounded,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Complete your profile for perfect fit \u2728',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'We\'ll use this to personalize your fit and delivery',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: context.abzioSecondaryText,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SlideTransition(
                          position: _fieldSlide,
                          child: Column(
                            children: [
                              _premiumField(
                                controller: widget.nameController,
                                focusNode: _nameFocusNode,
                                label: AbianzoText.profileSetupNameLabel,
                                icon: Icons.person_outline_rounded,
                              ),
                              const SizedBox(height: 14),
                              _premiumField(
                                controller: widget.addressController,
                                focusNode: _addressFocusNode,
                                label: AbianzoText.profileSetupAddressLabel,
                                icon: Icons.location_on_outlined,
                                maxLines: 3,
                                helper: 'Auto-detected via GPS',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        FadeTransition(
                          opacity: _buttonOpacity,
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: TapScale(
                                  onTap: widget.auth.isUpdatingProfile
                                      ? null
                                      : widget.onSave,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFD9B14D),
                                          Color(0xFFBF8E22),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AbzioTheme.accentColor
                                              .withValues(alpha: 0.26),
                                          blurRadius: 18,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed:
                                          (!widget.auth.isUpdatingProfile &&
                                              _isFormValid)
                                          ? widget.onSave
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: widget.auth.isUpdatingProfile
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                          : const Text(
                                              'Save & Continue',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: TapScale(
                                  onTap: widget.auth.isUpdatingProfile
                                      ? null
                                      : widget.onUseCurrentLocation,
                                  child: OutlinedButton(
                                    onPressed: widget.auth.isUpdatingProfile
                                        ? null
                                        : widget.onUseCurrentLocation,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      side: BorderSide(
                                        color: AbzioTheme.accentColor
                                            .withValues(alpha: 0.34),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: widget.auth.isUpdatingProfile
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Use Current Location'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? helper,
  }) {
    final isFocused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: AbzioTheme.accentColor.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(icon, color: AbzioTheme.accentColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AbzioTheme.accentColor,
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
Widget _aiStylistHighlight({required VoidCallback onTap}) {
  return Builder(
    builder: (context) => TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF8E6), Colors.white],
          ),
          border: Border.all(
            color: AbzioTheme.accentColor.withValues(alpha: 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: AbzioTheme.accentColor.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2C7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AbzioTheme.accentColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'AI Powered',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AbzioTheme.accentColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try AI Stylist \u2728',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Get outfit ideas, perfect fit, and styling advice instantly',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.abzioSecondaryText,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.arrow_forward_rounded,
              color: AbzioTheme.accentColor,
            ),
          ],
        ),
      ),
    ),
  );
}

// ignore: unused_element
Widget _compactAiStylistCard({required VoidCallback onTap}) {
  return Builder(
    builder: (context) => TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AbzioTheme.accentColor.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AbzioTheme.accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Stylist',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Instant outfit ideas and fit help',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.abzioSecondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: AbzioTheme.accentColor,
            ),
          ],
        ),
      ),
    ),
  );
}

// ignore: unused_element
class _AiStylistFloatingButton extends StatelessWidget {
  const _AiStylistFloatingButton({
    required this.animation,
    required this.showTooltip,
    required this.onTooltipDismissed,
    required this.onTap,
  });

  final Animation<double> animation;
  final bool showTooltip;
  final VoidCallback onTooltipDismissed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showTooltip)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: onTooltipDismissed,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 220),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  'Try AI Stylist for perfect outfit \uD83D\uDD25',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final glow = 0.16 + (animation.value * 0.12);
            final scale = 1 + (animation.value * 0.032);
            return Transform.scale(
              scale: scale,
              child: TapScale(
                onTap: onTap,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8C65C), AbzioTheme.accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AbzioTheme.accentColor.withValues(alpha: glow),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.black,
                    size: 26,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class CategorySection extends StatefulWidget {
  const CategorySection({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection> {
  late final Future<_CategoryRailData> _categoryRailFuture;

  @override
  void initState() {
    super.initState();
    _categoryRailFuture = Future.value(const _CategoryRailData());
  }

  List<_CategoryStripItem> _itemsForTab(_CategoryRailData data, String tab) {
    final remoteImagesByLabel = <String, String>{
      for (final visual in data.visuals.categoryVisuals)
        if (visual.isActive && visual.imageUrl.trim().isNotEmpty)
          visual.label.trim().toLowerCase(): visual.imageUrl.trim(),
      for (final category in data.categories)
        if (category.isActive &&
            category.showOnHome &&
            (category.image.trim().isNotEmpty ||
                category.bannerImage.trim().isNotEmpty))
          category.name.trim().toLowerCase(): category.image.trim().isNotEmpty
              ? category.image.trim()
              : category.bannerImage.trim(),
    };

    final fallbacks = <String, List<String>>{
      'Men': ['Shirts', 'T-Shirts', 'Jeans', 'Footwear', 'Watches'],
      'Women': ['Dresses', 'Ethnic', 'Heels', 'Bags', 'Beauty'],
      'Kids': ['Boys', 'Girls', 'Infants', 'School', 'Footwear'],
      'Wedding': ['Bride', 'Groom', 'Jewellery', 'Footwear', 'Accessories'],
      'Luxury': ['Designer Wear', 'Watches', 'Bags', 'Jewellery', 'Beauty'],
    };
    const defaultImages = <String, String>{
      'Shirts':
          'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?auto=format&fit=crop&q=80&w=900',
      'T-Shirts':
          'https://images.unsplash.com/photo-1523398002811-999ca8dec234?auto=format&fit=crop&q=80&w=900',
      'Jeans':
          'https://images.unsplash.com/photo-1542272604-787c3835535d?auto=format&fit=crop&q=80&w=900',
      'Footwear':
          'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&q=80&w=900',
      'Watches':
          'https://images.unsplash.com/photo-1523170335258-f5ed11844a49?auto=format&fit=crop&q=80&w=900',
      'Dresses':
          'https://images.unsplash.com/photo-1496747611176-843222e1e57c?auto=format&fit=crop&q=80&w=900',
      'Ethnic':
          'https://images.unsplash.com/photo-1509631179647-0177331693ae?auto=format&fit=crop&q=80&w=900',
      'Heels':
          'https://images.unsplash.com/photo-1515347619252-60a4bf4fff4f?auto=format&fit=crop&q=80&w=900',
      'Bags':
          'https://images.unsplash.com/photo-1584917865442-de89df76afd3?auto=format&fit=crop&q=80&w=900',
      'Beauty':
          'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?auto=format&fit=crop&q=80&w=900',
      'Jewellery':
          'https://images.unsplash.com/photo-1617038220319-276d3cfab638?auto=format&fit=crop&q=80&w=900',
      'Boys':
          'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&q=80&w=900',
      'Girls':
          'https://images.unsplash.com/photo-1450297166380-c1f5a7b3f9f1?auto=format&fit=crop&q=80&w=900',
      'Infants':
          'https://images.unsplash.com/photo-1515488042361-ee00e0ddd4e4?auto=format&fit=crop&q=80&w=900',
      'School':
          'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?auto=format&fit=crop&q=80&w=900',
      'Bride':
          'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&q=80&w=900',
      'Groom':
          'https://images.unsplash.com/photo-1515169067868-5387ec356754?auto=format&fit=crop&q=80&w=900',
      'Accessories':
          'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&q=80&w=900',
      'Designer Wear':
          'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&q=80&w=900',
      'Designer':
          'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&q=80&w=900',
      'Premium Watches':
          'https://images.unsplash.com/photo-1524592094714-0f0654e20314?auto=format&fit=crop&q=80&w=900',
      'Fine Jewellery':
          'https://images.unsplash.com/photo-1617038220319-276d3cfab638?auto=format&fit=crop&q=80&w=900',
    };

    final labels = fallbacks[tab] ?? fallbacks['Men']!;
    return labels
        .map(
          (label) => _CategoryStripItem(
            label: label,
            imageUrl:
                remoteImagesByLabel[label.toLowerCase()] ??
                defaultImages[label] ??
                defaultImages['Shirts']!,
          ),
        )
        .toList(growable: false);
  }

  List<_CategoryCollectionStripItem> _collectionsForTab(String tab) {
    const fallback = <_CategoryCollectionStripItem>[
      _CategoryCollectionStripItem(
        label: 'Explore',
        imageUrl:
            'https://images.unsplash.com/photo-1496747611176-843222e1e57c?auto=format&fit=crop&q=80&w=900',
      ),
      _CategoryCollectionStripItem(
        label: 'Essentials',
        imageUrl:
            'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&q=80&w=900',
      ),
      _CategoryCollectionStripItem(
        label: 'Editors',
        imageUrl:
            'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&q=80&w=900',
      ),
      _CategoryCollectionStripItem(
        label: 'New In',
        imageUrl:
            'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&q=80&w=900',
      ),
    ];

    final map = <String, List<_CategoryCollectionStripItem>>{
      'Men': [
        _CategoryCollectionStripItem(
          label: 'Shirts',
          imageUrl:
              'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?auto=format&fit=crop&q=80&w=900',
        ),
        _CategoryCollectionStripItem(
          label: 'Jeans',
          imageUrl:
              'https://images.unsplash.com/photo-1542272604-787c3835535d?auto=format&fit=crop&q=80&w=900',
        ),
        _CategoryCollectionStripItem(
          label: 'Sneakers',
          imageUrl:
              'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&q=80&w=900',
        ),
        _CategoryCollectionStripItem(
          label: 'Watches',
          imageUrl:
              'https://images.unsplash.com/photo-1523170335258-f5ed11844a49?auto=format&fit=crop&q=80&w=900',
        ),
      ],
      'Women': [
        _CategoryCollectionStripItem(
          label: 'Dresses',
          imageUrl:
              'https://images.unsplash.com/photo-1496747611176-843222e1e57c?auto=format&fit=crop&q=80&w=900',
        ),
        _CategoryCollectionStripItem(
          label: 'Bags',
          imageUrl:
              'https://images.unsplash.com/photo-1584917865442-de89df76afd3?auto=format&fit=crop&q=80&w=900',
        ),
        _CategoryCollectionStripItem(
          label: 'Beauty',
          imageUrl:
              'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?auto=format&fit=crop&q=80&w=900',
        ),
        _CategoryCollectionStripItem(
          label: 'Heels',
          imageUrl:
              'https://images.unsplash.com/photo-1515347619252-60a4bf4fff4f?auto=format&fit=crop&q=80&w=900',
        ),
      ],
      'Kids': [
        _CategoryCollectionStripItem(
          label: 'Boys',
          imageUrl:
              'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&q=80&w=900',
        ),
        _CategoryCollectionStripItem(
          label: 'Girls',
          imageUrl:
              'https://images.unsplash.com/photo-1450297166380-c1f5a7b3f9f1?auto=format&fit=crop&q=80&w=900',
        ),
        _CategoryCollectionStripItem(
          label: 'Footwear',
          imageUrl:
              'https://images.unsplash.com/photo-1543163521-1bf539c55dd2?auto=format&fit=crop&q=80&w=900',
        ),
        _CategoryCollectionStripItem(
          label: 'Toys',
          imageUrl:
              'https://images.unsplash.com/photo-1515488042361-ee00e0ddd4e4?auto=format&fit=crop&q=80&w=900',
        ),
      ],
      'Wedding': [
        _CategoryCollectionStripItem(
          label: 'Bridewear',
          imageUrl:
              'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&q=80&w=900',
        ),
        _CategoryCollectionStripItem(
          label: 'Sherwani',
          imageUrl:
              'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&q=80&w=900',
        ),
        _CategoryCollectionStripItem(
          label: 'Jewellery',
          imageUrl:
              'https://images.unsplash.com/photo-1617038220319-276d3cfab638?auto=format&fit=crop&q=80&w=900',
        ),
        _CategoryCollectionStripItem(
          label: 'Accessories',
          imageUrl:
              'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&q=80&w=900',
        ),
      ],
      'Luxury': [
        _CategoryCollectionStripItem(
          label: 'Designer',
          imageUrl:
              'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&q=80&w=900',
        ),
        _CategoryCollectionStripItem(
          label: 'Watches',
          imageUrl:
              'https://images.unsplash.com/photo-1524592094714-0f0654e20314?auto=format&fit=crop&q=80&w=900',
        ),
        _CategoryCollectionStripItem(
          label: 'Beauty',
          imageUrl:
              'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?auto=format&fit=crop&q=80&w=900',
        ),
        _CategoryCollectionStripItem(
          label: 'Handbags',
          imageUrl:
              'https://images.unsplash.com/photo-1584917865442-de89df76afd3?auto=format&fit=crop&q=80&w=900',
        ),
      ],
    };

    return map[tab] ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CategoryRailData>(
      future: _categoryRailFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const _CategoryRailData();
        final parentTab = _resolveHomeCategoryTab(widget.selectedCategory);
        final items = _itemsForTab(data, parentTab);
        final collections = _collectionsForTab(parentTab);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: SizedBox(
                key: ValueKey<String>(parentTab),
                height: 108,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _CategoryStripTile(
                      item: item,
                      isSelected:
                          widget.selectedCategory.toLowerCase() ==
                          item.label.toLowerCase(),
                      onTap: () {
                        widget.onCategorySelected(item.label);
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            _CategoryCollectionStrip(
              title: _collectionTitleForTab(parentTab),
              subtitle: _collectionSubtitleForTab(parentTab),
              items: collections,
            ),
          ],
        );
      },
    );
  }
}

class _CategoryRailData {
  const _CategoryRailData()
      : categories = const [],
        visuals = const HomeVisualConfigModel();

  final List<CategoryManagementModel> categories;
  final HomeVisualConfigModel visuals;
}

class _CategoryStripItem {
  const _CategoryStripItem({required this.label, required this.imageUrl});

  final String label;
  final String imageUrl;
}

class _CategoryStripTile extends StatelessWidget {
  const _CategoryStripTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _CategoryStripItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      scale: isSelected ? 1.04 : 0.985,
      onTap: onTap,
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            SizedBox(
              width: 88,
              height: 88,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AbzioNetworkImage(
                      imageUrl: item.imageUrl,
                      fallbackLabel: item.label,
                      fit: BoxFit.cover,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.22),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: isSelected
                            ? Border.all(
                                color: const Color(0xFFC8A86B),
                                width: 2,
                              )
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFFC8A86B,
                                  ).withValues(alpha: 0.16),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 17,
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1B1B1B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _resolveHomeCategoryTab(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return 'Men';
  }
  const directTabs = <String>['men', 'women', 'kids', 'wedding', 'luxury'];
  if (directTabs.contains(normalized)) {
    return normalized.substring(0, 1).toUpperCase() + normalized.substring(1);
  }
  const mapped = <String, String>{
    'shirts': 'Men',
    't-shirts': 'Men',
    'jeans': 'Men',
    'footwear': 'Men',
    'watches': 'Men',
    'tailoring': 'Men',
    'dresses': 'Women',
    'ethnic': 'Women',
    'heels': 'Women',
    'bags': 'Women',
    'beauty': 'Women',
    'jewellery': 'Women',
    'boys': 'Kids',
    'girls': 'Kids',
    'infants': 'Kids',
    'school': 'Kids',
    'toys': 'Kids',
    'bride': 'Wedding',
    'groom': 'Wedding',
    'accessories': 'Wedding',
    'bridewear': 'Wedding',
    'sherwani': 'Wedding',
    'designer wear': 'Luxury',
    'designer': 'Luxury',
    'premium watches': 'Luxury',
    'leather goods': 'Luxury',
    'luxury shoes': 'Luxury',
    'fine jewellery': 'Luxury',
    'custom made': 'Luxury',
    'handbags': 'Luxury',
  };
  return mapped[normalized] ?? 'Men';
}

String _collectionTitleForTab(String tab) {
  return switch (tab) {
    'Men' => 'Essentials for Everyday',
    'Women' => 'Trending Women\'s Picks',
    'Kids' => 'Playful Premium Picks',
    'Wedding' => 'Wedding Season Edits',
    'Luxury' => 'Curated Luxury',
    _ => 'Essentials for Everyday',
  };
}

String _collectionSubtitleForTab(String tab) {
  return switch (tab) {
    'Men' => 'Tailored, refined, and easy to shop.',
    'Women' => 'Elevated edits with a fashion-first lens.',
    'Kids' => 'Lifestyle picks for every little moment.',
    'Wedding' => 'Ceremony-ready pieces with quiet drama.',
    'Luxury' => 'Minimal, modern, and distinctly premium.',
    _ => 'Tailored, refined, and easy to shop.',
  };
}

class _CategoryCollectionStripItem {
  const _CategoryCollectionStripItem({
    required this.label,
    required this.imageUrl,
  });

  final String label;
  final String imageUrl;
}

class _CategoryCollectionStrip extends StatelessWidget {
  const _CategoryCollectionStrip({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<_CategoryCollectionStripItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 12,
            color: const Color(0xFF6D6254),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return _CategoryCollectionCard(item: item);
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryCollectionCard extends StatelessWidget {
  const _CategoryCollectionCard({required this.item});

  final _CategoryCollectionStripItem item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: TapScale(
        scale: 0.99,
        onTap: () {},
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AbzioNetworkImage(
                imageUrl: item.imageUrl,
                fallbackLabel: item.label,
                fit: BoxFit.cover,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.46),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _CategoryTabsHeaderDelegate({
    required this.selectedTab,
    required this.onCategorySelected,
  });

  final String selectedTab;
  final ValueChanged<String> onCategorySelected;

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFF8F5EF),
      padding: EdgeInsets.zero,
      child: _CategoryTabsBar(
        selectedTab: selectedTab,
        onCategorySelected: onCategorySelected,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryTabsHeaderDelegate oldDelegate) {
    return oldDelegate.selectedTab != selectedTab ||
        oldDelegate.onCategorySelected != onCategorySelected;
  }
}

class _CategoryTabsBar extends StatelessWidget {
  const _CategoryTabsBar({
    required this.selectedTab,
    required this.onCategorySelected,
  });

  final String selectedTab;
  final ValueChanged<String> onCategorySelected;

  static const List<String> _tabs = <String>[
    'Men',
    'Women',
    'Kids',
    'Wedding',
    'Luxury',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _tabs.length,
        separatorBuilder: (context, index) => const SizedBox(width: 24),
        itemBuilder: (context, index) {
          final tab = _tabs[index];
          final selected = tab == selectedTab;
          return TapScale(
            scale: selected ? 0.99 : 1,
            onTap: () => onCategorySelected(tab),
            child: SizedBox(
              width: 70,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? const Color(0xFFC8A86B)
                          : const Color(0xFF444444),
                      height: 1.1,
                    ),
                    child: Text(tab, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 5),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: selected ? 1 : 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      width: selected ? 36 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8A86B),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _sectionHeader({required String title, required String subtitle}) {
  return Builder(
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 19,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.abzioSecondaryText,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

Widget _storesFallbackSection(
  BuildContext context, {
  required ProductProvider provider,
  required List<Product> products,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8DCC2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF9F7F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Color(0xFF111111),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Top sellers delivering to you',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    provider.radiusKm < 25
                        ? 'No nearby stores yet. We found popular online picks instead.'
                        : 'Explore online stores and trending fashion that ships to your location.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF666666),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => provider.radiusKm < 25
                  ? provider.setRadiusKm(25)
                  : showLocationBottomSheet(context),
              child: Text(
                provider.radiusKm < 25 ? 'Expand' : 'Refine',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF666666),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      if (products.isNotEmpty) ...[
        const SizedBox(height: 12),
        SizedBox(
          height: 228,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: 150,
              child: ProductCard(
                product: products[index],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProductDetailScreen(product: products[index]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

// ignore: unused_element
Widget _compactAiStylistStrip({required VoidCallback onTap}) {
  return Builder(
    builder: (context) => TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AbzioTheme.accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Stylist',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Curated fit guidance and styling help in one tap',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.abzioSecondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AbzioTheme.accentColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Open',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ignore: unused_element
Widget _editorialFeatureCard({required VoidCallback onTap}) {
  return Builder(
    builder: (context) => TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Featured Brand Story',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFFC8A96A),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Refined staples for the week ahead',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'One curated drop. Cleaner discovery. Less noise.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.abzioSecondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 48,
              height: 56,
              decoration: BoxDecoration(
                color: AbzioTheme.accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.north_east_rounded,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HomeBadge extends StatelessWidget {
  const _HomeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFFF9F3E7),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class HomeBanner extends StatefulWidget {
  const HomeBanner({
    super.key,
    required this.fallbackBanners,
    required this.onBannerTap,
  });

  final List<BannerModel> fallbackBanners;
  final ValueChanged<BannerModel> onBannerTap;

  @override
  State<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<HomeBanner> {
  final BackendApiClient _apiClient = const BackendApiClient();
  final PageController _pageController = PageController();
  late final Future<List<BannerModel>> _bannersFuture;
  Timer? _autoSlideTimer;
  int _autoSlideCount = 0;

  int _currentIndex = 0;

  static const List<BannerModel> _staticFallbackBanners = [
    BannerModel(
      imageUrl:
          'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&q=80&w=1200',
      title: 'Top-rated stores around you',
      subtitle: 'Handpicked fashion destinations',
      ctaText: 'View Stores',
      redirectType: 'store',
      redirectId: '',
    ),
    BannerModel(
      imageUrl:
          'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&q=80&w=1200',
      title: 'Wedding edits worth arriving for',
      subtitle: 'Handpicked fashion destinations',
      ctaText: 'Discover',
      redirectType: 'category',
      redirectId: 'Wedding',
    ),
    BannerModel(
      imageUrl:
          'https://images.unsplash.com/photo-1496747611176-843222e1e57c?auto=format&fit=crop&q=80&w=1200',
      title: 'Top-rated stores around you',
      subtitle: 'Handpicked fashion destinations',
      ctaText: 'View Stores',
      redirectType: 'store',
      redirectId: '',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bannersFuture = fetchBanners();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _ensureAutoSlide(int slideCount) {
    if (slideCount <= 1) {
      _autoSlideTimer?.cancel();
      _autoSlideTimer = null;
      _autoSlideCount = slideCount;
      return;
    }
    if (_autoSlideTimer != null && _autoSlideCount == slideCount) {
      return;
    }
    _autoSlideTimer?.cancel();
    _autoSlideCount = slideCount;
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      final next = (_currentIndex + 1) % slideCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<List<BannerModel>> fetchBanners() async {
    try {
      if (!_apiClient.isConfigured) {
        return widget.fallbackBanners.isNotEmpty
            ? widget.fallbackBanners
            : _staticFallbackBanners;
      }
      final payload = await _apiClient.get('/banners');
      final items = payload is List ? payload : const [];
      final banners = items
          .whereType<Map>()
          .map((item) => BannerModel.fromMap(Map<String, dynamic>.from(item)))
          .where((banner) => banner.imageUrl.trim().isNotEmpty)
          .toList();
      if (banners.isNotEmpty) {
        return banners;
      }
    } catch (_) {
      // Fall through to provider/static fallback.
    }
    return widget.fallbackBanners.isNotEmpty
        ? widget.fallbackBanners
        : _staticFallbackBanners;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BannerModel>>(
      future: _bannersFuture,
      builder: (context, snapshot) {
        final slides = snapshot.data == null || snapshot.data!.isEmpty
            ? (widget.fallbackBanners.isNotEmpty
                  ? widget.fallbackBanners
                  : _staticFallbackBanners)
            : snapshot.data!;
        _ensureAutoSlide(slides.length);

        if (snapshot.connectionState == ConnectionState.waiting &&
            (snapshot.data == null || snapshot.data!.isEmpty)) {
          return Container(
            height: 360,
            color: Colors.black,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Color(0xFFC8A96A),
            ),
          );
        }

        return Column(
          children: [
            SizedBox(
              height: 360,
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 1, end: 1.03),
                        duration: const Duration(seconds: 14),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) =>
                            Transform.scale(scale: value, child: child),
                        child: Image.network(slide.imageUrl, fit: BoxFit.cover),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.16),
                              Colors.black.withValues(alpha: 0.22),
                              Colors.black.withValues(alpha: 0.78),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'NEW SEASON',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              slide.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontSize: 28,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    height: 1.08,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              slide.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.86),
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => widget.onBannerTap(slide),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFC6A769),
                                foregroundColor: const Color(0xFF111111),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                slide.ctaText.isEmpty
                                    ? 'Shop Now'
                                    : slide.ctaText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                slides.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentIndex == index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? const Color(0xFFC8A96A)
                        : const Color(0xFFD5D0C6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AiOutfitSection extends StatefulWidget {
  const _AiOutfitSection({required this.user, required this.onOpenAiStylist});

  final AppUser? user;
  final VoidCallback onOpenAiStylist;

  @override
  State<_AiOutfitSection> createState() => _AiOutfitSectionState();
}

class _AiOutfitSectionState extends State<_AiOutfitSection> {
  static const List<String> _occasionFilters = [
    '',
    'casual',
    'party',
    'wedding',
    'office',
  ];
  static const List<String> _budgetFilters = [
    '',
    'under_999',
    'under_1999',
    'under_2999',
  ];
  static const List<String> _styleFilters = [
    '',
    'minimal',
    'streetwear',
    'formal',
    'ethnic',
  ];

  final DatabaseService _db = DatabaseService();
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20B9',
    decimalDigits: 0,
  );

  late Future<List<OutfitRecommendation>> _outfitsFuture;
  final Set<String> _dismissedOutfits = <String>{};
  String _occasion = '';
  String _budget = '';
  String _style = '';
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _outfitsFuture = _loadOutfits();
  }

  @override
  void didUpdateWidget(covariant _AiOutfitSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.id != widget.user?.id) {
      _refresh();
    }
  }

  Future<List<OutfitRecommendation>> _loadOutfits() async {
    final outfits = await _db.getOutfitRecommendations(
      user: widget.user,
      occasion: _occasion.isEmpty ? null : _occasion,
      budget: _budget.isEmpty ? null : _budget,
      style: _style.isEmpty ? null : _style,
      limit: 6,
    );
    return outfits
        .where((outfit) => !_dismissedOutfits.contains(outfit.outfitId))
        .toList();
  }

  void _refresh() {
    setState(() {
      _outfitsFuture = _loadOutfits();
    });
  }

  Future<void> _track(
    String action,
    OutfitRecommendation outfit, {
    Map<String, dynamic> metadata = const {},
  }) async {
    await _db.trackOutfitInteraction(
      action: action,
      outfitId: outfit.outfitId,
      itemIds: outfit.items.map((item) => item.id).toList(),
      filters: {
        if (_occasion.isNotEmpty) 'occasion': _occasion,
        if (_budget.isNotEmpty) 'budget': _budget,
        if (_style.isNotEmpty) 'style': _style,
      },
      metadata: metadata,
    );
  }

  Future<void> _skipOutfit(OutfitRecommendation outfit) async {
    setState(() {
      _dismissedOutfits.add(outfit.outfitId);
      _outfitsFuture = _loadOutfits();
    });
    await _track('skip', outfit, metadata: {'source': 'home_outfit_section'});
  }

  Future<void> _shopOutfit(OutfitRecommendation outfit) async {
    if (outfit.items.isEmpty) {
      return;
    }
    await _track('click', outfit, metadata: {'source': 'home_outfit_section'});
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: outfit.items.first),
      ),
    );
  }

  String _labelForFilter(String value) {
    if (value.isEmpty) {
      return 'All';
    }
    if (value.startsWith('under_')) {
      return value.replaceFirst('under_', 'Under \u20B9').replaceAll('_', '');
    }
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  Widget _filterRow({
    required String label,
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 62,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: context.abzioSecondaryText,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final option = options[index];
                final selected = option == selectedValue;
                return ChoiceChip(
                  label: Text(_labelForFilter(option)),
                  selected: selected,
                  onSelected: (_) {
                    onSelected(selected ? '' : option);
                  },
                  selectedColor: const Color(0xFFC9A74E),
                  backgroundColor: const Color(0xFFF1F1F1),
                  labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? Colors.white : const Color(0xFF121212),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  side: BorderSide.none,
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: const VisualDensity(
                    horizontal: -2,
                    vertical: -3,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _loadingRail() {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 2,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => Container(
          width: 232,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ShimmerBox(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 12, child: ShimmerBox()),
                    SizedBox(height: 4),
                    SizedBox(height: 12, child: ShimmerBox()),
                    SizedBox(height: 6),
                    SizedBox(height: 12, width: 72, child: ShimmerBox()),
                    SizedBox(height: 10),
                    SizedBox(
                      height: 32,
                      width: 88,
                      child: ShimmerBox(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactOutfitRail(List<OutfitRecommendation> outfits) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: outfits.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final outfit = outfits[index];
          final items = outfit.items;
          return Container(
            width: 236,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AbzioNetworkImage(
                            imageUrl: items.first.images.isNotEmpty
                                ? items.first.images.first
                                : '',
                            fallbackLabel: items.first.name,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF121212,
                                ).withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${outfit.matchScore}% match',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 9,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              outfit.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              visualDensity: const VisualDensity(
                                horizontal: -4,
                                vertical: -4,
                              ),
                              onPressed: () => _skipOutfit(outfit),
                              icon: const Icon(Icons.close_rounded, size: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        outfit.bodyTypeLabel.isNotEmpty
                            ? 'Perfect for your body type · ${outfit.bodyTypeLabel}'
                            : 'Recommended for you',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: context.abzioSecondaryText,
                        ),
                      ),
                      if (outfit.bodyReason.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          outfit.bodyReason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 11,
                                color: context.abzioSecondaryText.withValues(
                                  alpha: 0.88,
                                ),
                              ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _currencyFormatter.format(outfit.totalPrice),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 32,
                            child: FilledButton(
                              onPressed: () => _shopOutfit(outfit),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFC9A74E),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: const VisualDensity(
                                  horizontal: -2,
                                  vertical: -3,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Shop',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _showFilters = !_showFilters),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9A74E).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: Color(0xFFC9A74E),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Stylist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Curated looks from your style profile',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 12,
                                color: context.abzioSecondaryText,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: widget.onOpenAiStylist,
                    icon: const Icon(Icons.tune_rounded, size: 14),
                    label: const Text('Open'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(
                        horizontal: -2,
                        vertical: -3,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showFilters
                        ? Icons.expand_less_rounded
                        : Icons.chevron_right_rounded,
                    size: 20,
                    color: const Color(0xFF4A4A4A),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showFilters) ...[
          const SizedBox(height: 8),
          _filterRow(
            label: 'Occasion',
            options: _occasionFilters,
            selectedValue: _occasion,
            onSelected: (value) {
              _occasion = value;
              _refresh();
            },
          ),
          const SizedBox(height: 8),
          _filterRow(
            label: 'Budget',
            options: _budgetFilters,
            selectedValue: _budget,
            onSelected: (value) {
              _budget = value;
              _refresh();
            },
          ),
          const SizedBox(height: 8),
          _filterRow(
            label: 'Style',
            options: _styleFilters,
            selectedValue: _style,
            onSelected: (value) {
              _style = value;
              _refresh();
            },
          ),
        ],
        const SizedBox(height: 8),
        FutureBuilder<List<OutfitRecommendation>>(
          future: _outfitsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _loadingRail();
            }

            final outfits = snapshot.data ?? const <OutfitRecommendation>[];
            if (outfits.isEmpty) {
              return AbzioEmptyCard(
                title: 'No outfit edits yet',
                subtitle:
                    'Try a different occasion or open AI Stylist to get more personal styling suggestions.',
                ctaLabel: 'Open AI Stylist',
                onTap: widget.onOpenAiStylist,
              );
            }

            return _buildCompactOutfitRail(outfits); /*
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: outfits.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final outfit = outfits[index];
                  final items = outfit.items;
                  return Container(
                    width: 270,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: AbzioNetworkImage(
                                          imageUrl: items.first.images.isNotEmpty ? items.first.images.first : '',
                                          fallbackLabel: items.first.name,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(16),
                                              child: AbzioNetworkImage(
                                                imageUrl: items.length > 1 && items[1].images.isNotEmpty ? items[1].images.first : '',
                                                fallbackLabel: items.length > 1 ? items[1].name : 'Abianzo',
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(16),
                                              child: AbzioNetworkImage(
                                                imageUrl: items.length > 2 && items[2].images.isNotEmpty ? items[2].images.first : '',
                                                fallbackLabel: items.length > 2 ? items[2].name : 'Abianzo',
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Material(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: () => _skipOutfit(outfit),
                                    customBorder: const CircleBorder(),
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(Icons.close_rounded, size: 18),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 20,
                                bottom: 18,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF121212).withValues(alpha: 0.82),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${outfit.matchScore}% match',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                outfit.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${items.length} picks · ${_labelForFilter(outfit.occasion)} · ${_labelForFilter(outfit.style)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: context.abzioSecondaryText,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _currencyFormatter.format(outfit.totalPrice),
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 40,
                                    child: FilledButton(
                                      onPressed: () => _shopOutfit(outfit),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFFC9A74E),
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: const Text('Shop Outfit'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ); */
          },
        ),
      ],
    );
  }
}

Widget _promoBanner({
  required PromoBannerCopy copy,
  required VoidCallback onTap,
  String? imageUrl,
}) {
  return Builder(
    builder: (context) => TapScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE2C98B).withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F1A0B).withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: imageUrl != null && imageUrl.trim().isNotEmpty
                  ? AbzioNetworkImage(
                      imageUrl: imageUrl,
                      fallbackLabel: copy.title,
                      fit: BoxFit.cover,
                    )
                  : const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF181108),
                            Color(0xFF4F3A14),
                            Color(0xFF8C6A12),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF120E08).withValues(alpha: 0.74),
                      const Color(0xFF281C0B).withValues(alpha: 0.48),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.eyebrow.toUpperCase(),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: const Color(0xFFF8E9BE),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          copy.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          copy.subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(
                                  0xFFF7F1E3,
                                ).withValues(alpha: 0.82),
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            _HomeBadge(label: 'Premium edit'),
                            _HomeBadge(label: 'Fast discovery'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.arrow_outward_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF19130A),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(copy.cta),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class HomePromoBannerSlot extends StatefulWidget {
  const HomePromoBannerSlot({
    super.key,
    required this.slot,
    required this.fallbackCopy,
    required this.onTap,
  });

  final int slot;
  final PromoBannerCopy fallbackCopy;
  final VoidCallback onTap;

  @override
  State<HomePromoBannerSlot> createState() => _HomePromoBannerSlotState();
}

class _HomePromoBannerSlotState extends State<HomePromoBannerSlot> {
  final BackendApiClient _apiClient = const BackendApiClient();
  static Future<HomeVisualConfigModel>? _sharedFuture;
  @override
  void initState() {
    super.initState();
    _sharedFuture ??= _fetchHomeVisuals();
  }

  Future<HomeVisualConfigModel> _fetchHomeVisuals() async {
    if (!_apiClient.isConfigured) {
      return const HomeVisualConfigModel();
    }
    try {
      final payload = await _apiClient.get('/home-visuals');
      final map = Map<String, dynamic>.from(payload as Map);
      final data = map['data'] is Map
          ? Map<String, dynamic>.from(map['data'] as Map)
          : map;
      return HomeVisualConfigModel.fromMap(data);
    } catch (_) {
      return const HomeVisualConfigModel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeVisualConfigModel>(
      future: _sharedFuture,
      builder: (context, snapshot) {
        final promoBlocks =
            snapshot.data?.promoBlocks ?? const <HomePromoBlockModel>[];
        final matches = promoBlocks.where(
          (item) => item.isActive && item.slot == widget.slot,
        );
        final block = matches.isEmpty ? null : matches.first;
        final copy = block == null
            ? widget.fallbackCopy
            : PromoBannerCopy(
                eyebrow: block.eyebrow.isEmpty
                    ? widget.fallbackCopy.eyebrow
                    : block.eyebrow,
                title: block.title.isEmpty
                    ? widget.fallbackCopy.title
                    : block.title,
                subtitle: block.subtitle.isEmpty
                    ? widget.fallbackCopy.subtitle
                    : block.subtitle,
                cta: block.ctaText.isEmpty
                    ? widget.fallbackCopy.cta
                    : block.ctaText,
              );
        return _promoBanner(
          copy: copy,
          imageUrl: block?.imageUrl,
          onTap: widget.onTap,
        );
      },
    );
  }
}

Widget _productSection(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<Product> products,
}) {
  if (products.isEmpty) {
    return const SizedBox.shrink();
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionHeader(title: title, subtitle: subtitle),
      const SizedBox(height: 14),
      ProductGrid(
        products: products,
        shrinkWrap: true,
        onProductTap: (product) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        ),
      ),
    ],
  );
}

Widget _storeCard({required NearbyStore nearby, required VoidCallback onTap}) {
  final store = nearby.store;
  final image = store.logoUrl.isNotEmpty
      ? store.logoUrl
      : (store.imageUrl.isNotEmpty ? store.imageUrl : store.bannerImageUrl);
  return Builder(
    builder: (context) => TapScale(
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 172,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8DCC2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F7F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: image.isEmpty
                    ? const Icon(Icons.storefront_outlined, size: 18)
                    : AbzioNetworkImage(
                        imageUrl: image,
                        fallbackLabel: store.name,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      store.tagline.trim().isEmpty
                          ? '${nearby.distanceKm.toStringAsFixed(1)} km away'
                          : store.tagline.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Expand',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF666666),
                    fontWeight: FontWeight.w600,
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

class _StoreSkeletonList extends StatelessWidget {
  const _StoreSkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AbianzoText.storesLoading,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.abzioSecondaryText),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => Container(
              width: 164,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6E6E6)),
              ),
              padding: const EdgeInsets.all(12),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 16, child: ShimmerBox()),
                  SizedBox(height: 8),
                  SizedBox(height: 12, child: ShimmerBox()),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}







