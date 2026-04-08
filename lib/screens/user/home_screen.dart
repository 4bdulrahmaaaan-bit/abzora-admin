import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/text_constants.dart';
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
import '../../widgets/global_skeletons.dart';
import '../../widgets/home_header.dart';
import '../../widgets/product_card.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  static const String _hasUsedAiKey = 'abzora_has_used_ai_stylist';

  bool _hasUsedAi = false;

  @override
  void initState() {
    super.initState();
    _restoreAiDiscoveryState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 220), () async {
          if (!mounted) {
            return;
          }
          final auth = context.read<AuthProvider>();
          await context.read<ProductProvider>().fetchHomeData(user: auth.user);
        }),
      );
    });
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

  List<Widget> _screens() {
    return [
      HomeContent(
        onOpenAiStylist: _openAiStylist,
      ),
      const CustomBrandFlowScreen(),
      const OrderTrackingScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AbzioThemeScope.light(
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens()),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              height: 66,
              backgroundColor: Colors.white,
              indicatorColor: AbzioTheme.accentColor.withValues(alpha: 0.16),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? const Color(0xFF1A1A1A) : const Color(0xFF707070),
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return IconThemeData(
                  color: selected ? AbzioTheme.accentColor : const Color(0xFF6A6A6A),
                  size: selected ? 24 : 22,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) => setState(() => _currentIndex = index),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
                NavigationDestination(
                  icon: Icon(Icons.design_services_outlined),
                  selectedIcon: Icon(Icons.design_services_rounded),
                  label: AbzoraText.customNavLabel,
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: 'Orders',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({
    super.key,
    required this.onOpenAiStylist,
  });

  final VoidCallback onOpenAiStylist;

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final _scrollController = ScrollController();
  bool _profileModalShown = false;
  bool _isHeaderScrolled = false;

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
      final shouldCompressHeader = _scrollController.offset > 18;
      if (shouldCompressHeader != _isHeaderScrolled && mounted) {
        setState(() => _isHeaderScrolled = shouldCompressHeader);
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

    return Consumer2<ProductProvider, LocationProvider>(
      builder: (context, provider, locationProvider, child) {
        final products = provider.searchResults.isNotEmpty ? provider.searchResults : provider.locationProducts;
        final stores = provider.nearbyStores;
        final banners = context.watch<BannerProvider>().banners;
        final headline = user == null ? AbzoraText.locationLoggedOutTitle : locationProvider.deliveryHeadline(userName);
        final trendingProducts = products.take(4).toList();
        final justForYouProducts = products.skip(4).take(4).toList();
        final recentlyViewedProducts = products.reversed.take(4).toList();
        final storesSection = _buildStoresSection(
          context,
          provider: provider,
          stores: stores,
          products: products,
        );

        return SafeArea(
          top: true,
          bottom: false,
          child: Scaffold(
            appBar: HomeHeader(
              location: headline,
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
              onWishlistTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WishlistScreen()),
              ),
              onCartTap: () => Navigator.pushNamed(context, '/cart'),
              onLocationTap: () => showLocationBottomSheet(context),
            ),
            body: provider.isLoading && products.isEmpty
                ? const _HomeSkeleton()
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
                        controller: _scrollController,
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate(
                                [
                                  const SizedBox(height: 4),
                                  HomeBanner(
                                    fallbackBanners: banners,
                                    onBannerTap: (banner) => _handleBannerTap(
                                      banner,
                                      products: products,
                                      stores: stores,
                                      selectedLocation: provider.activeLocation,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _compactAiStylistStrip(
                                    onTap: widget.onOpenAiStylist,
                                  ),
                                  const SizedBox(height: 10),
                                  _tailoringHighlight(
                                    onStart: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const CustomBrandFlowScreen(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const CategorySection(),
                                  const SizedBox(height: 12),
                                  _promoBanner(
                                    copy: AbzoraCopySets.promoBanners[0],
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const CustomBrandFlowScreen(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
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
                                  onTap: () => provider.fetchHomeData(
                                    forceLocationRefresh: true,
                                    user: auth.user,
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 116),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate(
                                  [
                                    _productSection(
                                      context,
                                      title: AbzoraText.trendingNearYouTitle,
                                      subtitle: AbzoraText.trendingNearYouSubtitle,
                                      products: trendingProducts,
                                    ),
                                    const SizedBox(height: 12),
                                    _promoBanner(
                                      copy: AbzoraCopySets.promoBanners[1],
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const CustomBrandFlowScreen(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _productSection(
                                      context,
                                      title: AbzoraText.justForYouTitle,
                                      subtitle: AbzoraText.justForYouSubtitle,
                                      products: justForYouProducts.isEmpty
                                          ? trendingProducts
                                          : justForYouProducts,
                                    ),
                                    const SizedBox(height: 12),
                                    _promoBanner(
                                      copy: AbzoraCopySets.promoBanners[2],
                                      onTap: () => showLocationBottomSheet(context),
                                    ),
                                    const SizedBox(height: 12),
                                    _productSection(
                                      context,
                                      title: AbzoraText.recentlyViewedTitle,
                                      subtitle: AbzoraText.recentlyViewedSubtitle,
                                      products: recentlyViewedProducts.isEmpty
                                          ? trendingProducts
                                          : recentlyViewedProducts,
                                    ),
                                    const SizedBox(height: 12),
                                    storesSection,
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AbzioTheme.accentColor,
                                    ),
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
          title: AbzoraText.storesNearYou,
          subtitle: AbzoraText.locationSubtext,
        ),
        const SizedBox(height: 10),
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
            height: 192,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: stores.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _storeCard(
                nearby: stores[index],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoreDetailScreen(
                      store: stores[index].store,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerCard(height: 68),
          SizedBox(height: 12),
          ShimmerCard(height: 56),
          SizedBox(height: 12),
          ShimmerBannerBlock(),
          SizedBox(height: 12),
          ShimmerCard(height: 108),
          SizedBox(height: 12),
          ShimmerCategoryRow(),
          SizedBox(height: 12),
          ShimmerBannerBlock(),
          SizedBox(height: 12),
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

Widget _tailoringHighlight({required VoidCallback onStart}) {
  return Builder(
    builder: (context) => TapScale(
      onTap: onStart,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF121212),
              Color(0xFF2E2417),
              Color(0xFFF1DCA1),
            ],
          ),
          border: Border.all(color: const Color(0x33FFFFFF)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'LUXURY ATELIER',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.design_services_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              AbzoraText.customClothingTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crafted to your body. Designed with your chosen boutique.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _AtelierChip(label: 'Featured Designers'),
                _AtelierChip(label: 'Wedding Specialists'),
                _AtelierChip(label: 'Formal Shirts'),
                _AtelierChip(label: 'Blazers'),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFFFFE7A7),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Choose store first • Live pricing • Precision fit guaranteed',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onStart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(AbzoraText.customClothingCta),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onStart,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Explore Designers'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _AtelierChip extends StatelessWidget {
  const _AtelierChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
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
  const CategorySection({super.key});

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection> {
  static const _tabs = ['All', 'Men', 'Women', 'Kids'];
  static const _quickFilters = <String>[
    'Price Crash',
    'Top Rated',
    'Rising Star',
  ];

  static final Map<String, List<_CategorySectionItem>> _categoryMap = {
    'All': [
      _CategorySectionItem(
        label: AbzoraCopySets.categories[0].title,
        icon: Icons.male_rounded,
      ),
      _CategorySectionItem(
        label: AbzoraCopySets.categories[1].title,
        icon: Icons.female_rounded,
      ),
      _CategorySectionItem(
        label: AbzoraCopySets.categories[2].title,
        icon: Icons.auto_awesome_rounded,
      ),
      _CategorySectionItem(
        label: AbzoraCopySets.categories[3].title,
        icon: Icons.watch_outlined,
      ),
    ],
    'Men': const [
      _CategorySectionItem(label: 'Casual', icon: Icons.checkroom_rounded),
      _CategorySectionItem(label: 'Ethnic', icon: Icons.auto_awesome_rounded),
      _CategorySectionItem(label: 'Footwear', icon: Icons.hiking_rounded),
      _CategorySectionItem(label: 'Sports', icon: Icons.sports_basketball_rounded),
    ],
    'Women': const [
      _CategorySectionItem(label: 'Western', icon: Icons.diamond_outlined),
      _CategorySectionItem(label: 'Ethnic', icon: Icons.local_florist_outlined),
      _CategorySectionItem(label: 'Fusion', icon: Icons.style_outlined),
      _CategorySectionItem(label: 'Beauty', icon: Icons.face_retouching_natural_outlined),
    ],
    'Kids': const [
      _CategorySectionItem(label: 'Playwear', icon: Icons.toys_rounded),
      _CategorySectionItem(label: 'Festive', icon: Icons.celebration_rounded),
      _CategorySectionItem(label: 'School', icon: Icons.backpack_outlined),
      _CategorySectionItem(label: 'Sneakers', icon: Icons.directions_run_rounded),
    ],
  };

  int _selectedTabIndex = 0;
  int _selectedCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentTab = _tabs[_selectedTabIndex];
    final categories =
        _categoryMap[currentTab] ?? _categoryMap['All'] ?? const <_CategorySectionItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _quickFilters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final label = _quickFilters[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F6F6),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE6E6E6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 14,
                      color: Color(0xFF8A8A8A),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF3E3E3E),
                          ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _tabs.length,
            separatorBuilder: (context, index) => const SizedBox(width: 20),
            itemBuilder: (context, index) {
              final tab = _tabs[index];
              final isSelected = _selectedTabIndex == index;
              return TapScale(
                onTap: () {
                  if (_selectedTabIndex == index) {
                    return;
                  }
                  setState(() {
                    _selectedTabIndex = index;
                    _selectedCategoryIndex = 0;
                  });
                },
                child: InkWell(
                  onTap: () {
                    if (_selectedTabIndex == index) {
                      return;
                    }
                    setState(() {
                      _selectedTabIndex = index;
                      _selectedCategoryIndex = 0;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          tab,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected
                                    ? AbzioTheme.textPrimary
                                    : context.abzioSecondaryText,
                              ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          width: isSelected ? 24 : 8,
                          height: 3,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFC9A74E)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: SizedBox(
            key: ValueKey(currentTab),
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = _selectedCategoryIndex == index;
                return TapScale(
                  onTap: () {
                    if (_selectedCategoryIndex == index) {
                      return;
                    }
                    setState(() => _selectedCategoryIndex = index);
                  },
                  child: InkWell(
                    onTap: () {
                      if (_selectedCategoryIndex == index) {
                        return;
                      }
                      setState(() => _selectedCategoryIndex = index);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: 76,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFC9A74E).withValues(alpha: 0.16)
                                  : const Color(0xFFF6F4EE),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFC9A74E)
                                    : context.abzioBorder,
                              ),
                            ),
                            child: Icon(
                              category.icon,
                              size: 26,
                              color: isSelected
                                  ? const Color(0xFFC9A74E)
                                  : AbzioTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            category.label,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                  color: isSelected
                                      ? AbzioTheme.textPrimary
                                      : context.abzioSecondaryText,
                                  height: 1.1,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CategorySectionItem {
  const _CategorySectionItem({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
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
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.abzioSecondaryText,
                fontSize: 13,
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
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFECE5D4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: AbzioTheme.accentColor,
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
                          fontWeight: FontWeight.w800,
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
                          color: context.abzioSecondaryText,
                          height: 1.3,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => provider.radiusKm < 25
                  ? provider.setRadiusKm(25)
                  : showLocationBottomSheet(context),
              child: Text(
                provider.radiusKm < 25 ? 'Expand' : 'Change',
              ),
            ),
          ],
        ),
      ),
      if (products.isNotEmpty) ...[
        const SizedBox(height: 10),
        SizedBox(
          height: 236,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) => SizedBox(
              width: 150,
              child: ProductCard(
                product: products[index],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: products[index]),
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

Widget _compactAiStylistStrip({required VoidCallback onTap}) {
  return Builder(
    builder: (context) => TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 12,
              offset: const Offset(0, 6),
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
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fit help, outfit ideas, and styling in one tap',
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AbzioTheme.accentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Open',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
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
  final PageController _pageController = PageController();
  final BackendApiClient _apiClient = const BackendApiClient();

  late final Future<List<BannerModel>> _bannersFuture;

  int _currentIndex = 0;

  static const List<BannerModel> _staticFallbackBanners = [
    BannerModel(
      imageUrl: 'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&q=80&w=1200',
      title: 'Top-rated stores around you',
      subtitle: 'Handpicked fashion destinations',
      ctaText: 'View Stores',
      redirectType: 'store',
      redirectId: '',
    ),
    BannerModel(
      imageUrl: 'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&q=80&w=1200',
      title: 'Wedding edits worth arriving for',
      subtitle: 'Handpicked fashion destinations',
      ctaText: 'Discover',
      redirectType: 'category',
      redirectId: 'Wedding',
    ),
    BannerModel(
      imageUrl: 'https://images.unsplash.com/photo-1496747611176-843222e1e57c?auto=format&fit=crop&q=80&w=1200',
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
    _pageController.dispose();
    super.dispose();
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

        if (snapshot.connectionState == ConnectionState.waiting &&
            (snapshot.data == null || snapshot.data!.isEmpty)) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 214,
              color: Theme.of(context).cardColor,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Color(0xFFC9A74E),
              ),
            ),
          );
        }

        return Column(
          children: [
            SizedBox(
              height: 214,
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(slide.imageUrl, fit: BoxFit.cover),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.10),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.58),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'TRENDING NOW',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                slide.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                slide.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () => widget.onBannerTap(slide),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF111111),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  slide.ctaText.isEmpty ? 'View Stores' : slide.ctaText,
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
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                slides.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentIndex == index ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentIndex == index ? const Color(0xFFC9A74E) : const Color(0xFFD2D2D2),
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
  const _AiOutfitSection({
    required this.user,
    required this.onOpenAiStylist,
  });

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
    symbol: '₹',
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
      return value.replaceFirst('under_', 'Under ₹').replaceAll('_', '');
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
                  visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
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
                  child: ShimmerBox(borderRadius: BorderRadius.all(Radius.circular(12))),
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
                    SizedBox(height: 32, width: 88, child: ShimmerBox(borderRadius: BorderRadius.all(Radius.circular(10)))),
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
                            imageUrl: items.first.images.isNotEmpty ? items.first.images.first : '',
                            fallbackLabel: items.first.name,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF121212).withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${outfit.matchScore}% match',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: context.abzioSecondaryText.withValues(alpha: 0.88),
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
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Shop',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Curated looks from your style profile',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showFilters ? Icons.expand_less_rounded : Icons.chevron_right_rounded,
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
                                                fallbackLabel: items.length > 1 ? items[1].name : 'ABZORA',
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
                                                fallbackLabel: items.length > 2 ? items[2].name : 'ABZORA',
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
      const SizedBox(height: 8),
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
