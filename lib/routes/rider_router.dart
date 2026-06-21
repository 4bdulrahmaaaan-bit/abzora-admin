import 'package:go_router/go_router.dart';

import '../features/onboarding/rider_onboarding_screens.dart';
import '../features/onboarding/widgets/rider_success_screen.dart';
import '../screens/rider/rider_operations_hub_screen.dart';
import '../features/onboarding/screens/rider_application_center.dart';
import '../features/onboarding/screens/rider_suspended_screen.dart';
import '../features/onboarding/rider_training_module_screen.dart';
import '../screens/onboarding/application_rejected_screen.dart';
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
      path: RiderRoutes.profileOnboarding,
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
    GoRoute(
      path: RiderRoutes.status,
      builder: (context, state) => const RiderApplicationCenter(),
    ),
    GoRoute(
      path: RiderRoutes.training,
      builder: (context, state) => const RiderTrainingModuleScreen(),
    ),
    GoRoute(
      path: RiderRoutes.suspended,
      builder: (context, state) => const RiderSuspendedScreen(),
    ),
    GoRoute(
      path: RiderRoutes.rejected,
      builder: (context, state) => const ApplicationRejectedScreen(),
    ),
  ],
);
