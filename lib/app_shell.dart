import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import 'providers/wishlist_provider.dart';
import 'screens/login_screen.dart';
import 'screens/ops/ops_account_screen.dart';
import 'screens/ops/ops_shell_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/rider/rider_dashboard.dart';
import 'screens/splash_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_analytics_screen.dart';
import 'screens/user/cart_screen.dart';
import 'screens/user/chat_list_screen.dart';
import 'screens/user/checkout_screen.dart';
import 'screens/user/address_screen.dart';
import 'screens/user/add_card_screen.dart';
import 'screens/user/home_screen.dart';
import 'screens/user/notifications_screen.dart';
import 'screens/user/order_tracking_screen.dart';
import 'screens/user/payment_methods_screen.dart';
import 'screens/user/product_detail_screen.dart';
import 'screens/user/profile_screen.dart';
import 'screens/user/referral_screen.dart';
import 'screens/user/role_selection_screen.dart';
import 'screens/user/signup_screen.dart';
import 'screens/user/video_feed_screen.dart';
import 'screens/admin/admin_kyc_screen.dart';
import 'screens/admin/admin_orders_screen.dart';
import 'screens/admin/admin_payouts_screen.dart';
import 'screens/admin/admin_riders_screen.dart';
import 'screens/admin/admin_vendors_screen.dart';
import 'screens/vendor/vendor_dashboard.dart';
import 'services/app_bootstrap_service.dart';
import 'services/notification_service.dart';
import 'theme.dart';
import 'widgets/offline_widgets.dart';
import 'widgets/safe_widget.dart';

enum AbzioAppMode {
  unified,
  customer,
  operations,
}

Future<void> bootstrapAndRun(AbzioAppMode mode) async {
  await bootstrapAndRunWithInitialRoute(mode);
}

Future<void> bootstrapAndRunWithInitialRoute(
  AbzioAppMode mode, {
  String initialRoute = '/',
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  _installGlobalErrorHandling();

  await runZonedGuarded(() async {
    await AppBootstrapService().initialize();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BannerProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
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
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: AbzioApp(mode: mode, initialRoute: initialRoute),
      ),
    );
  }, (error, stackTrace) {
    debugPrint('ABZORA zoned error: $error');
    debugPrintStack(stackTrace: stackTrace);
  });
}

void _installGlobalErrorHandling() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('ABZORA Flutter error: ${details.exception}');
    if (details.stack != null) {
      debugPrintStack(stackTrace: details.stack);
    }
  };

  ErrorWidget.builder = (details) {
    return AbzioGlobalErrorView(
      message: 'This part of the app had a problem, but you can keep using ABZORA.',
      onRetry: () {
        final navigator = AbzioApp.navigatorKey.currentState;
        navigator?.pushNamedAndRemoveUntil('/', (route) => false);
      },
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    debugPrint('ABZORA platform error: $error');
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

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: mode == AbzioAppMode.operations ? 'Abzora Partner' : 'Abzora',
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
              fallbackBuilder: (context, error, stackTrace) => AbzioGlobalErrorView(
                message: 'We hit a UI issue, but you can safely return to the app.',
                onRetry: () {
                  Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/', (route) => false);
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
        '/admin-login': (context) => const LoginScreen(mode: AbzioAppMode.unified, adminEntry: true),
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
        '/ops': (context) => const OpsShellScreen(),
        '/profile': (context) => mode == AbzioAppMode.operations
            ? const OpsAccountScreen()
            : const ProfileScreen(),
        '/addresses': (context) => const AddressScreen(),
        '/add-card': (context) => const AddCardScreen(),
        '/payments': (context) => const PaymentMethodsScreen(),
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
        '/rider-dashboard': (context) => const RiderDashboard(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/product-detail' && settings.arguments is Product) {
          return MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: settings.arguments as Product),
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

  void _navigateToResolvedRoute(AuthProvider auth) {
    if (!mounted || _didRoute) {
      return;
    }

    final user = auth.user;
    _didRoute = true;

    if (user != null) {
      NotificationService().syncToken(user);
      Navigator.of(context).pushReplacementNamed(
        routeForUserInMode(user, widget.mode),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(
          mode: widget.mode,
          adminEntry: kIsWeb && widget.mode == AbzioAppMode.unified,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: slideAnimation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isInitialized) {
      return SplashScreen(mode: widget.mode);
    }

    if (auth.user == null) {
      return LoginScreen(
        mode: widget.mode,
        adminEntry: kIsWeb && widget.mode == AbzioAppMode.unified,
      );
    }

    if (!_didRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToResolvedRoute(auth);
      });
    }

    return SplashScreen(mode: widget.mode);
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
          Navigator.pushReplacementNamed(context, '/admin-login');
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

    return const AdminDashboard();
  }
}

class AuthGuard extends StatefulWidget {
  final Widget child;
  final AbzioAppMode mode;

  const AuthGuard({
    super.key,
    required this.child,
    required this.mode,
  });

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  Future<void> _forceLogout(AuthProvider auth, String message) async {
    await auth.logout();
    if (!mounted) return;

    final navContext = AbzioApp.navigatorKey.currentContext ?? context;
    if (navContext.mounted) {
      ScaffoldMessenger.of(navContext).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
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
        if (restriction != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _forceLogout(auth, restriction);
          });
        }
      }
    }

    return widget.child;
  }
}
