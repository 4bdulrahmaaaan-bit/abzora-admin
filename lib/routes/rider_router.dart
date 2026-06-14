import 'package:go_router/go_router.dart';

import '../features/onboarding/rider_onboarding_screens.dart';
import '../screens/rider/rider_operations_hub_screen.dart';
import 'rider_routes.dart';

final riderRouter = GoRouter(
  initialLocation: RiderRoutes.auth,
  routes: [
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
      builder: (context, state) => const RiderOperationsHubScreen(),
    ),
  ],
);
