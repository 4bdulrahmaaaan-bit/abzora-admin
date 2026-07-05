import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app_shell.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/global_skeletons.dart';
import '../../widgets/tap_scale.dart';
import '../../utils/app_mode_routes.dart';
import '../login_screen.dart';
import 'address_screen.dart';
import 'chat_list_screen.dart';
import 'edit_profile_screen.dart';
import 'faq_screen.dart';
import 'profile_completion_flow_screen.dart';
import 'notifications_screen.dart';
import 'order_tracking_screen.dart';
import 'referral_screen.dart';
import 'saved_fit_profile_screen.dart';
import 'wishlist_screen.dart';
import '../../features/legal/legal_consent_screen.dart';
import '../../features/legal/legal_document_registry.dart';
import '../../features/legal/legal_policy_hub_screen.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final DatabaseService _database = DatabaseService();
  Future<List<MeasurementProfile>>? _measurementFuture;
  Future<BodyProfile?>? _bodyProfileFuture;
  Future<_ProfileSetupSnapshot>? _profileSetupFuture;
  Future<UserMemory?>? _memoryFuture;
  Future<_ProfileValueSnapshot>? _profileValueFuture;
  String? _measurementUserId;
  String? _bodyProfileUserId;
  String? _profileSetupUserId;
  String? _memoryUserId;
  String? _profileValueUserId;
  AppUser? _cachedProfileUser;
  ImageProvider<Object>? _cachedProfileImageProvider;
  String _cachedProfileFingerprint = '';
  String _cachedProfileImageUrl = '';
  bool _profileHydrated = false;
  bool _isRefreshingProfile = false;
  bool _openingProfileCompletion = false;
  AuthProvider? _authProvider;
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
      CurvedAnimation(parent: _revealController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (!identical(_authProvider, auth)) {
      _authProvider?.removeListener(_handleProfileSourceChanged);
      _authProvider = auth;
      _authProvider?.addListener(_handleProfileSourceChanged);
      _syncProfileFromAuth(force: true);
    }
  }

  void _handleProfileSourceChanged() {
    if (!mounted) {
      return;
    }
    _syncProfileFromAuth();
  }

  void _syncProfileFromAuth({bool force = false}) {
    final auth = _authProvider;
    if (auth == null) {
      return;
    }

    final nextUser = auth.user;
    final nextFingerprint = _profileFingerprint(nextUser);
    final nextImageUrl = nextUser?.profileImageUrl?.trim() ?? '';
    final shouldBeReady = auth.isInitialized;
    final userChanged =
        force ||
        !_profileHydrated ||
        nextFingerprint != _cachedProfileFingerprint ||
        (_cachedProfileUser?.id ?? '') != (nextUser?.id ?? '');
    final imageChanged = nextImageUrl != _cachedProfileImageUrl;

    if (userChanged || shouldBeReady != _profileHydrated) {
      setState(() {
        _cachedProfileUser = nextUser;
        _cachedProfileFingerprint = nextFingerprint;
        _profileHydrated = shouldBeReady;
        if (!shouldBeReady) {
          _cachedProfileImageProvider = null;
          _cachedProfileImageUrl = '';
        }
      });
    }

    if (nextUser == null) {
      return;
    }

    if (imageChanged) {
      if (nextImageUrl.isEmpty) {
        setState(() {
          _cachedProfileImageUrl = '';
          _cachedProfileImageProvider = null;
        });
      } else {
        unawaited(_cacheProfileImage(nextImageUrl));
      }
    }
  }

  Future<void> _cacheProfileImage(String url) async {
    if (url.isEmpty) {
      return;
    }
    _cachedProfileImageUrl = url;
    final provider = NetworkImage(url);
    try {
      await precacheImage(provider, context);
    } catch (_) {
      return;
    }
    if (!mounted || _cachedProfileImageUrl != url) {
      return;
    }
    setState(() {
      _cachedProfileImageProvider = provider;
    });
  }

  Future<void> _refreshProfile() async {
    final auth = _authProvider;
    if (auth == null) {
      return;
    }
    setState(() => _isRefreshingProfile = true);
    try {
      await auth.refreshCurrentUser();
    } finally {
      if (mounted) {
        setState(() => _isRefreshingProfile = false);
      }
    }
  }

  String _profileFingerprint(AppUser? user) {
    if (user == null) {
      return 'guest';
    }
    return [
      user.id,
      user.name,
      user.email,
      user.profileImageUrl ?? '',
      user.phone ?? '',
      user.address ?? '',
      user.area ?? '',
      user.city ?? '',
      user.latitude?.toStringAsFixed(6) ?? '',
      user.longitude?.toStringAsFixed(6) ?? '',
      user.deliveryRadiusKm.toStringAsFixed(2),
      user.locationUpdatedAt ?? '',
      user.createdAt ?? '',
      user.role,
      user.isActive.toString(),
      user.storeId ?? '',
      user.walletBalance.toStringAsFixed(2),
      user.roles.toString(),
      user.riderApprovalStatus,
      user.riderVehicleType ?? '',
      user.riderLicenseNumber ?? '',
      user.riderCity ?? '',
      user.referralCode ?? '',
      user.referredBy ?? '',
    ].join('|');
  }

  Widget _buildProfileLoadingScaffold(BuildContext context) {
    return AbzioThemeScope.dark(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDFC),
        appBar: AppBar(title: const Text('Profile')),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _profileHeaderSkeleton(),
                const SizedBox(height: 14),
                const ShimmerCard(height: 88),
                const SizedBox(height: 14),
                const ShimmerCard(height: 180),
                const SizedBox(height: 14),
                const ShimmerCard(height: 220),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = _authProvider ?? context.read<AuthProvider>();
    final user = _cachedProfileUser ?? auth.user;
    if (!auth.isInitialized || !_profileHydrated || _isRefreshingProfile) {
      return _buildProfileLoadingScaffold(context);
    }
    if (user == null) {
      return AbzioThemeScope.dark(
        child: Scaffold(
          backgroundColor: const Color(0xFFFFFDFC),
          appBar: AppBar(title: const Text('Profile')),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              child: _buildGuestModeProfile(context),
            ),
          ),
        ),
      );
    }

    final String actualName = user.name.trim();
    final String actualPhone = user.phone?.trim() ?? '';
    final bool hasName = actualName.isNotEmpty;

    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    final nameParts = actualName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final greetingText = hasName ? '$timeGreeting, $firstName' : timeGreeting;

    final name = hasName ? actualName : 'Complete Your Profile';
    final phone = hasName
        ? (actualPhone.isNotEmpty ? actualPhone : 'No phone linked')
        : 'Add your name and details';
    final address = user.address?.trim().isNotEmpty == true
        ? user.address!.trim()
        : 'Set location';
    final city = _extractCity(address);

    return AbzioThemeScope.dark(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDFC),
        appBar: AppBar(title: const Text('Profile')),
        body: SafeArea(
          child: RefreshIndicator(
            color: AbzioTheme.accentColor,
            backgroundColor: const Color(0xFFFFFDFC),
            onRefresh: _refreshProfile,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _reveal(
                        0.00,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greetingText,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
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
                        _buildProfileHeaderCard(
                          context,
                          auth: auth,
                          user: user,
                          name: name,
                          phone: phone,
                          profileImageProvider: _cachedProfileImageProvider,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _reveal(0.04, _buildValueStrip(context, user)),
                      const SizedBox(height: 24),
                      _reveal(
                        0.06,
                        _sectionTitle(
                          eyebrow: 'AI Support',
                          title: 'Instant help for styling and orders',
                          subtitle:
                              'A premium assistant for fit questions, order support, and next-look guidance.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _reveal(
                        0.08,
                        StreamBuilder<List<SupportChat>>(
                          stream: _database.watchSupportChatsForUser(
                            actor: user,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return _buildAiSupportState(
                                context,
                                subtitle: 'Instant help for styling and orders',
                                badgeLabel: 'Live',
                              );
                            }
                            final chats =
                                snapshot.data ?? const <SupportChat>[];
                            final unreadCount = chats.fold<int>(
                              0,
                              (sum, chat) => sum + chat.unreadCountUser,
                            );
                            final openChats = chats
                                .where((chat) => chat.status != 'closed')
                                .length;
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
                                    badgeLabel: unreadCount > 0
                                        ? '$unreadCount new'
                                        : 'Live',
                                  );
                                }
                                final memory = memorySnapshot.data;
                                final memorySummary = memory == null
                                    ? ''
                                    : [
                                        if (memory.preferredStyle
                                            .trim()
                                            .isNotEmpty)
                                          'Style: ${memory.preferredStyle.trim()}',
                                        if (memory.size.trim().isNotEmpty)
                                          'Size: ${memory.size.trim()}',
                                        if (memory.lastConversationSummary
                                            .trim()
                                            .isNotEmpty)
                                          memory.lastConversationSummary.trim(),
                                      ].join(' • ');
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
                      const SizedBox(height: 24),
                      _reveal(0.14, _quickActionGrid(context)),
                      const SizedBox(height: 24),
                      _reveal(
                        0.22,
                        _sectionTitle(
                          eyebrow: 'Profile • Fit Profile',
                          title: 'Your Fit Profile',
                          subtitle:
                              'Personalized sizing recommendations for better shopping.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _reveal(0.28, _styleSection(context, user)),
                      const SizedBox(height: 24),
                      _reveal(
                        0.32,
                        _sectionTitle(
                          eyebrow: 'Account • Essentials',
                          title: 'Shopping Essentials',
                          subtitle:
                              'Manage delivery locations and payment preferences.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _reveal(0.34, _buildShoppingEssentials(context, city)),
                      const SizedBox(height: 24),
                      _reveal(
                        0.38,
                        _sectionTitle(
                          eyebrow: 'Rewards',
                          title: 'Referrals & Offers',
                          subtitle:
                              'Invite friends, earn style credits, and unlock drops.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _reveal(0.40, _buildRewardsSection(context)),
                      const SizedBox(height: 24),

                      _reveal(
                        0.50,
                        _sectionTitle(
                          eyebrow: 'Account',
                          title: 'Manage your preferences',
                          subtitle:
                              'Delivery, payments, and notifications tuned for a seamless shopping flow.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _reveal(
                        0.56,
                        FutureBuilder<_ProfileSetupSnapshot>(
                          future: _profileSetupFor(user.id),
                          builder: (context, snapshot) {
                            final loading =
                                snapshot.connectionState ==
                                ConnectionState.waiting;
                            final setup = snapshot.data;
                            return _buildSettingsList(
                              context,
                              city,
                              showCompleteProfileCard:
                                  !loading && !(setup?.isComplete ?? false),
                              showCompletionLoading: loading,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      _reveal(0.60, _buildLegalPolicyEntry(context)),
                      const SizedBox(height: 24),
                      _reveal(
                        0.64,
                        _sectionTitle(
                          eyebrow: 'Sell',
                          title: 'Sell on Abianzo',
                          subtitle: 'Onboard as a premium fashion vendor.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _reveal(0.66, _buildSellerEntry(context)),
                      const SizedBox(height: 28),
                      _reveal(
                        0.68,
                        OutlinedButton.icon(
                          onPressed: () => _confirmLogout(context),
                          icon: Icon(
                            Icons.logout_rounded,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.72),
                          ),
                          label: const Text(
                            'Logout',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.78),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.72,
                            ),
                            side: BorderSide(
                              color: context.abzioBorder.withValues(
                                alpha: 0.70,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ]),
                  ),
                ),
              ],
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _reveal(
          0.00,
          Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Hero(
                  tag: 'auth-brand-logo',
                  child: BrandLogo.hero(
                    size: 72,
                    radius: 20,
                    backgroundColor: Colors.white,
                    assetPath: brandAssetForMode(AbzioAppMode.customer),
                    padding: const EdgeInsets.all(4),
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Your Abianzo Account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF151515),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to access AI Fit, AR Try-On history, wishlist and orders.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6A5E4E),
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        _reveal(
          0.03,
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
                backgroundColor: AbzioTheme.accentColor,
                foregroundColor: const Color(0xFF111111),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Continue with Phone',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111111),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        _reveal(
          0.06,
          _GuestSection(
            title: 'Quick Access',
            subtitle: 'Shortcuts for shopping, fit, and support.',
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.08,
              children: [
                _GuestQuickAccessCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Orders',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const LoginScreen(mode: AbzioAppMode.customer),
                      ),
                    );
                  },
                ),
                _GuestQuickAccessCard(
                  icon: Icons.favorite_border_rounded,
                  title: 'Wishlist',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const LoginScreen(mode: AbzioAppMode.customer),
                      ),
                    );
                  },
                ),
                _GuestQuickAccessCard(
                  icon: Icons.auto_awesome_outlined,
                  title: 'AI Fit Profile',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const LoginScreen(mode: AbzioAppMode.customer),
                      ),
                    );
                  },
                ),
                _GuestQuickAccessCard(
                  icon: Icons.help_outline_rounded,
                  title: 'Help Center',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FaqScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _reveal(
          0.10,
          _GuestSection(
            title: 'Abianzo Features',
            subtitle: 'Built around fit intelligence and premium discovery.',
            child: Column(
              children: const [
                _GuestFeatureCard(
                  icon: Icons.straighten_rounded,
                  title: 'AI Fit',
                  subtitle:
                      'Personalized sizing recommendations powered by AI.',
                ),
                SizedBox(height: 12),
                _GuestFeatureCard(
                  icon: Icons.view_in_ar_rounded,
                  title: 'AR Try-On',
                  subtitle: 'See styles on yourself before buying.',
                ),
                SizedBox(height: 12),
                _GuestFeatureCard(
                  icon: Icons.storefront_outlined,
                  title: 'Nearby Boutiques',
                  subtitle: 'Discover premium local fashion stores near you.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _reveal(
          0.14,
          _GuestSection(
            title: 'Support',
            subtitle: 'Help is always a tap away.',
            child: Column(
              children: [
                _GuestLinkRow(
                  title: 'Help Center',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FaqScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _GuestLinkRow(
                  title: 'Contact Us',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatListScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _GuestLinkRow(
                  title: 'FAQs',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FaqScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _reveal(
          0.18,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Legal',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF8A7A63),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 10,
                children: [
                  _GuestLegalLink(
                    label: 'About Us',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LegalPolicyHubScreen(
                            audience: LegalAudience.common,
                            title: 'About Abianzo',
                          ),
                        ),
                      );
                    },
                  ),
                  _GuestLegalLink(
                    label: 'Terms & Conditions',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LegalConsentScreen(
                            audience: LegalAudience.customer,
                          ),
                        ),
                      );
                    },
                  ),
                  _GuestLegalLink(
                    label: 'Privacy Policy',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LegalPolicyHubScreen(
                            audience: LegalAudience.common,
                            title: 'Privacy Policy',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _profileHeaderSkeleton() {
    return const ShimmerProfileHeader();
  }

  Widget _buildProfileHeaderCard(
    BuildContext context, {
    required AuthProvider auth,
    required AppUser? user,
    required String name,
    required String phone,
    ImageProvider<Object>? profileImageProvider,
  }) {
    final completionScore = _profileCompletion(user);
    final initials = _profileInitials(user?.name ?? '');
    final cachedImageProvider = profileImageProvider;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                          child: cachedImageProvider == null
                              ? const BrandLogo(
                                  size: 60,
                                  radius: 17,
                                  padding: EdgeInsets.all(1.5),
                                )
                              : Image(
                                  image: cachedImageProvider,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const BrandLogo(
                                        size: 60,
                                        radius: 17,
                                        padding: EdgeInsets.all(1.5),
                                      ),
                                ),
                        ),
                      ),
                    ),
                    if (initials.isNotEmpty)
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
                              color: AbzioTheme.accentColor.withValues(
                                alpha: 0.28,
                              ),
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
                      style: TextStyle(
                        color: context.abzioSecondaryText,
                        fontSize: 13,
                      ),
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
                      child: Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (completionScore >= 100)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F9F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle, color: Color(0xFFC6A769), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Profile Verified',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                    ),
                  ),
                ],
              ),
            )
          else ...[
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
          ],
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
        child: const Row(
          children: [
            Expanded(
              child: _ProfileValueCell(
                label: 'Wallet',
                value: '\u20B90',
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            _ProfileValueDivider(),
            Expanded(
              child: _ProfileValueCell(
                label: 'Rewards',
                value: '0 pts',
                icon: Icons.stars_outlined,
              ),
            ),
            _ProfileValueDivider(),
            Expanded(
              child: _ProfileValueCell(
                label: 'Orders',
                value: '0',
                icon: Icons.shopping_bag_outlined,
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<_ProfileValueSnapshot>(
      future: _profileValuesFor(user),
      builder: (context, snapshot) {
        final values = snapshot.data;
        final rewardPoints = snapshot.hasError
            ? 0
            : (values?.rewardPoints ?? 0);
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
                  message:
                      'Private offers and promo coupons will show up here.',
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
    if (user == null) return const SizedBox.shrink();
    return FutureBuilder<_StyleProfileSnapshot>(
      future: _styleSnapshotFor(user.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();

        final styleSnapshot = snapshot.data;
        final bodyProfile = styleSnapshot?.bodyProfile;

        final subtitle = bodyProfile != null
            ? '${bodyProfile.recommendedSize.isNotEmpty ? bodyProfile.recommendedSize : 'M'} Fit • Updated ${_relativeScanTime(bodyProfile.updatedAt)}'
            : 'View and manage your saved measurements';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _buildListItem(
            icon: Icons.straighten_rounded,
            title: 'Saved Fit Profile',
            subtitle: subtitle,
            onTap: () => _push(context, const SavedFitProfileScreen()),
            minimal: true,
          ),
        );
      },
    );
  }

  Widget _buildShoppingEssentials(BuildContext context, String city) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildListItem(
            icon: Icons.location_on_outlined,
            title: 'Addresses',
            subtitle: city == 'Location pending'
                ? 'Add your preferred delivery spot'
                : 'Deliver to $city',
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
        ],
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
                    style: TextStyle(
                      color: context.abzioSecondaryText,
                      height: 1.35,
                    ),
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
          color: AbzioTheme.accentColor.withValues(
            alpha: lightweight ? 0.16 : 0.22,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AbzioTheme.accentColor.withValues(
              alpha: lightweight ? 0.04 : 0.06,
            ),
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
                    color: minimal
                        ? const Color(0xFFF6F3EC)
                        : const Color(0xFFFFF4D8),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: minimal
                        ? null
                        : [
                            BoxShadow(
                              color: AbzioTheme.accentColor.withValues(
                                alpha: 0.08,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Icon(
                    icon,
                    color: minimal
                        ? const Color(0xFF8E7A58)
                        : Theme.of(context).colorScheme.onSurface,
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
                          if (badgeLabel != null &&
                              badgeLabel.trim().isNotEmpty) ...[
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
                                  color: AbzioTheme.accentColor.withValues(
                                    alpha: 0.22,
                                  ),
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
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: context.abzioSecondaryText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsList(
    BuildContext context,
    String city, {
    required bool showCompleteProfileCard,
    required bool showCompletionLoading,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          if (showCompletionLoading) ...[
            const ShimmerListItem(),
            _minimalDivider(context),
          ] else if (showCompleteProfileCard) ...[
            _buildListItem(
              icon: Icons.verified_rounded,
              title: 'Complete Your Profile',
              subtitle: 'Address, fit profile, and payment in one guided flow',
              onTap: _openProfileCompletion,
              minimal: true,
            ),
            _minimalDivider(context),
          ],
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

  Widget _buildRewardsSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
              message:
                  'Curated rewards and luxury member offers will be available here.',
            ),
            minimal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSellerEntry(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildListItem(
        icon: Icons.storefront_outlined,
        title: 'Sell on Abianzo',
        subtitle: 'Start selling fashion products on the marketplace',
        onTap: () => Navigator.of(context).pushNamed('/vendor-onboarding'),
        minimal: true,
      ),
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
            style: TextStyle(color: context.abzioSecondaryText, height: 1.45),
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
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
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
          return const _ProfileValueSnapshot(orderCount: 0, rewardPoints: 0);
        }
      }();
    }
    return _profileValueFuture!;
  }

  String _formatCurrency(double value) {
    final whole = value == value.roundToDouble();
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: whole ? 0 : 2,
    ).format(value);
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
      return '';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
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

  Future<_ProfileSetupSnapshot> _profileSetupFor(String userId) {
    if (_profileSetupUserId != userId || _profileSetupFuture == null) {
      _profileSetupUserId = userId;
      _profileSetupFuture = () async {
        try {
          final results = await Future.wait<Object?>([
            _database.getUserAddresses(userId),
            _database.getBodyProfile(userId),
            _database.getPreferredPaymentMethod(userId),
          ]);
          final addresses = results[0] as List<UserAddress>;
          final bodyProfile = results[1] as BodyProfile?;
          final paymentMethod = results[2] as String?;
          return _ProfileSetupSnapshot(
            addressDone: addresses.isNotEmpty,
            fitDone: bodyProfile != null,
            paymentDone:
                paymentMethod != null && paymentMethod.trim().isNotEmpty,
          );
        } catch (error) {
          debugPrint('Profile setup snapshot fallback for $userId: $error');
          return const _ProfileSetupSnapshot(
            addressDone: false,
            fitDone: false,
            paymentDone: false,
          );
        }
      }();
    }
    return _profileSetupFuture!;
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
      final text = error.toString().toLowerCase();
      final isAuthFallback =
          text.contains('unauthorized') ||
          text.contains('sign in again') ||
          text.contains('session expired') ||
          text.contains('too many authentication requests');
      if (!isAuthFallback) {
        debugPrint('Profile style snapshot fallback for $userId: $error');
      }
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
    final shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AbzioTheme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Logout'),
            content: const Text(
              'Are you sure you want to log out from Abianzo?',
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
    await authProvider.logout(resetNavigation: true, showSuccessMessage: true);
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _openProfileCompletion() async {
    if (!mounted || _openingProfileCompletion) {
      return;
    }
    setState(() => _openingProfileCompletion = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileCompletionFlowScreen()),
      );
      if (mounted) {
        _profileSetupFuture = null;
        _profileSetupUserId = null;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      debugPrint('Failed to open profile completion flow: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Profile setup is temporarily unavailable.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingProfileCompletion = false);
      }
    }
  }

  void _showPaymentMethodsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.24),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 32,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
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
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose how you want to pay',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
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
                                  content: Text(
                                    'Cash on Delivery is available on eligible orders.',
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFCF4),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AbzioTheme.accentColor.withValues(
                                  alpha: 0.12,
                                ),
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
                                Expanded(
                                  child: Text(
                                    '100% secure payments',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
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
              );
            },
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
                  child: Icon(icon, color: AbzioTheme.accentColor),
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
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AbzioTheme.accentColor.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badge,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
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
              style: const TextStyle(color: AbzioTheme.grey600, height: 1.45),
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

  Widget _buildLegalPolicyEntry(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(eyebrow: 'Legal', title: 'Legal & Policies'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _buildListItem(
            icon: Icons.gavel_rounded,
            title: 'Legal & Policies',
            subtitle: 'Manage legal documents and privacy settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalPolicyHubScreen(
                  audience: LegalAudience.customer,
                  title: 'Customer Legal Center',
                ),
              ),
            ),
            minimal: true,
          ),
        ),
      ],
    );
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

class _GuestSection extends StatelessWidget {
  const _GuestSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0E8D8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6F614D),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _GuestQuickAccessCard extends StatelessWidget {
  const _GuestQuickAccessCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      scale: 0.98,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF0E8D8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F0E3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: const Color(0xFF8D6A28), size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1C),
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

class _GuestFeatureCard extends StatelessWidget {
  const _GuestFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E8D8)),
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F0E3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF8D6A28), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6F614D),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestLinkRow extends StatelessWidget {
  const _GuestLinkRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      scale: 0.99,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0E8D8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E1B16),
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF8D6A28),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestLegalLink extends StatelessWidget {
  const _GuestLegalLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      scale: 0.99,
      onTap: onTap,
      child: ActionChip(
        onPressed: onTap,
        label: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF8D6A28),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: const Color(0xFFFFFCF8),
        side: const BorderSide(color: Color(0xFFEFE4D3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

class _ProfileSetupSnapshot {
  const _ProfileSetupSnapshot({
    required this.addressDone,
    required this.fitDone,
    required this.paymentDone,
  });

  final bool addressDone;
  final bool fitDone;
  final bool paymentDone;

  bool get isComplete => addressDone && fitDone && paymentDone;
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
        Icon(icon, size: 16, color: const Color(0xFF9A8258)),
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
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.60),
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
