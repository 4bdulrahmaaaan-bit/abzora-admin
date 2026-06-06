import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:provider/provider.dart';

import 'utils/app_mode_routes.dart';
import 'models/models.dart';
import 'providers/auth_provider.dart';
import 'providers/banner_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/location_provider.dart';
import 'providers/network_provider.dart';
import 'providers/product_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/trial_home_provider.dart';
import 'providers/wishlist_provider.dart';
import 'screens/login_screen.dart';
import 'screens/ops/ops_account_screen.dart';
import 'screens/ops/ops_shell_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/rider/rider_dashboard.dart';
import 'screens/rider/rider_onboarding_screen.dart';
import 'screens/admin/admin_analytics_screen.dart';
import 'screens/admin/admin_web_panel.dart';
import 'screens/user/cart_screen.dart';
import 'screens/user/chat_list_screen.dart';
import 'screens/user/checkout_screen.dart';
import 'screens/user/address_screen.dart';
import 'screens/user/add_card_screen.dart';
import 'screens/user/home_screen.dart';
import 'screens/user/notifications_screen.dart';
import 'screens/user/order_tracking_screen.dart';
import 'screens/user/fast_delivery_tracking_screen.dart';
import 'screens/user/payment_methods_screen.dart';
import 'screens/user/profile_completion_flow_screen.dart';
import 'screens/user/product_detail_screen.dart';
import 'screens/user/profile_screen.dart';
import 'screens/user/referral_screen.dart';
import 'screens/user/role_selection_screen.dart';
import 'screens/user/signup_screen.dart';
import 'screens/user/video_feed_screen.dart';
import 'features/invoices/presentation/screens/invoice_hub_screen.dart';
import 'features/invoices/presentation/screens/invoice_history_screen.dart';
import 'features/invoices/presentation/screens/invoice_details_screen.dart';
import 'features/invoices/presentation/screens/invoice_pdf_viewer_screen.dart';
import 'features/invoices/presentation/screens/refund_timeline_screen.dart';
import 'features/invoices/presentation/screens/credit_note_screen.dart';
import 'screens/admin/admin_kyc_screen.dart';
import 'screens/admin/admin_orders_screen.dart';
import 'screens/admin/admin_payouts_screen.dart';
import 'screens/admin/admin_riders_screen.dart';
import 'screens/admin/admin_vendors_screen.dart';
import 'screens/vendor/vendor_dashboard.dart';
import 'screens/vendor/vendor_profile_screen.dart';
import 'features/legal/legal_consent_screen.dart';
import 'features/legal/legal_consent_service.dart';
import 'features/legal/legal_document_registry.dart';
import 'features/legal/legal_policy_hub_screen.dart';
import 'features/legal/legal_versioning.dart';
import 'services/app_navigation_service.dart';
import 'services/app_bootstrap_service.dart';
import 'services/notification_service.dart';
import 'theme.dart';
import 'widgets/offline_widgets.dart';
import 'widgets/safe_widget.dart';

enum AbzioAppMode { unified, customer, operations, vendor, rider }

Future<void> bootstrapAndRun(AbzioAppMode mode) async {
  await bootstrapAndRunWithInitialRoute(mode);
}

Future<void> bootstrapAndRunWithInitialRoute(
  AbzioAppMode mode, {
  String initialRoute = '/',
}) async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      _installGlobalErrorHandling();
      await AppBootstrapService().initialize();
      final imageCache = PaintingBinding.instance.imageCache;
      imageCache.maximumSizeBytes = 200 << 20;
      imageCache.maximumSize = 1000;

      runApp(
        ProviderScope(
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthProvider()),
              ChangeNotifierProvider(create: (_) => BannerProvider()),
              ChangeNotifierProxyProvider<AuthProvider, CartProvider>(
                create: (_) => CartProvider(),
                update: (_, authProvider, cartProvider) {
                  final provider = cartProvider ?? CartProvider();
                  unawaited(provider.syncUser(authProvider.user));
                  return provider;
                },
              ),
              ChangeNotifierProvider(create: (_) => LocationProvider()),
              ChangeNotifierProvider(
                create: (_) => NetworkProvider()..initialize(),
              ),
              ChangeNotifierProxyProvider<LocationProvider, ProductProvider>(
                create: (_) => ProductProvider(),
                update: (_, locationProvider, productProvider) {
                  final provider = productProvider ?? ProductProvider();
                  provider.attachLocationProvider(locationProvider);
                  return provider;
                },
              ),
              ChangeNotifierProxyProvider<AuthProvider, WishlistProvider>(
                create: (_) => WishlistProvider(),
                update: (_, authProvider, wishlistProvider) {
                  final provider = wishlistProvider ?? WishlistProvider();
                  provider.syncUser(authProvider.user);
                  return provider;
                },
              ),
              ChangeNotifierProvider(create: (_) => TrialHomeProvider()),
              ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ],
            child: AbzioApp(mode: mode, initialRoute: initialRoute),
          ),
        ),
      );
    },
    (error, stackTrace) {
      debugPrint('Abianzo zoned error: $error');
      debugPrintStack(stackTrace: stackTrace);
    },
  );
}

