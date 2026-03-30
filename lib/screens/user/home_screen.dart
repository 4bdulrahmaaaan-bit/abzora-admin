import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/text_constants.dart';
import '../../models/banner_model.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/banner_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/product_provider.dart';
import '../../theme.dart';
import '../../widgets/banner_carousel.dart';
import '../../widgets/global_skeletons.dart';
import '../../widgets/home_header.dart';
import '../../widgets/product_grid.dart';
import '../../widgets/shimmer_box.dart';
import '../../widgets/state_views.dart';
import '../../widgets/tap_scale.dart';
import '../tailoring/custom_brand_flow_screen.dart';
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  static const String _hasUsedAiKey = 'abzora_has_used_ai_stylist';
  static const String _appOpenCountKey = 'abzora_ai_app_open_count';

  late final AnimationController _pulseController;
  bool _hasUsedAi = false;
  int _appOpenCount = 0;
  bool _showAiTooltip = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _restoreAiDiscoveryState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final auth = context.read<AuthProvider>();
      context.read<ProductProvider>().fetchHomeData(user: auth.user);
    });
  }

  Future<void> _restoreAiDiscoveryState() async {
    final prefs = await SharedPreferences.getInstance();
    final nextOpenCount = (prefs.getInt(_appOpenCountKey) ?? 0) + 1;
    final hasUsedAi = prefs.getBool(_hasUsedAiKey) ?? false;
    await prefs.setInt(_appOpenCountKey, nextOpenCount);
    if (!mounted) {
      return;
    }
    setState(() {
      _appOpenCount = nextOpenCount;
      _hasUsedAi = hasUsedAi;
      _showAiTooltip = !hasUsedAi && nextOpenCount == 1;
    });
    if (_showAiTooltip) {
      Future<void>.delayed(const Duration(seconds: 4), () {
        if (!mounted) {
          return;
        }
        setState(() => _showAiTooltip = false);
      });
    }
  }

  Future<void> _markAiUsed() async {
    if (!_hasUsedAi) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasUsedAiKey, true);
      if (mounted) {
        setState(() {
          _hasUsedAi = true;
          _showAiTooltip = false;
        });
      }
    } else if (_showAiTooltip && mounted) {
      setState(() => _showAiTooltip = false);
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

  List<Widget> _screens() {
    return [
      HomeContent(
        showAiDiscoveryCard: !_hasUsedAi && _appOpenCount <= 3,
        showCompactAiCard: _hasUsedAi || _appOpenCount > 3,
        onOpenAiStylist: _openAiStylist,
      ),
      const CustomBrandFlowScreen(),
      const OrderTrackingScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return AbzioThemeScope.light(
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens()),
        floatingActionButton: keyboardOpen
            ? null
            : _AiStylistFloatingButton(
                animation: _pulseController,
                showTooltip: _showAiTooltip,
                onTooltipDismissed: () => setState(() => _showAiTooltip = false),
                onTap: _openAiStylist,
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: NavigationBar(
          height: 68,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, size: 26), label: 'Home'),
            NavigationDestination(
              icon: Icon(Icons.design_services_outlined),
              selectedIcon: Icon(Icons.design_services_rounded, size: 26),
              label: AbzoraText.customNavLabel,
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded, size: 26),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded, size: 26),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({
    super.key,
    required this.showAiDiscoveryCard,
    required this.showCompactAiCard,
    required this.onOpenAiStylist,
  });

  final bool showAiDiscoveryCard;
  final bool showCompactAiCard;
  final VoidCallback onOpenAiStylist;

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final _scrollController = ScrollController();
  bool _profileModalShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final auth = context.read<AuthProvider>();
      if (auth.requiresProfileSetup) {
        _promptProfileSetup();
      }
    });
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) {
        return;
      }
      final max = _scrollController.position.maxScrollExtent;
      if (_scrollController.position.pixels > max - 380) {
        context.read<ProductProvider>().loadMoreLocationProducts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final userName = user?.name.trim().isEmpty ?? true ? '' : user!.name;
    final savedAddress = (user?.address ?? '').trim();

    return Consumer2<ProductProvider, LocationProvider>(
      builder: (context, provider, locationProvider, child) {
        final products = provider.searchResults.isNotEmpty ? provider.searchResults : provider.locationProducts;
        final stores = provider.nearbyStores;
        final bannerProvider = context.watch<BannerProvider>();
        final banners = bannerProvider.banners;
        final headline = user == null ? AbzoraText.locationLoggedOutTitle : locationProvider.deliveryHeadline(userName);
        final line2 = user == null
            ? AbzoraText.locationSubtext
            : locationProvider.deliverySubline().trim().isNotEmpty
                ? locationProvider.deliverySubline()
                : savedAddress.isNotEmpty
                    ? savedAddress
                    : AbzoraText.locationSubtext;
        final trendingProducts = products.take(4).toList();
        final justForYouProducts = products.skip(4).take(4).toList();
        final recentlyViewedProducts = products.reversed.take(4).toList();

        return Scaffold(
          appBar: HomeHeader(
            onSearchTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SearchScreen(
                  allProducts: products,
                  selectedLocation: provider.activeLocation,
                ),
              ),
            ),
            onWishlistTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WishlistScreen()),
            ),
            onCartTap: () => Navigator.pushNamed(context, '/cart'),
          ),
          body: provider.isLoading && products.isEmpty
              ? const _HomeSkeleton()
              : RefreshIndicator(
                  onRefresh: () => provider.fetchHomeData(forceLocationRefresh: true, user: auth.user),
                  color: AbzioTheme.accentColor,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(
                            [
                              _locationBar(
                                title: headline,
                                line2: line2,
                                onTap: () => showLocationBottomSheet(context),
                              ),
                              const SizedBox(height: 16),
                              BannerCarousel(
                                banners: banners,
                                isLoading: bannerProvider.isLoading,
                                onBannerTap: (banner) => _handleBannerTap(
                                  banner,
                                  products: products,
                                  stores: stores,
                                  selectedLocation: provider.activeLocation,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _tailoringHighlight(
                                onStart: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CustomBrandFlowScreen()),
                                ),
                              ),
                              if (widget.showAiDiscoveryCard) ...[
                                const SizedBox(height: 14),
                                _aiStylistHighlight(
                                  onTap: widget.onOpenAiStylist,
                                ),
                              ] else if (widget.showCompactAiCard) ...[
                                const SizedBox(height: 14),
                                _compactAiStylistCard(
                                  onTap: widget.onOpenAiStylist,
                                ),
                              ],
                              const SizedBox(height: 20),
                              _categoryRow(),
                              const SizedBox(height: 20),
                              _promoBanner(
                                copy: AbzoraCopySets.promoBanners[0],
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CustomBrandFlowScreen()),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _sectionHeader(
                                title: AbzoraText.storesNearYou,
                                subtitle: AbzoraText.locationSubtext,
                              ),
                              const SizedBox(height: 12),
                              if (provider.isLocationLoading)
                                const _StoreSkeletonList()
                              else if (stores.isEmpty)
                                AbzioEmptyCard(
                                  title: provider.usingNearestStoreFallback
                                      ? AbzoraText.storesFallbackTitle
                                      : AbzoraText.storesEmptyTitle,
                                  subtitle: provider.usingNearestStoreFallback
                                      ? AbzoraText.storesFallbackSubtitle
                                      : '${AbzoraText.storesEmptySubtitle} No stores within ${provider.radiusKm.toInt()} km.',
                                  ctaLabel: provider.radiusKm < 25 ? AbzoraText.expandTo25Km : AbzoraText.changeLocation,
                                  onTap: () => provider.radiusKm < 25 ? provider.setRadiusKm(25) : showLocationBottomSheet(context),
                                )
                              else
                                SizedBox(
                                  height: 192,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: stores.length,
                                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                                    itemBuilder: (context, index) => _storeCard(
                                      nearby: stores[index],
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => StoreDetailScreen(store: stores[index].store)),
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      if (products.isEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverToBoxAdapter(
                            child: AbzioEmptyCard(
                              title: AbzoraText.homeEmptyTitle,
                              subtitle: AbzoraText.homeEmptySubtitle,
                              ctaLabel: AbzoraText.homeEmptyCta,
                              onTap: () => provider.fetchHomeData(forceLocationRefresh: true, user: auth.user),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate(
                              [
                                _productSection(
                                  context,
                                  title: AbzoraText.trendingNearYouTitle,
                                  subtitle: AbzoraText.trendingNearYouSubtitle,
                                  products: trendingProducts,
                                ),
                                const SizedBox(height: 20),
                                _promoBanner(
                                  copy: AbzoraCopySets.promoBanners[1],
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CustomBrandFlowScreen()),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _productSection(
                                  context,
                                  title: AbzoraText.justForYouTitle,
                                  subtitle: AbzoraText.justForYouSubtitle,
                                  products: justForYouProducts.isEmpty ? trendingProducts : justForYouProducts,
                                ),
                                const SizedBox(height: 20),
                                _promoBanner(
                                  copy: AbzoraCopySets.promoBanners[2],
                                  onTap: () => showLocationBottomSheet(context),
                                ),
                                const SizedBox(height: 20),
                                _productSection(
                                  context,
                                  title: AbzoraText.recentlyViewedTitle,
                                  subtitle: AbzoraText.recentlyViewedSubtitle,
                                  products: recentlyViewedProducts.isEmpty ? trendingProducts : recentlyViewedProducts,
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (provider.isLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 20),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AbzioTheme.accentColor),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Future<void> _promptProfileSetup() async {
    if (_profileModalShown) {
      return;
    }
    _profileModalShown = true;
    final auth = context.read<AuthProvider>();
    final nameController = TextEditingController(text: auth.user?.name ?? '');
    final addressController = TextEditingController(text: auth.user?.address ?? '');
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Profile setup',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final navigator = Navigator.of(dialogContext);
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        return _ProfileSetupSheet(
          auth: auth,
          nameController: nameController,
          addressController: addressController,
          onUseCurrentLocation: () async {
            final productProvider = context.read<ProductProvider>();
            try {
              await auth.fillAddressFromGps(fallbackName: nameController.text.trim());
              if (!mounted) {
                return;
              }
              navigator.pop();
              await productProvider.requestLocationAccess();
            } catch (_) {
              if (!mounted) {
                return;
              }
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text(AbzoraText.locationDetectError)),
              );
            }
          },
          onSave: () async {
            final productProvider = context.read<ProductProvider>();
            await auth.saveProfile(
              name: nameController.text.trim().isEmpty ? 'ABZORA Member' : nameController.text.trim(),
              address: addressController.text.trim(),
            );
            if (!mounted) {
              return;
            }
            navigator.pop();
            await productProvider.applySavedUserLocation(auth.user);
          },
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
    nameController.dispose();
    addressController.dispose();
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
            MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
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
              (item) => banner.redirectId.isNotEmpty ? item?.store.id == banner.redirectId : true,
              orElse: () => null,
            );
        if (store != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => StoreDetailScreen(store: store.store)),
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
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerCard(height: 68),
          SizedBox(height: 16),
          ShimmerBannerBlock(),
          SizedBox(height: 16),
          ShimmerCard(height: 120),
          SizedBox(height: 16),
          ShimmerCategoryRow(),
          SizedBox(height: 18),
          ShimmerBannerBlock(),
          SizedBox(height: 18),
          ShimmerProductGrid(),
        ],
      ),
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
    _nameFocusNode = FocusNode()..addListener(_handleFocusChange);
    _addressFocusNode = FocusNode()..addListener(_handleFocusChange);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();
    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    );
    _fieldSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
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
    _nameFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _addressFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {});
    }
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
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                                    colors: [Color(0xFFE5BF5D), Color(0xFFC69222)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AbzioTheme.accentColor.withValues(alpha: 0.28),
                                      blurRadius: 18,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.content_cut_rounded, color: Colors.black),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Complete your profile for perfect fit ✨',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'We’ll use this to personalize your fit and delivery',
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
                                label: AbzoraText.profileSetupNameLabel,
                                icon: Icons.person_outline_rounded,
                              ),
                              const SizedBox(height: 14),
                              _premiumField(
                                controller: widget.addressController,
                                focusNode: _addressFocusNode,
                                label: AbzoraText.profileSetupAddressLabel,
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
                                  onTap: widget.auth.isUpdatingProfile ? null : widget.onSave,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFD9B14D), Color(0xFFBF8E22)],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AbzioTheme.accentColor.withValues(alpha: 0.26),
                                          blurRadius: 18,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: widget.auth.isUpdatingProfile ? null : widget.onSave,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(vertical: 18),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: widget.auth.isUpdatingProfile
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Text(
                                              'Save & Continue',
                                              style: TextStyle(fontWeight: FontWeight.w800),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: TapScale(
                                  onTap: widget.auth.isUpdatingProfile ? null : widget.onUseCurrentLocation,
                                  child: OutlinedButton(
                                    onPressed: widget.auth.isUpdatingProfile ? null : widget.onUseCurrentLocation,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      side: BorderSide(color: AbzioTheme.accentColor.withValues(alpha: 0.34)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: widget.auth.isUpdatingProfile
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
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
            borderSide: const BorderSide(color: AbzioTheme.accentColor, width: 1.4),
          ),
        ),
      ),
    );
  }
}

