import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../../utils/app_mode_routes.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/state_views.dart';
import 'ops_account_screen.dart';
import '../rider/rider_dashboard.dart';
import '../vendor/smart_vendor_onboarding_screen.dart';
import '../vendor/vendor_dashboard.dart';
import '../../features/onboarding/rider_onboarding_screens.dart';
import '../../features/onboarding/rider_training_module_screen.dart';
import '../onboarding/rider_onboarding_status_screen.dart';
import '../onboarding/application_rejected_screen.dart';

class OpsShellScreen extends StatefulWidget {
  const OpsShellScreen({super.key});

  @override
  State<OpsShellScreen> createState() => _OpsShellScreenState();
}

class _OpsShellScreenState extends State<OpsShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user == null) {
      return const Scaffold(
        body: AbzioLoadingView(
          title: 'Opening operations',
          subtitle: 'Preparing your workspace.',
        ),
      );
    }

    final isVendor = hasVendorOperationsAccess(user);
    final isRider = hasRiderOperationsAccess(user);
    if (!isVendor && !isRider) {
      return Scaffold(
        body: const AbzioEmptyCard(
          title: 'Operations access only',
          subtitle: 'This workspace is reserved for vendor and rider accounts.',
        ),
      );
    }

    if (isVendor) {
      if ((user.storeId ?? '').trim().isEmpty) {
        return const Scaffold(
          body: SmartVendorOnboardingScreen(),
        );
      }
      return Scaffold(
        backgroundColor: AbzioTheme.grey50,
        body: const VendorDashboard(),
      );
    }

    if (isRider) {
      if (!hasCompletedRiderOnboarding(user)) {
        return const Scaffold(body: RiderOnboardingFlowScreen());
      }
      final riderStatus = user.riderApprovalStatus.trim().toLowerCase();
      if (riderStatus == 'rejected') {
        return const Scaffold(body: ApplicationRejectedScreen());
      }
      if (riderStatus != 'approved') {
        return const Scaffold(body: RiderOnboardingStatusScreen());
      }
      final trainingStatus = user.training?['status'];
      if (trainingStatus == 'pending') {
        return const Scaffold(body: RiderTrainingModuleScreen());
      }
    }

    final pages = [
      const RiderDashboard(embedded: true),
      const OpsAccountScreen(),
    ];

    final labels = [isVendor ? 'DASHBOARD' : 'DELIVERIES', 'ACCOUNT'];

    return Scaffold(
      backgroundColor: AbzioTheme.grey50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            const BrandLogo(
              size: 34,
              radius: 9,
              padding: EdgeInsets.all(2),
              assetPath: 'assets/branding/abianzo_partner_icon.png',
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Abianzo PARTNER',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                    color: Colors.black,
                  ),
                ),
                Text(
                  isVendor ? 'Vendor workspace' : 'Rider workspace',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AbzioTheme.grey500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        destinations: [
          NavigationDestination(
            icon: Icon(
              isVendor
                  ? Icons.storefront_outlined
                  : Icons.delivery_dining_outlined,
            ),
            selectedIcon: Icon(
              isVendor
                  ? Icons.storefront_rounded
                  : Icons.delivery_dining_rounded,
              size: 26,
            ),
            label: labels[0],
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, size: 26),
            label: 'ACCOUNT',
          ),
        ],
      ),
    );
  }
}