void _installGlobalErrorHandling() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Abianzo Flutter error: ${details.exception}');
    if (details.stack != null) {
      debugPrintStack(stackTrace: details.stack);
    }
  };

  ErrorWidget.builder = (details) {
    return AbzioGlobalErrorView(
      message:
          'This part of the app had a problem, but you can keep using Abianzo.',
      onRetry: () {
        final navigator = AbzioApp.navigatorKey.currentState;
        navigator?.pushNamedAndRemoveUntil('/', (route) => false);
      },
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    debugPrint('Abianzo platform error: $error');
    debugPrintStack(stackTrace: stackTrace);
    return true;
  };
}

class AbzioApp extends StatelessWidget {
  const AbzioApp({
    super.key,
    this.mode = AbzioAppMode.unified,
    this.initialRoute = '/',
  });

  final AbzioAppMode mode;
  final String initialRoute;

  static final GlobalKey<NavigatorState> navigatorKey =
      AppNavigationService.navigatorKey;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: AppNavigationService.navigatorKey,
      scaffoldMessengerKey: AppNavigationService.messengerKey,
      title: appTitleForMode(mode),
      debugShowCheckedModeBanner: false,
      theme: AbzioTheme.lightTheme,
      darkTheme: AbzioTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return Stack(
          children: [
            AbzioSafeWidget(
              builder: (_) => child,
              fallbackBuilder: (context, error, stackTrace) =>
                  AbzioGlobalErrorView(
                    message:
                        'We hit a UI issue, but you can safely return to the app.',
                    onRetry: () {
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pushNamedAndRemoveUntil('/', (route) => false);
                    },
                  ),
            ),
            const AbzioNetworkBanner(),
          ],
        );
      },
      initialRoute: initialRoute,
      routes: {
        '/': (context) => _AppLaunchGate(mode: mode),
        '/login': (context) => LoginScreen(
          mode: mode,
          adminEntry: kIsWeb && mode == AbzioAppMode.unified,
        ),
        '/admin-login': (context) =>
            const LoginScreen(mode: AbzioAppMode.unified, adminEntry: true),
        '/otp': (context) => OtpVerificationScreen(mode: mode),
        '/admin': (context) => _AdminRoute(mode: mode),
        '/admin-orders': (context) => const AdminOrdersScreen(),
        '/admin-vendors': (context) => const AdminVendorsScreen(),
        '/admin-riders': (context) => const AdminRidersScreen(),
        '/admin-payouts': (context) => const AdminPayoutsScreen(),
        '/admin-analytics': (context) => const AdminAnalyticsScreen(),
        '/signup': (context) => const SignupScreen(),
        '/shop': (context) => const HomeScreen(),
        '/home': (context) => const HomeScreen(),
        '/ops': (context) {
          if (mode == AbzioAppMode.vendor) {
            return const VendorDashboard();
          }
          if (mode == AbzioAppMode.rider) {
            return const RiderDashboard();
          }
          return const OpsShellScreen();
        },
        '/profile': (context) => mode == AbzioAppMode.vendor
            ? const VendorProfileScreen()
            : isPartnerMode(mode)
            ? OpsAccountScreen(mode: mode)
            : const ProfileScreen(),
        '/addresses': (context) => const AddressScreen(),
        '/add-card': (context) => const AddCardScreen(),
        '/payments': (context) => const PaymentMethodsScreen(),
        '/profile-completion': (context) => const ProfileCompletionFlowScreen(),
        '/profile-setup': (context) => const RiderOnboardingScreen(),
        '/cart': (context) => const CartScreen(),
        '/checkout': (context) => const CheckoutScreen(),
        '/orders': (context) => const OrderTrackingScreen(),
        '/chats': (context) => const ChatListScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/referral': (context) => const ReferralScreen(),
        '/become-partner': (context) => const RoleSelectionScreen(),
        '/admin-kyc': (context) => const AdminKycScreen(),
        '/video-feed': (context) => const VideoFeedScreen(),
        '/vendor-dashboard': (context) => const VendorDashboard(),
        '/vendor-profile': (context) => const VendorProfileScreen(),
        '/rider-dashboard': (context) => const RiderDashboard(),
        '/invoice/hub': (context) => const InvoiceHubScreen(),
        '/invoice/history': (context) => const InvoiceHistoryScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/fast-tracking' &&
            settings.arguments is OrderModel) {
          return MaterialPageRoute(
            builder: (_) => FastDeliveryTrackingScreen(
              order: settings.arguments as OrderModel,
            ),
            settings: settings,
          );
        }
        if (settings.name == '/product-detail' &&
            settings.arguments is Product) {
          return MaterialPageRoute(
            builder: (_) =>
                ProductDetailScreen(product: settings.arguments as Product),
            settings: settings,
          );
        }
        if (settings.name == '/invoice/details' &&
            settings.arguments is String) {
          return MaterialPageRoute(
            builder: (_) =>
                InvoiceDetailsScreen(invoiceId: settings.arguments as String),
            settings: settings,
          );
        }
        if (settings.name == '/invoice/pdf' && settings.arguments is String) {
          return MaterialPageRoute(
            builder: (_) =>
                InvoicePdfViewerScreen(invoiceId: settings.arguments as String),
            settings: settings,
          );
        }
        if (settings.name == '/invoice/refund-timeline') {
          final args = settings.arguments is Map<String, dynamic>
              ? settings.arguments as Map<String, dynamic>
              : const <String, dynamic>{};
          return MaterialPageRoute(
            builder: (_) => RefundTimelineScreen(
              steps:
                  (args['steps'] as List?)?.map((e) => e.toString()).toList() ??
                  const <String>[],
            ),
            settings: settings,
          );
        }
        if (settings.name == '/invoice/credit-note') {
          final args = settings.arguments is Map<String, dynamic>
              ? settings.arguments as Map<String, dynamic>
              : const <String, dynamic>{};
          return MaterialPageRoute(
            builder: (_) => CreditNoteScreen(
              creditNoteNumber: (args['creditNoteNumber'] ?? '').toString(),
              amount: (args['amount'] as num?)?.toDouble() ?? 0,
            ),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}

class _AppLaunchGate extends StatefulWidget {
  const _AppLaunchGate({required this.mode});

  final AbzioAppMode mode;

  @override
  State<_AppLaunchGate> createState() => _AppLaunchGateState();
}

class _AppLaunchGateState extends State<_AppLaunchGate> {
  bool _didRoute = false;
  bool _didScheduleRoute = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool get _wantsAdminEntryFromUrl {
    if (!kIsWeb) {
      return false;
    }
    final path = Uri.base.path.toLowerCase();
    return path == '/admin' ||
        path == '/admin-login' ||
        path.startsWith('/admin/');
  }

  PageRouteBuilder<void> _launchRoute(Widget page) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnimation =
            Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
    );
  }

  Widget _launchDestinationForRoute(String route, AppUser? user) {
    switch (route) {
      case '/login':
        return LoginScreen(
          mode: widget.mode,
          adminEntry: kIsWeb && widget.mode == AbzioAppMode.unified,
        );
      case '/admin-login':
        return const LoginScreen(mode: AbzioAppMode.unified, adminEntry: true);
      case '/admin':
        return _AdminRoute(mode: widget.mode);
      case '/ops':
        if (widget.mode == AbzioAppMode.vendor) {
          return const VendorDashboard();
        }
        if (widget.mode == AbzioAppMode.rider) {
          return const RiderDashboard();
        }
        return const OpsShellScreen();
      case '/vendor-dashboard':
        return const VendorDashboard();
      case '/vendor-profile':
        return const VendorProfileScreen();
      case '/rider-dashboard':
        return const RiderDashboard();
      case '/profile-setup':
        return const RiderOnboardingScreen();
      case '/profile':
        if (widget.mode == AbzioAppMode.vendor) {
          return const VendorProfileScreen();
        }
        if (isPartnerMode(widget.mode)) {
          return OpsAccountScreen(mode: widget.mode);
        }
        return const ProfileScreen();
      case '/shop':
      case '/home':
        return const HomeScreen();
      default:
        if (user != null) {
          return const HomeScreen();
        }
        return LoginScreen(
          mode: widget.mode,
          adminEntry: kIsWeb && widget.mode == AbzioAppMode.unified,
        );
    }
  }

  Future<void> _navigateToResolvedRoute(AuthProvider auth) async {
    if (!mounted || _didRoute) {
      return;
    }

    final user = auth.user;
    _didRoute = true;

    if (user != null) {
      if (widget.mode == AbzioAppMode.vendor) {
        final route = routeForUserInMode(user, widget.mode);
        Navigator.of(context).pushAndRemoveUntil(
          _launchRoute(_launchDestinationForRoute(route, user)),
          (route) => false,
        );
        return;
      }
      final consentService = LegalConsentService();
      final needsConsent = await consentService.requiresConsent(
        user: user,
        mode: widget.mode,
      );
      if (!mounted) {
        return;
      }
      if (needsConsent) {
        final audience = LegalVersioning.audienceFor(
          user: user,
          mode: widget.mode,
        );
        Navigator.of(context).pushAndRemoveUntil(
          _launchRoute(LegalConsentScreen(audience: audience)),
          (route) => false,
        );
        return;
      }
      final route = routeForUserInMode(user, widget.mode);
      Navigator.of(context).pushAndRemoveUntil(
        _launchRoute(_launchDestinationForRoute(route, user)),
        (route) => false,
      );
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 900), () async {
          if (!mounted) {
            return;
          }
          await NotificationService().syncToken(user);
        }),
      );
      return;
    }

    if (isPartnerMode(widget.mode)) {
      Navigator.of(context).pushAndRemoveUntil(
        _launchRoute(_launchDestinationForRoute('/login', null)),
        (route) => false,
      );
      return;
    }

    if (widget.mode == AbzioAppMode.unified && _wantsAdminEntryFromUrl) {
      Navigator.of(context).pushAndRemoveUntil(
        _launchRoute(_launchDestinationForRoute('/admin-login', null)),
        (route) => false,
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      _launchRoute(_launchDestinationForRoute('/home', null)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isInitialized && !_didScheduleRoute) {
      _didScheduleRoute = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_navigateToResolvedRoute(auth));
      });
    }

    return const ColoredBox(color: Color(0xFFF9F7F2));
  }
}

