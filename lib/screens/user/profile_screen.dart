import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_shell.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/global_skeletons.dart';
import '../../widgets/shimmer_box.dart';
import '../../widgets/state_views.dart';
import '../../widgets/tap_scale.dart';
import '../atelier/atelier_flow_screen.dart';
import '../login_screen.dart';
import '../tailoring/tailoring_flow_screen.dart';
import 'address_screen.dart';
import 'body_scan_screen.dart';
import 'chat_list_screen.dart';
import 'edit_profile_screen.dart';
import 'faq_screen.dart';
import 'notifications_screen.dart';
import 'order_tracking_screen.dart';
import 'referral_screen.dart';
import 'wishlist_screen.dart';
import '../vendor/vendor_onboarding_screen.dart';
import '../vendor/vendor_registration_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _database = DatabaseService();
  Future<List<MeasurementProfile>>? _measurementFuture;
  Future<BodyProfile?>? _bodyProfileFuture;
  Future<UserMemory?>? _memoryFuture;
  Future<_ProfileValueSnapshot>? _profileValueFuture;
  String? _measurementUserId;
  String? _bodyProfileUserId;
  String? _memoryUserId;
  String? _profileValueUserId;
  late final AnimationController _revealController;
  late final Animation<double> _revealOpacity;
  late final Animation<double> _revealOffset;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _revealOpacity = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutCubic,
    );
    _revealOffset = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return AbzioThemeScope.dark(
        child: Scaffold(
          backgroundColor: const Color(0xFFFFFDFC),
          appBar: AppBar(title: const Text('Profile')),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              child: _buildGuestModeProfile(context),
            ),
          ),
        ),
      );
    }

    final name = user.name.trim().isNotEmpty ? user.name.trim() : 'ABZORA Member';
    final nameParts = name.split(' ').where((part) => part.trim().isNotEmpty).toList();
    final firstName = nameParts.isEmpty ? 'there' : nameParts.first;
    final phone = user.phone?.trim().isNotEmpty == true ? user.phone!.trim() : 'No phone linked';
    final address = user.address?.trim().isNotEmpty == true ? user.address!.trim() : 'Set location';
    final city = _extractCity(address);

    return AbzioThemeScope.dark(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDFC),
        appBar: AppBar(title: const Text('Profile')),
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      _reveal(
                        0.00,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good evening, $firstName âœ¨',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your next outfit is waiting',
                              style: TextStyle(
                                color: context.abzioSecondaryText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _reveal(
                        0.02,
                        StreamBuilder<AppUser?>(
                                stream: _database.watchUser(user.id),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting &&
                                      !snapshot.hasData) {
                                    return _profileHeaderSkeleton();
                                  }
                                  if (snapshot.hasError) {
                                    return _buildEliteCard(
                                      context,
                                      auth: auth,
                                      user: user,
                                      name: name,
                                      phone: phone,
                                      city: city,
                                      address: address,
                                    );
                                  }
                                  final liveUser = snapshot.data ?? user;
                                  final liveName = liveUser.name.trim().isNotEmpty
                                      ? liveUser.name.trim()
                                      : 'ABZORA Member';
                                  final livePhone = liveUser.phone?.trim().isNotEmpty == true
                                      ? liveUser.phone!.trim()
                                      : 'No phone linked';
                                  final liveAddress = liveUser.address?.trim().isNotEmpty == true
                                      ? liveUser.address!.trim()
                                      : 'Set location';
                                  return _buildEliteCard(
                                    context,
                                    auth: auth,
                                    user: liveUser,
                                    name: liveName,
                                    phone: livePhone,
                                    city: _extractCity(liveAddress),
                                    address: liveAddress,
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 14),
                      _reveal(0.04, _buildValueStrip(context, user)),
                      const SizedBox(height: 18),
                      _reveal(0.06, _atelierEntryCard(context)),
                      const SizedBox(height: 26),
                      _reveal(
                        0.08,
                        _sectionTitle(
                          eyebrow: 'Quick Access',
                          title: 'Your fashion dashboard',
                          subtitle: 'Orders, saved edits, offers, and support arranged with clear hierarchy.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _reveal(0.14, _quickActionGrid(context)),
                      const SizedBox(height: 24),
                      _reveal(
                        0.22,
                        _sectionTitle(
                          eyebrow: 'Style Profile',
                          title: 'Fit intelligence and tailoring',
                          subtitle: 'Body scan insights, saved measurements, and custom-piece progress in one luxury workspace.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _reveal(0.28, _styleSection(context, user)),
                      const SizedBox(height: 24),
                      _reveal(
                        0.36,
                        _sectionTitle(
                          eyebrow: 'Account',
                          title: 'Manage your preferences',
                          subtitle: 'Delivery, payments, and notifications tuned for a seamless shopping flow.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _reveal(0.42, _buildSettingsList(context, city)),
                      const SizedBox(height: 24),
                      _reveal(
                        0.50,
                        _sectionTitle(
                          eyebrow: 'Growth',
                          title: 'Grow with ABZORA',
                          subtitle: 'Partner opportunities, referral rewards, and premium member perks.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _reveal(0.56, _buildGrowthSection(context)),
                      const SizedBox(height: 24),
                      _reveal(
                        0.64,
                        _sectionTitle(
                          eyebrow: 'AI Support',
                          title: 'Instant help for styling and orders',
                          subtitle: 'A premium assistant for fit questions, order support, and next-look guidance.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _reveal(
                        0.70,
                        StreamBuilder<List<SupportChat>>(
                                stream: _database.watchSupportChatsForUser(actor: user),
                                builder: (context, snapshot) {
                                  if (snapshot.hasError) {
                                    return _buildAiSupportState(
                                      context,
                                      subtitle: 'Instant help for styling and orders',
                                      badgeLabel: 'Live',
                                    );
                                  }
                                  final chats = snapshot.data ?? const <SupportChat>[];
                                  final unreadCount = chats.fold<int>(
                                    0,
                                    (sum, chat) => sum + chat.unreadCountUser,
                                  );
                                  final openChats = chats.where((chat) => chat.status != 'closed').length;
                                  return FutureBuilder<UserMemory?>(
                                    future: _memoryFor(user.id),
                                    builder: (context, memorySnapshot) {
                                      if (memorySnapshot.hasError) {
                                        return _buildAiSupportState(
                                          context,
                                          subtitle: unreadCount > 0
                                              ? '$unreadCount new assistant repl${unreadCount == 1 ? 'y' : 'ies'}'
                                              : openChats > 0
                                                  ? '$openChats active assistant conversation${openChats == 1 ? '' : 's'}'
                                                  : 'Instant help for styling and orders',
                                          badgeLabel: unreadCount > 0 ? '$unreadCount new' : 'Live',
                                        );
                                      }
                                      final memory = memorySnapshot.data;
                                      final memorySummary = memory == null
                                          ? ''
                                          : [
                                              if (memory.preferredStyle.trim().isNotEmpty)
                                                'Style: ${memory.preferredStyle.trim()}',
                                              if (memory.size.trim().isNotEmpty)
                                                'Size: ${memory.size.trim()}',
                                              if (memory.lastConversationSummary.trim().isNotEmpty)
                                                memory.lastConversationSummary.trim(),
                                            ].join(' â€¢ ');
                                      final supportSubtitle = unreadCount > 0
                                          ? '$unreadCount new assistant repl${unreadCount == 1 ? 'y' : 'ies'}'
                                          : openChats > 0
                                              ? '$openChats active assistant conversation${openChats == 1 ? '' : 's'}'
                                              : memorySummary.isNotEmpty
                                                  ? memorySummary
                                                  : 'Instant help for orders, payments, and custom styles';

                                      return _buildAiSupportState(
                                        context,
                                        subtitle: supportSubtitle,
                                        badgeLabel: unreadCount > 0
                                            ? '$unreadCount new'
                                            : memorySummary.isNotEmpty
                                                ? 'Memory On'
                                                : 'Live',
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 28),
                      _reveal(
                        0.78,
                        OutlinedButton.icon(
                          onPressed: () => _confirmLogout(context),
                          icon: Icon(
                            Icons.logout_rounded,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
                          ),
                          label: const Text(
                            'Logout',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
                            backgroundColor: Colors.white.withValues(alpha: 0.72),
                            side: BorderSide(color: context.abzioBorder.withValues(alpha: 0.70)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reveal(double start, Widget child) {
    final clampedStart = start.clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _revealController,
      curve: Interval(clampedStart, 1.0, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, builtChild) {
        return Opacity(
          opacity: _revealOpacity.value * animation.value,
          child: Transform.translate(
            offset: Offset(0, _revealOffset.value * (1 - animation.value)),
            child: builtChild,
          ),
        );
      },
    );
  }

  Widget _buildGuestModeProfile(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final liveProducts = productProvider.trendingProducts
        .where((product) => product.isActive)
        .take(8)
        .toList();
    final contextProduct = liveProducts.isNotEmpty ? liveProducts.first : null;
    final recentlyViewed = liveProducts.skip(1).take(6).toList();
    final hasLastViewedData = recentlyViewed.isNotEmpty;
    final recommendedSize = _guestSizeRecommendation(contextProduct);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _reveal(
          0.00,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFCF5), Color(0xFFF5E9D3)],
              ),
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
                Text(
                  'Welcome back to your style \u{1F44B}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1711),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pick up where you left off and keep your perfect fit saved',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6A5E4E),
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _reveal(
          0.03,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEFE4D3)),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2D2A26), Color(0xFF5C5242)],
                      ),
                    ),
                    child: contextProduct != null && contextProduct.images.isNotEmpty
                        ? Image.network(
                            contextProduct.images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.checkroom_rounded,
                              color: Color(0xFFF6EAD3),
                            ),
                          )
                        : const Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFFF6EAD3),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasLastViewedData ? 'Last viewed' : 'Trending now',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF8A7A63),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contextProduct?.name ?? 'Premium Satin Edit',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF20190F),
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        recommendedSize,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF5E5344),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _reveal(
          0.06,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(
                      mode: AbzioAppMode.customer,
                      deferredAction: true,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
              ),
              child: Ink(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFFB9924A), Color(0xFFC6A769), Color(0xFFD6BF8B)],
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Continue with Phone \u2192',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A140B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _reveal(
          0.08,
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _GuestBenefitChip(icon: Icons.local_shipping_outlined, label: 'Track your orders'),
              _GuestBenefitChip(icon: Icons.favorite_border_rounded, label: 'Save your wishlist'),
              _GuestBenefitChip(icon: Icons.straighten_rounded, label: 'Get AI-powered fit'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _reveal(
          0.10,
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/home'),
              child: Text(
                'Skip for now',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF7D7264),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _reveal(
          0.14,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Continue browsing',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF8A7A63),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Recently Viewed',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1712),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _reveal(
          0.18,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: recentlyViewed.isNotEmpty
                  ? [
                      for (var i = 0; i < recentlyViewed.length; i++) ...[
                        _GuestJourneyCard(
                          title: recentlyViewed[i].name,
                          subtitle: recentlyViewed[i].brand.trim().isNotEmpty
                              ? recentlyViewed[i].brand.trim()
                              : recentlyViewed[i].category,
                          price: 'Rs ${recentlyViewed[i].effectivePrice.toStringAsFixed(0)}',
                          accent: i.isEven ? const Color(0xFFF6EAD3) : const Color(0xFFF4EFE4),
                          imageUrl: recentlyViewed[i].images.isNotEmpty ? recentlyViewed[i].images.first : null,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/product-detail',
                            arguments: recentlyViewed[i],
                          ),
                        ),
                        if (i != recentlyViewed.length - 1) const SizedBox(width: 12),
                      ],
                    ]
                  : const [
                      _GuestJourneyCard(
                        title: 'Satin Drape Dress',
                        subtitle: 'Modern evening silhouette',
                        price: 'From Rs 2,499',
                        accent: Color(0xFFF6EAD3),
                      ),
                      SizedBox(width: 12),
                      _GuestJourneyCard(
                        title: 'Structured Blazer Set',
                        subtitle: 'Polished fit for workwear',
                        price: 'From Rs 1,899',
                        accent: Color(0xFFF4EFE4),
                      ),
                      SizedBox(width: 12),
                      _GuestJourneyCard(
                        title: 'Linen Co-ord Edit',
                        subtitle: 'Breezy premium weekend look',
                        price: 'From Rs 1,599',
                        accent: Color(0xFFF8F1DF),
                      ),
                    ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _reveal(
          0.24,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: const Color(0xFFEFE5D3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7EEDC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.home_work_outlined,
                    color: Color(0xFF8D6A28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Try at Home',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try 5 styles at home. Pay only for what you keep',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF6A6156),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/home'),
                  child: const Text(
                    'Explore',
                    style: TextStyle(
                      color: Color(0xFF8D6A28),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _reveal(
          0.30,
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _GuestTrustBadge(
                icon: Icons.assignment_return_outlined,
                label: 'Free returns',
              ),
              _GuestTrustBadge(
                icon: Icons.lock_outline_rounded,
                label: 'Secure checkout',
              ),
              _GuestTrustBadge(
                icon: Icons.verified_outlined,
                label: 'Verified sellers',
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
  bool get _showLegacyAtelierTeaser => false;

  Widget _buildEliteCard(
    BuildContext context, {
    required AuthProvider auth,
    required AppUser? user,
    required String name,
    required String phone,
    required String city,
    required String address,
  }) {
    final completionScore = _profileCompletion(user);
    final initials = _profileInitials(name);
    final profileImageUrl = user?.profileImageUrl?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        color: const Color(0xFFFFFCF8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFFFFF8EC),
                  border: Border.all(
                    color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(1.5),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(17),
                          child: profileImageUrl.isEmpty
                              ? const BrandLogo(
                                  size: 60,
                                  radius: 17,
                                  padding: EdgeInsets.all(1.5),
                                )
                              : Image.network(
                                  profileImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const BrandLogo(
                                    size: 60,
                                    radius: 17,
                                    padding: EdgeInsets.all(1.5),
                                  ),
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) {
                                      return child;
                                    }
                                    return const ShimmerBox(
                                      width: 60,
                                      height: 60,
                                      borderRadius: BorderRadius.all(Radius.circular(17)),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AbzioTheme.accentColor.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      phone,
                      style: TextStyle(color: context.abzioSecondaryText, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: AbzioTheme.accentColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TapScale(
                onTap: () => _editProfile(context),
                scale: 0.92,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _editProfile(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(Icons.edit_outlined, size: 18, color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TapScale(
            onTap: () => _showComingSoon(
              context,
              title: 'ABZORA Elite',
              message: 'Elite membership perks, concierge support, and private drops will appear here.',
            ),
            child: _eliteBadge(),
          ),
          const SizedBox(height: 14),
          if (_showLegacyAtelierTeaser) TapScale(
            onTap: () => _push(context, const AtelierFlowScreen()),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AbzioTheme.accentColor.withValues(alpha: 0.20),
                ),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AbzioTheme.accentColor.withValues(alpha: 0.14),
                    const Color(0xFFFFFCF5),
                    Colors.white,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AbzioTheme.accentColor.withValues(alpha: 0.08),
                    blurRadius: 22,
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.design_services_rounded,
                      color: AbzioTheme.accentColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start your custom fit journey',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Design clothes tailored just for you',
                          style: TextStyle(
                            color: context.abzioSecondaryText,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AbzioTheme.accentColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create Custom Outfit â†’',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: completionScore / 100),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.abzioBorder.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value.clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: const Color(0xFFD6BA67),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$completionScore%',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Complete your profile to unlock faster checkout',
            style: TextStyle(
              color: context.abzioSecondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (auth.isUpdatingProfile) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              minHeight: 3,
              color: AbzioTheme.accentColor,
              backgroundColor: context.abzioBorder,
            ),
          ],
        ],
      ),
    );
  }

  Widget _eliteBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE2C46D),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_outlined, size: 16, color: Colors.black),
          SizedBox(width: 8),
          Text(
            'Unlock ABZORA Elite',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueStrip(BuildContext context, AppUser? user) {
    if (user == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: const [
            Expanded(child: _ProfileValueCell(label: 'Wallet', value: 'â‚¹0', icon: Icons.account_balance_wallet_outlined)),
            _ProfileValueDivider(),
            Expanded(child: _ProfileValueCell(label: 'Rewards', value: '0 pts', icon: Icons.stars_outlined)),
            _ProfileValueDivider(),
            Expanded(child: _ProfileValueCell(label: 'Orders', value: '0', icon: Icons.shopping_bag_outlined)),
          ],
        ),
      );
    }

    return FutureBuilder<_ProfileValueSnapshot>(
      future: _profileValuesFor(user),
      builder: (context, snapshot) {
        final values = snapshot.data;
        final rewardPoints = snapshot.hasError ? 0 : (values?.rewardPoints ?? 0);
        final orderCount = snapshot.hasError ? 0 : (values?.orderCount ?? 0);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _ProfileValueCell(
                  label: 'Wallet',
                  value: _formatCurrency(user.walletBalance),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const _ProfileValueDivider(),
              Expanded(
                child: _ProfileValueCell(
                  label: 'Rewards',
                  value: '$rewardPoints pts',
                  icon: Icons.stars_outlined,
                ),
              ),
              const _ProfileValueDivider(),
              Expanded(
                child: _ProfileValueCell(
                  label: 'Orders',
                  value: '$orderCount',
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _atelierEntryCard(BuildContext context) {
    return TapScale(
      onTap: () => _push(context, const AtelierFlowScreen()),
      scale: 0.97,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF221A14),
              Color(0xFF3A2A1C),
              Color(0xFF15110E),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: AbzioTheme.accentColor.withValues(alpha: 0.16),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -16,
              top: -20,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AbzioTheme.accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.30)),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFF4DEAC),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Start Your Atelier Journey',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Design your own outfit',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4DEAC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Begin Custom Piece',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.black),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _quickActionCard(
                context,
                icon: Icons.receipt_long_rounded,
                title: 'My Orders',
                subtitle: 'Track every order',
                onTap: () => _push(context, const OrderTrackingScreen()),
                featured: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickActionCard(
                context,
                icon: Icons.favorite_outline_rounded,
                title: 'Wishlist',
                subtitle: 'Your saved pieces',
                onTap: () => _push(context, const WishlistScreen()),
                featured: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _quickActionCard(
                context,
                icon: Icons.local_offer_outlined,
                title: 'Coupons',
                subtitle: 'Exclusive savings',
                onTap: () => _showComingSoon(
                  context,
                  title: 'Coupons',
                  message: 'Private offers and promo coupons will show up here.',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickActionCard(
                context,
                icon: Icons.support_agent_rounded,
                title: 'Support',
                subtitle: 'Help when you need it',
                onTap: () => _push(context, const ChatListScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _styleSection(BuildContext context, AppUser? user) {
      if (user == null) {
        return const AbzioEmptyCard(
          title: 'Sign in to unlock custom clothing',
          subtitle: 'Your measurements, made-to-order fits, and styling progress will appear here.',
        );
      }

      final normalizedRole = user.role.trim().toLowerCase();
      if (normalizedRole == 'vendor' || normalizedRole == 'rider') {
        return const AbzioEmptyCard(
          title: 'Customer style profile only',
          subtitle: 'Measurements, body scans, and fit memory are available in the customer shopping experience.',
        );
      }

      return FutureBuilder<_StyleProfileSnapshot>(
        future: _styleSnapshotFor(user.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const AbzioEmptyCard(
            title: 'Style profile unavailable right now',
            subtitle: 'Measurements and smart-fit details could not be loaded, but the rest of your profile is still available.',
          );
        }
        final styleSnapshot = snapshot.data;
        final measurementProfiles =
            styleSnapshot?.measurementProfiles ?? const <MeasurementProfile>[];
        final bodyProfile = styleSnapshot?.bodyProfile;
        final measurementsSubtitle = snapshot.connectionState == ConnectionState.waiting
            ? 'Checking your saved fit profiles'
            : measurementProfiles.isEmpty
                ? 'Save your measurements for perfect fit'
                : '${measurementProfiles.length} saved profile${measurementProfiles.length == 1 ? '' : 's'} ready to use';
        final scanSubtitle = snapshot.connectionState == ConnectionState.waiting
            ? 'Preparing your smart fit status'
            : bodyProfile == null
                ? 'Get perfect fit using camera'
                : 'Last scanned ${_relativeScanTime(bodyProfile.updatedAt)}';

        final fitInsight = bodyProfile == null
            ? 'Complete a scan to unlock better fit recommendations.'
            : bodyProfile.recommendedSize.trim().isNotEmpty
                ? 'Fit insight: ${bodyProfile.recommendedSize.trim()} works best with your saved profile.'
                : 'Fit insight: your body profile is ready for smarter tailoring suggestions.';

        return Column(
          children: [
            _styleHighlightCard(
              context,
              icon: Icons.accessibility_new_rounded,
              title: 'Scan My Body',
              subtitle: scanSubtitle,
              badgeLabel: bodyProfile == null ? 'Recommended' : 'Fit Ready',
              highlighted: true,
              onTap: () => _push(context, const BodyScanScreen()),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF2),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.14)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AbzioTheme.accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: AbzioTheme.accentColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      fitInsight,
                      style: TextStyle(
                        color: context.abzioSecondaryText,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _styleHighlightCard(
                    context,
                    icon: Icons.straighten_rounded,
                    title: 'Saved Measurements',
                    subtitle: measurementsSubtitle,
                    compact: true,
                    onTap: () => _push(context, const CustomTailoringFlowScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _styleHighlightCard(
                    context,
                    icon: Icons.auto_awesome_outlined,
                    title: 'Custom Orders',
                    subtitle: 'Review your bespoke pieces',
                    compact: true,
                    onTap: () => _push(context, const AtelierFlowScreen()),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _styleHighlightCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool highlighted = false,
    String? badgeLabel,
    bool compact = false,
  }) {
    return TapScale(
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: highlighted ? const Color(0xFFFFFBF4) : Colors.white,
              border: Border.all(
                color: highlighted
                    ? AbzioTheme.accentColor.withValues(alpha: 0.20)
                    : context.abzioBorder.withValues(alpha: 0.55),
                width: 1,
              ),
            ),
              child: Padding(
                padding: EdgeInsets.all(compact ? 16 : highlighted ? 20 : 18),
                child: Row(
                  children: [
                  if (!compact) ...[
                    Container(
                      width: 3,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: const Color(0xFFD8BE74),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Container(
                    width: compact ? 42 : 48,
                    height: compact ? 42 : 48,
                    decoration: BoxDecoration(
                      color: highlighted ? const Color(0xFFFFF7E7) : const Color(0xFFF7F3EB),
                      borderRadius: BorderRadius.circular(compact ? 14 : 16),
                    ),
                    child: Icon(icon, color: const Color(0xFF9F8452)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (badgeLabel != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8EDC9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badgeLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          title,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: compact ? 15 : highlighted ? 17 : 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: context.abzioSecondaryText,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: context.abzioSecondaryText),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool featured = false,
  }) {
    return TapScale(
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: featured
                      ? Colors.black.withValues(alpha: 0.055)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: featured ? 18 : 14,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(featured ? 20 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: featured ? 52 : 44,
                    height: featured ? 52 : 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F2E7),
                      borderRadius: BorderRadius.circular(featured ? 18 : 14),
                    ),
                    child: Icon(icon, color: const Color(0xFF9F8452)),
                  ),
                  SizedBox(height: featured ? 28 : 20),
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: featured ? 17 : 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: context.abzioSecondaryText, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListSection({
    required List<Widget> children,
    bool lightweight = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AbzioTheme.accentColor.withValues(alpha: lightweight ? 0.16 : 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: AbzioTheme.accentColor.withValues(alpha: lightweight ? 0.04 : 0.06),
            blurRadius: lightweight ? 12 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 72),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: context.abzioBorder.withValues(alpha: 0.5),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildListItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badgeLabel,
    bool minimal = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: TapScale(
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: minimal ? const Color(0xFFF6F3EC) : const Color(0xFFFFF4D8),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: minimal
                        ? null
                        : [
                            BoxShadow(
                              color: AbzioTheme.accentColor.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Icon(
                    icon,
                    color: minimal ? const Color(0xFF8E7A58) : Theme.of(context).colorScheme.onSurface,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (badgeLabel != null && badgeLabel.trim().isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3CB),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AbzioTheme.accentColor.withValues(alpha: 0.22),
                                ),
                              ),
                              child: Text(
                                badgeLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AbzioTheme.accentColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: context.abzioSecondaryText,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.arrow_forward_ios_rounded, size: 15, color: context.abzioSecondaryText),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vendorOnboardingCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    String? badge,
  }) {
    return TapScale(
      onTap: onTap,
      scale: 0.97,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withValues(alpha: 0.90),
              border: Border.all(color: context.abzioBorder.withValues(alpha: 0.75)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AbzioTheme.accentColor.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Icon(icon, color: AbzioTheme.accentColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: context.abzioSecondaryText,
                            height: 1.4,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CB),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AbzioTheme.accentColor.withValues(alpha: 0.20),
                              ),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AbzioTheme.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AbzioTheme.accentColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context, String city) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildListItem(
            icon: Icons.location_on_outlined,
            title: 'Addresses',
            subtitle: city == 'Location pending' ? 'Add your preferred delivery spot' : 'Deliver to $city',
            onTap: () => _editAddress(context),
            minimal: true,
          ),
          _minimalDivider(context),
          _buildListItem(
            icon: Icons.credit_card_outlined,
            title: 'Payment Methods',
            subtitle: 'Secure cards and UPI options',
            onTap: () => _showPaymentMethodsSheet(context),
            minimal: true,
          ),
          _minimalDivider(context),
          _buildListItem(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: 'Order, offer, and delivery alerts',
            onTap: () => _push(context, const NotificationsScreen()),
            minimal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthSection(BuildContext context) {
    return Column(
      children: [
        _vendorOnboardingCard(
          context,
          title: 'Join as Ready-Made Vendor',
          subtitle: 'Sell in-stock fashion products and grow with marketplace demand.',
          icon: Icons.storefront_outlined,
          badge: 'Ready-Made',
          onTap: () => _push(context, const VendorRegistrationScreen()),
        ),
        const SizedBox(height: 12),
        _vendorOnboardingCard(
          context,
          title: 'Join as Custom Atelier Vendor',
          subtitle: 'Offer made-to-measure tailoring with premium client workflows.',
          icon: Icons.design_services_outlined,
          badge: 'Atelier',
          onTap: () => _push(context, const VendorOnboardingScreen()),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _buildListItem(
                icon: Icons.card_giftcard_rounded,
                title: 'Refer & Earn',
                subtitle: 'Invite friends and unlock style credits',
                onTap: () => _push(context, const ReferralScreen()),
                minimal: true,
              ),
              _minimalDivider(context),
              _buildListItem(
                icon: Icons.local_offer_outlined,
                title: 'Offers & Rewards',
                subtitle: 'Private drops, loyalty perks, and seasonal edits',
                onTap: () => _showComingSoon(
                  context,
                  title: 'Offers & rewards',
                  message: 'Curated rewards and luxury member offers will be available here.',
                ),
                minimal: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _minimalDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Divider(
        height: 1,
        thickness: 0.7,
        color: context.abzioBorder.withValues(alpha: 0.28),
      ),
    );
  }

  Widget _sectionTitle({
    required String eyebrow,
    required String title,
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            color: AbzioTheme.accentColor,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: context.abzioSecondaryText,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAiSupportState(
    BuildContext context, {
    required String subtitle,
    required String badgeLabel,
  }) {
    final safeSubtitle = subtitle.trim().isEmpty
        ? 'Instant help for styling and orders'
        : subtitle;
    final safeBadge = badgeLabel.trim().isEmpty ? 'Live' : badgeLabel;

    return Column(
      children: [
        TapScale(
          onTap: () => _push(context, const ChatListScreen()),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B1612),
                  Color(0xFF2A221A),
                  Color(0xFFEFE5D6),
                ],
                stops: [0.0, 0.62, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE5CF98),
                    boxShadow: [
                      BoxShadow(
                        color: AbzioTheme.accentColor.withValues(alpha: 0.18),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.black,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'AI Assistant',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEBD7A2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              safeBadge,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        safeSubtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.80),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildListSection(
          lightweight: true,
          children: [
            _buildListItem(
              icon: Icons.help_outline_rounded,
              title: 'FAQs',
              subtitle: 'Answers to the most common questions',
              onTap: () => _push(context, const FaqScreen()),
            ),
          ],
        ),
      ],
    );
  }

  Future<_ProfileValueSnapshot> _profileValuesFor(AppUser user) {
    if (_profileValueUserId != user.id || _profileValueFuture == null) {
      _profileValueUserId = user.id;
      _profileValueFuture = () async {
        try {
          final values = await Future.wait<Object>([
            _database.getUserOrdersOnce(user.id),
            _database.getReferralDashboard(user),
          ]);
          final orders = values[0] as List<OrderModel>;
          final referral = values[1] as ReferralDashboardData;
          return _ProfileValueSnapshot(
            orderCount: orders.length,
            rewardPoints: referral.earnedCredits.round(),
          );
        } catch (error) {
          debugPrint('Profile value strip fallback for ${user.id}: $error');
          return const _ProfileValueSnapshot(
            orderCount: 0,
            rewardPoints: 0,
          );
        }
      }();
    }
    return _profileValueFuture!;
  }

  String _formatCurrency(double value) {
    final whole = value == value.roundToDouble();
    return whole ? 'â‚¹${value.toStringAsFixed(0)}' : 'â‚¹${value.toStringAsFixed(2)}';
  }

  String _extractCity(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty || trimmed == 'Add your delivery address') {
      return 'Location pending';
    }
    final parts = trimmed
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return trimmed;
    }
    if (parts.length >= 2) {
      return parts[parts.length - 2];
    }
    return parts.first;
  }

  int _profileCompletion(AppUser? user) {
    if (user == null) {
      return 20;
    }
    var score = 35;
    if (user.name.trim().isNotEmpty) score += 20;
    if ((user.phone ?? '').trim().isNotEmpty) score += 15;
    if ((user.address ?? '').trim().isNotEmpty) score += 20;
    if ((user.city ?? '').trim().isNotEmpty) score += 10;
    return score.clamp(20, 100);
  }

  String _profileInitials(String name) {
    final parts = name
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'A';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  String _relativeScanTime(String updatedAt) {
    final parsed = DateTime.tryParse(updatedAt);
    if (parsed == null) {
      return 'recently';
    }
    final difference = DateTime.now().difference(parsed);
    if (difference.inDays >= 2) {
      return '${difference.inDays} days ago';
    }
    if (difference.inDays == 1) {
      return 'yesterday';
    }
    if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    }
    return 'today';
  }

  Future<List<MeasurementProfile>> _measurementProfilesFor(String userId) {
    if (_measurementUserId != userId || _measurementFuture == null) {
      _measurementUserId = userId;
      _measurementFuture = _database.getMeasurementProfiles(userId);
    }
    return _measurementFuture!;
  }

  Future<BodyProfile?> _bodyProfileFor(String userId) {
    if (_bodyProfileUserId != userId || _bodyProfileFuture == null) {
      _bodyProfileUserId = userId;
      _bodyProfileFuture = _database.getBodyProfile(userId);
    }
    return _bodyProfileFuture!;
  }

  Future<_StyleProfileSnapshot> _styleSnapshotFor(String userId) async {
    try {
      final values = await Future.wait<Object?>([
        _measurementProfilesFor(userId),
        _bodyProfileFor(userId),
      ]);
      return _StyleProfileSnapshot(
        measurementProfiles: values[0]! as List<MeasurementProfile>,
        bodyProfile: values[1] as BodyProfile?,
      );
    } catch (error) {
      debugPrint('Profile style snapshot fallback for $userId: $error');
      return const _StyleProfileSnapshot(
        measurementProfiles: <MeasurementProfile>[],
        bodyProfile: null,
      );
    }
  }

  Future<UserMemory?> _memoryFor(String userId) {
    if (_memoryUserId != userId || _memoryFuture == null) {
      _memoryUserId = userId;
      _memoryFuture = _database.getUserMemory(userId);
    }
    return _memoryFuture!;
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AbzioTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Logout'),
            content: const Text(
              'Are you sure you want to log out from ABZORA?',
              style: TextStyle(color: AbzioTheme.grey600),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Color(0xFFE35D5B)),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldLogout) {
      return;
    }

    if (!mounted) {
      return;
    }
    await authProvider.logout(
      resetNavigation: true,
      showSuccessMessage: true,
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  String _guestSizeRecommendation(Product? product) {
    if (product == null) {
      return 'Size recommendation: M (most selected)';
    }
    final normalized = product.sizes
        .map((size) => size.trim().toUpperCase())
        .where((size) => size.isNotEmpty)
        .toSet();
    const preferenceOrder = ['M', 'L', 'S', 'XL', 'XS', 'XXL'];
    for (final preferred in preferenceOrder) {
      if (normalized.contains(preferred)) {
        return 'Size recommendation: $preferred';
      }
    }
    return 'Size recommendation: ${normalized.isEmpty ? 'M' : normalized.first}';
  }

  void _showPaymentMethodsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.24),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 32,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.abzioBorder,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Add Payment Method',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose how you want to pay',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.abzioSecondaryText,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 18),
                    _paymentActionTile(
                      context,
                      icon: Icons.credit_card_rounded,
                        title: 'Credit / Debit Card',
                        subtitle: 'Visa, Mastercard, RuPay',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.pushNamed(context, '/add-card');
                        },
                      ),
                    const SizedBox(height: 14),
                    _paymentActionTile(
                      context,
                      icon: Icons.qr_code_2_rounded,
                      title: 'UPI',
                      subtitle: 'Google Pay, PhonePe, Paytm',
                      badge: 'Fastest',
                      recommended: true,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.pushNamed(context, '/payments');
                      },
                    ),
                    const SizedBox(height: 14),
                    _paymentActionTile(
                      context,
                      icon: Icons.payments_outlined,
                      title: 'Cash on Delivery',
                      subtitle: 'Pay when order arrives',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text('Cash on Delivery is available on eligible orders.'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFCF4),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            color: AbzioTheme.accentColor,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '100% secure payments',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            Navigator.pushNamed(context, '/payments');
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
    bool recommended = false,
  }) {
    return TapScale(
      onTap: onTap,
      scale: 0.95,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: recommended
                    ? AbzioTheme.accentColor.withValues(alpha: 0.20)
                    : context.abzioBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AbzioTheme.accentColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: AbzioTheme.accentColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AbzioTheme.accentColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badge,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AbzioTheme.textPrimary,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.abzioSecondaryText,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AbzioTheme.accentColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoon(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AbzioTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AbzioTheme.grey300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AbzioTheme.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: AbzioTheme.grey600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAddress(BuildContext context) async {
    final current = context.read<AuthProvider>().user;
    if (current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to manage your address.')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddressScreen()),
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final current = context.read<AuthProvider>().user;
    if (current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to edit your profile.')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  Widget _profileHeaderSkeleton() {
    return const ShimmerProfileHeader();
  }
}

class _StyleProfileSnapshot {
  const _StyleProfileSnapshot({
    required this.measurementProfiles,
    required this.bodyProfile,
  });

  final List<MeasurementProfile> measurementProfiles;
  final BodyProfile? bodyProfile;
}

class _GuestBenefitChip extends StatelessWidget {
  const _GuestBenefitChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AbzioTheme.accentColor.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: const Color(0xFF7C5E23),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF3B3022),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _GuestJourneyCard extends StatelessWidget {
  const _GuestJourneyCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.accent,
    this.imageUrl,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String price;
  final Color accent;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scale: 0.98,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            width: 196,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEFE4D3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 108,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent,
                          const Color(0xFFF9F4EA),
                        ],
                      ),
                    ),
                    child: imageUrl?.trim().isNotEmpty == true
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.checkroom_rounded,
                              color: Color(0xFF8D6A28),
                            ),
                          )
                        : const Icon(
                            Icons.checkroom_rounded,
                            color: Color(0xFF8D6A28),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF20190F),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6F614D),
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  price,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8D6A28),
                        fontWeight: FontWeight.w800,
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

class _GuestTrustBadge extends StatelessWidget {
  const _GuestTrustBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEE5D4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF8D6A28)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF342A1D),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProfileValueSnapshot {
  const _ProfileValueSnapshot({
    required this.orderCount,
    required this.rewardPoints,
  });

  final int orderCount;
  final int rewardPoints;
}

class _ProfileValueCell extends StatelessWidget {
  const _ProfileValueCell({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF9A8258),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProfileValueDivider extends StatelessWidget {
  const _ProfileValueDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: AbzioTheme.accentColor.withValues(alpha: 0.10),
      margin: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}