Widget _locationBar({
  required String title,
  required String line2,
  required VoidCallback onTap,
}) {
  return Builder(
    builder: (context) => TapScale(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.abzioBorder),
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
              const Icon(Icons.location_on_outlined, color: AbzioTheme.accentColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      line2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.abzioSecondaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.keyboard_arrow_down_rounded, color: context.abzioSecondaryText),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _tailoringHighlight({required VoidCallback onStart}) {
  return Builder(
    builder: (context) => TapScale(
      onTap: onStart,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context).cardColor,
          border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.5)),
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
                color: AbzioTheme.accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.design_services_rounded, color: AbzioTheme.accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AbzoraText.customClothingTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    AbzoraText.customClothingSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.abzioSecondaryText),
                  ),
                ],
              ),
            ),
            ElevatedButton(onPressed: onStart, child: const Text(AbzoraText.customClothingCta)),
          ],
        ),
      ),
    ),
  );
}

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
            colors: [
              Color(0xFFFFF8E6),
              Colors.white,
            ],
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
              height: 48,
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    'Try AI Stylist ✨',
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

Widget _compactAiStylistCard({required VoidCallback onTap}) {
  return Builder(
    builder: (context) => TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.18)),
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
              child: const Icon(Icons.auto_awesome_rounded, color: AbzioTheme.accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Stylist',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Instant outfit ideas and fit help',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.abzioSecondaryText),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: AbzioTheme.accentColor),
          ],
        ),
      ),
    ),
  );
}

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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  'Try AI Stylist for perfect outfit 🔥',
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
            final scale = 1 + (animation.value * 0.04);
            return Transform.scale(
              scale: scale,
              child: TapScale(
                onTap: onTap,
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFE8C65C),
                        AbzioTheme.accentColor,
                      ],
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
                    size: 28,
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