class VendorAuthBannerScreen extends StatefulWidget {
  const VendorAuthBannerScreen({super.key});

  @override
  State<VendorAuthBannerScreen> createState() => _VendorAuthBannerScreenState();
}

class _VendorAuthBannerScreenState extends State<VendorAuthBannerScreen> {
  final PageController _controller = PageController();
  final TextEditingController _phoneController = TextEditingController();
  Timer? _timer;
  int _index = 0;

  static const List<
    ({
      String title,
      String subtitle,
      String imagePath,
      double textTopOffset,
      double zoomEnd,
    })
  >
  _slides = [
    (
      title: 'SELL ACROSS CHENNAI',
      subtitle: 'Reach more customers with ABIANZO',
      imagePath: 'assets/onboarding/vendor_visual_1.jpg',
      textTopOffset: 4,
      zoomEnd: 1.035,
    ),
    (
      title: 'FAST DELIVERY PARTNERS',
      subtitle: 'Deliver premium products across Chennai',
      imagePath: 'assets/onboarding/vendor_visual_0.jpg',
      textTopOffset: 0,
      zoomEnd: 1.035,
    ),
    (
      title: 'GROW YOUR BUSINESS',
      subtitle: 'Manage fashion orders with ease',
      imagePath: 'assets/onboarding/vendor_visual_2.jpg',
      textTopOffset: 2,
      zoomEnd: 1.0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      final next = (_index + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
      setState(() => _index = next);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _startOtp() async {
    final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit mobile number.')),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    try {
      await auth.requestOtp(phone);
      if (!mounted) return;
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            phoneNumber: phone,
            mode: AbzioAppMode.vendor,
            deferredAction: true,
            allowPartnerOnboarding: true,
          ),
        ),
      );
      if (!mounted || verified != true) {
        return;
      }
      final user =
          await auth.refreshProfileFromBackendIfPossible() ?? auth.user;
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        hasVendorOperationsAccess(user)
            ? '/vendor-dashboard'
            : '/vendor-profile',
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send OTP. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (_, index) {
                final slide = _slides[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    TweenAnimationBuilder<double>(
                      key: ValueKey(slide.imagePath),
                      tween: Tween(begin: 1.0, end: slide.zoomEnd),
                      duration: const Duration(seconds: 7),
                      curve: Curves.easeOutCubic,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Image.asset(slide.imagePath, fit: BoxFit.cover),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 360),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: Column(
                          key: ValueKey(slide.title),
                          children: [
                            SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: 80 + slide.textTopOffset,
                                ),
                                child: SizedBox(
                                  width: MediaQuery.sizeOf(context).width * 0.8,
                                  child: Column(
                                    children: [
                                      Text(
                                        slide.title,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFFD4AF37),
                                          fontSize: 36,
                                          fontFamily: 'Cormorant Garamond',
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                          height: 1.05,
                                          shadows: [
                                            Shadow(
                                              color: Color(0x40000000),
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        slide.subtitle,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFFF5E7C1),
                                          fontSize: 16,
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w500,
                                          height: 1.4,
                                          shadows: [
                                            Shadow(
                                              color: Color(0x33000000),
                                              blurRadius: 6,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
              decoration: const BoxDecoration(
                color: Color(0xEB111111),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(_slides.length, (dot) {
                        final active = dot == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFFD4AF37)
                                : const Color(0xFF555555),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Enter vendor workspace',
                      style: TextStyle(
                        color: Color(0xFFF5E7C1),
                        fontSize: 27,
                        fontFamily: 'Cormorant Garamond',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Use your registered mobile number to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFC8A96B),
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: InputDecoration(
                        prefixText: '+91  ',
                        prefixStyle: const TextStyle(
                          color: Color(0xFF111111),
                          fontWeight: FontWeight.w800,
                        ),
                        counterText: '',
                        hintText: 'Enter 10 digit mobile number',
                        hintStyle: const TextStyle(color: Color(0xFF9A958B)),
                        filled: true,
                        fillColor: const Color(0xFFFAF8F2),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5D7B3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFD4AF37),
                            width: 1.4,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _startOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: const Color(0xFFE0D8C9),
                          foregroundColor: const Color(0xFF111111),
                          minimumSize: const Size.fromHeight(54),
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD4AF37), Color(0xFFF5E7C1)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF111111),
                                    ),
                                  )
                                : const Text(
                                    'Get Started',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        text: "By logging in, I agree to Abianzo's ",
                        children: [
                          TextSpan(
                            text: 'terms and condition',
                            style: const TextStyle(
                              color: Color(0xFF8A6A16),
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const LegalPolicyHubScreen(
                                      audience: LegalAudience.vendor,
                                      title: 'Vendor Legal Center',
                                    ),
                                  ),
                                );
                              },
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF716B5E),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminRoute extends StatelessWidget {
  const _AdminRoute({required this.mode});

  final AbzioAppMode mode;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (!kIsWeb || mode != AbzioAppMode.unified) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Admin access is available only in the dedicated web panel.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/admin-login',
            (route) => false,
          );
        }
      });
      return const SizedBox.shrink();
    }

    if (user.role != 'admin' && user.role != 'super_admin') {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This area is restricted to platform administrators.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return const AdminWebPanel();
  }
}

class AuthGuard extends StatefulWidget {
  final Widget child;
  final AbzioAppMode mode;

  const AuthGuard({super.key, required this.child, required this.mode});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  Future<void> _forceLogout(AuthProvider auth, String message) async {
    await auth.logout();
    if (!mounted) return;

    final navContext = AbzioApp.navigatorKey.currentContext ?? context;
    if (navContext.mounted && !isBuildScopeRestrictionMessage(message)) {
      ScaffoldMessenger.of(navContext).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
    }

    AbzioApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      widget.mode == AbzioAppMode.unified ? '/admin-login' : '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user != null) {
      if (!user.isActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _forceLogout(auth, 'Your account has been deactivated.');
        });
      } else {
        final restriction = accessRestrictionMessage(user, widget.mode);
        if (restriction != null && widget.mode != AbzioAppMode.vendor) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _forceLogout(auth, restriction);
          });
        }
      }
    }

    return widget.child;
  }
}
