import 'package:go_router/go_router.dart';

import '../features/dashboard/rider_dashboard_screen.dart';
import '../features/onboarding/rider_onboarding_screens.dart';
import 'rider_routes.dart';

final riderRouter = GoRouter(
  initialLocation: RiderRoutes.splash,
  routes: [
    GoRoute(
      path: RiderRoutes.splash,
      builder: (context, state) => const RiderSplashScreen(),
    ),
    GoRoute(
      path: RiderRoutes.auth,
      builder: (context, state) => const RiderAuthBannerScreen(),
    ),
    GoRoute(
      path: RiderRoutes.profileSetup,
      builder: (context, state) => const RiderOnboardingFlowScreen(),
    ),
    GoRoute(
      path: RiderRoutes.success,
      builder: (context, state) => const RiderSuccessScreen(),
    ),
    GoRoute(
      path: RiderRoutes.dashboard,
      builder: (context, state) => const RiderDashboardScreen(),
    ),
  ],
);