Widget _categoryRow() {
  const icons = <IconData>[
    Icons.male_rounded,
    Icons.female_rounded,
    Icons.auto_awesome_rounded,
    Icons.watch_outlined,
  ];
  return SizedBox(
    height: 92,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: AbzoraCopySets.categories.length,
      separatorBuilder: (context, index) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final category = AbzoraCopySets.categories[index];
        return TapScale(
          onTap: () {},
          child: Container(
            width: 118,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).cardColor,
              border: Border.all(color: context.abzioBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icons[index], color: AbzioTheme.accentColor, size: 20),
                const SizedBox(height: 10),
                Text(category.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  category.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.abzioSecondaryText),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Widget _sectionHeader({
  required String title,
  required String subtitle,
}) {
  return Builder(
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.abzioSecondaryText),
        ),
      ],
    ),
  );
}

Widget _promoBanner({
  required PromoBannerCopy copy,
  required VoidCallback onTap,
}) {
  return Builder(
    builder: (context) => TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF1F1A0B), Color(0xFF4B3A10)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F1A0B).withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 12),
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
                    copy.eyebrow.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    copy.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    copy.subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
              ),
              child: Text(copy.cta),
            ),
          ],
        ),
      ),
    ),
  );
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
      const SizedBox(height: 12),
      ProductGrid(
        products: products,
        shrinkWrap: true,
        onProductTap: (product) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
        ),
      ),
    ],
  );
}

Widget _storeCard({required NearbyStore nearby, required VoidCallback onTap}) {
  final store = nearby.store;
  final image = store.imageUrl.isNotEmpty ? store.imageUrl : store.bannerImageUrl;
  return Builder(
    builder: (context) => TapScale(
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 164,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.abzioBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 108, width: double.infinity, child: AbzioNetworkImage(imageUrl: image, fallbackLabel: store.name)),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${nearby.distanceKm.toStringAsFixed(1)} km away',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.abzioSecondaryText),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AbzioTheme.accentColor),
                        const SizedBox(width: 2),
                        Text(
                          store.rating.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
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
          AbzoraText.storesLoading,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.abzioSecondaryText),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 192,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => Container(
              width: 164,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.abzioBorder),
              ),
              padding: const EdgeInsets.all(10),
              child: const Column(
                children: [
                  Expanded(child: ShimmerBox()),
                  SizedBox(height: 8),
                  SizedBox(height: 14, child: ShimmerBox()),
                  SizedBox(height: 6),
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
