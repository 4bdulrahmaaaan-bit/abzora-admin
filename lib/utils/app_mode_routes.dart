import 'package:flutter/foundation.dart';
import '../app_shell.dart';
import '../models/models.dart';

bool isCustomerMode(AbzioAppMode mode) {
  return mode == AbzioAppMode.customer || mode == AbzioAppMode.unified;
}

bool isPartnerMode(AbzioAppMode mode) {
  return mode == AbzioAppMode.operations ||
      mode == AbzioAppMode.vendor ||
      mode == AbzioAppMode.rider;
}

bool isVendorMode(AbzioAppMode mode) {
  return mode == AbzioAppMode.vendor;
}

bool isRiderMode(AbzioAppMode mode) {
  return mode == AbzioAppMode.rider;
}

String appTitleForMode(AbzioAppMode mode) {
  switch (mode) {
    case AbzioAppMode.vendor:
      return 'Abianzo Vendor';
    case AbzioAppMode.rider:
      return 'Abianzo Rider';
    case AbzioAppMode.operations:
      return 'Abianzo Partner';
    case AbzioAppMode.customer:
      return 'Abianzo';
    case AbzioAppMode.unified:
      return 'ABIANZO ADMIN';
  }
}

String splashTitleForMode(AbzioAppMode mode) {
  switch (mode) {
    case AbzioAppMode.vendor:
      return 'ABIANZO VENDOR';
    case AbzioAppMode.rider:
      return 'ABIANZO RIDER';
    case AbzioAppMode.operations:
      return 'ABIANZO PARTNER';
    case AbzioAppMode.customer:
    case AbzioAppMode.unified:
      return 'ABIANZO';
  }
}

String splashSubtitleForMode(AbzioAppMode mode) {
  switch (mode) {
    case AbzioAppMode.vendor:
      return 'Store operations for vendors only';
    case AbzioAppMode.rider:
      return 'Delivery operations for riders only';
    case AbzioAppMode.operations:
      return 'Premium operations for vendors and riders';
    case AbzioAppMode.customer:
    case AbzioAppMode.unified:
      return 'Premium marketplace and custom clothing';
  }
}

String brandAssetForMode(AbzioAppMode mode) {
  switch (mode) {
    case AbzioAppMode.rider:
      return 'assets/branding/abianzo_rider_icon.png';
    case AbzioAppMode.vendor:
    case AbzioAppMode.operations:
      return 'assets/branding/abianzo_partner_icon.png';
    case AbzioAppMode.customer:
    case AbzioAppMode.unified:
      return 'assets/branding/abianzo_customer_icon.png';
  }
}

String normalizedUserRole(AppUser? user) {
  return user?.role.trim().toLowerCase() ?? '';
}

Map<String, bool> normalizedUserRoles(AppUser? user) {
  if (user == null) {
    return const {};
  }
  return user.roles.map(
    (key, value) => MapEntry(key.toLowerCase().trim(), value),
  );
}

bool hasVendorOperationsAccess(AppUser? user) {
  if (user == null) {
    return false;
  }
  return normalizedUserRole(user) == 'vendor';
}

bool hasRiderOperationsAccess(AppUser? user) {
  if (user == null) {
    return false;
  }
  return normalizedUserRole(user) == 'rider';
}

bool hasCompletedRiderOnboarding(AppUser user) {
  final hasVehicle = (user.riderVehicleType ?? '').trim().isNotEmpty;
  final hasLicense = (user.riderLicenseNumber ?? '').trim().isNotEmpty;
  final hasCity = (user.riderCity ?? '').trim().isNotEmpty;
  final status = user.riderOnboarding?['status'];
  final hasValidStatus = status != null && status != 'incomplete';
  
  return hasVehicle && hasLicense && hasCity && hasValidStatus;
}

bool canAccessOperationsMode(AppUser? user) {
  if (user == null) {
    return false;
  }
  return hasVendorOperationsAccess(user) || hasRiderOperationsAccess(user);
}

bool canAccessMode(AppUser? user, AbzioAppMode mode) {
  switch (mode) {
    case AbzioAppMode.vendor:
      return hasVendorOperationsAccess(user);
    case AbzioAppMode.rider:
      return hasRiderOperationsAccess(user);
    case AbzioAppMode.operations:
      return canAccessOperationsMode(user);
    case AbzioAppMode.customer:
    case AbzioAppMode.unified:
      return true;
  }
}

String routeForRiderUser(AppUser user) {
  final approval = user.riderApprovalStatus.trim().toLowerCase();
  final training = user.training?['status']?.toString().trim().toLowerCase();
  final onboardingStatus = user.riderOnboarding?['status']?.toString().trim().toLowerCase();
  final isActive = user.isActive;
  final hasCompletedOnboarding = hasCompletedRiderOnboarding(user);

  String resolvedRoute = '';

  // 1. Suspension Gate
  if (approval == 'suspended' || onboardingStatus == 'suspended' || !isActive) {
    resolvedRoute = '/rider-suspended';
  }
  // 2. Onboarding Gate
  else if (!hasCompletedOnboarding) {
    resolvedRoute = '/rider-onboarding';
  }
  // 3 & 4. Approval Gates (handles pending, rejected, empty, unknown)
  else if (approval != 'approved') {
    resolvedRoute = '/rider-status';
  }
  // 5. Training Gate (handles null, empty, unknown)
  else if (training != 'completed') {
    resolvedRoute = '/rider-training';
  }
  // 6. Activation Gate
  else {
    resolvedRoute = '/rider-dashboard';
  }

  debugPrint(
    '\n[RIDER_ROUTE_GUARD]\n'
    'userId=${user.id}\n'
    'approval=${approval.isEmpty ? 'null' : approval}\n'
    'training=${(training == null || training.isEmpty) ? 'null' : training}\n'
    'onboarding=$hasCompletedOnboarding\n'
    'active=$isActive\n'
    'resolvedRoute=$resolvedRoute\n'
  );

  return resolvedRoute;
}

String routeForUserInMode(AppUser? user, AbzioAppMode mode) {
  if (user == null) {
    return '/login';
  }

  switch (mode) {
    case AbzioAppMode.customer:
      if (user.activeRole.toLowerCase() != 'customer') {
         return '/login';
      }
      return '/shop';
    case AbzioAppMode.vendor:
      if (hasVendorOperationsAccess(user)) {
        if ((user.storeId ?? '').trim().isEmpty) {
          final vendorOnboarding = user.vendorOnboarding;
          if (vendorOnboarding != null) {
            final status = vendorOnboarding['status'];
            if (status == 'pending' || status == 'review') {
              return '/vendor-status';
            } else if (status == 'rejected') {
              return '/vendor-rejected';
            }
          }
          return '/vendor-onboarding';
        }
        return '/vendor-dashboard';
      }
      final vendorOnboarding = user.vendorOnboarding;
      if (vendorOnboarding != null) {
        final status = vendorOnboarding['status'];
        if (status == 'active') {
          return '/vendor-dashboard';
        } else if (status == 'pending' || status == 'review') {
          return '/vendor-status';
        } else if (status == 'rejected') {
          return '/vendor-rejected';
        } else if (vendorOnboarding['resubmissionRequired'] == true) {
          return '/vendor-onboarding';
        }
      }
      return '/vendor-onboarding';
    case AbzioAppMode.rider:
      return routeForRiderUser(user);
    case AbzioAppMode.operations:
      if (canAccessOperationsMode(user)) {
        if (hasVendorOperationsAccess(user) && (user.storeId ?? '').trim().isEmpty) {
          final vendorOnboarding = user.vendorOnboarding;
          if (vendorOnboarding != null) {
            final status = vendorOnboarding['status'];
            if (status == 'pending' || status == 'review') return '/vendor-status';
            if (status == 'rejected') return '/vendor-rejected';
          }
          return '/vendor-onboarding';
        }
        if (hasRiderOperationsAccess(user)) {
          final riderRoute = routeForRiderUser(user);
          if (riderRoute != '/rider-dashboard') return riderRoute;
        }
        return '/ops';
      }
      return '/login';
    case AbzioAppMode.unified:
      if (normalizedUserRole(user) == 'admin' ||
          normalizedUserRole(user) == 'super_admin') {
        return '/admin';
      }
      if (canAccessOperationsMode(user)) {
        if (hasVendorOperationsAccess(user) && (user.storeId ?? '').trim().isEmpty) {
          final vendorOnboarding = user.vendorOnboarding;
          if (vendorOnboarding != null) {
            final status = vendorOnboarding['status'];
            if (status == 'pending' || status == 'review') return '/vendor-status';
            if (status == 'rejected') return '/vendor-rejected';
          }
          return '/vendor-onboarding';
        }
        if (hasRiderOperationsAccess(user)) {
          final riderRoute = routeForRiderUser(user);
          if (riderRoute != '/rider-dashboard') return riderRoute;
        }
        return '/ops';
      }
      if (kIsWeb) return '/admin';
      return normalizedUserRole(user) == 'user' ||
              normalizedUserRole(user) == 'customer'
          ? '/shop'
          : '/login';
  }
}

String? accessRestrictionMessage(AppUser? user, AbzioAppMode mode) {
  if (user == null) {
    return null;
  }
  final role = normalizedUserRole(user);
  if (mode == AbzioAppMode.customer && user.activeRole.toLowerCase() != 'customer') {
    return 'This build is for customer shopping only. Please use the partner or rider app for operations accounts.';
  }
  if (mode == AbzioAppMode.vendor && !hasVendorOperationsAccess(user)) {
    // Vendor app should allow authenticated users to proceed to vendor setup
    // flows (for example /vendor-profile) instead of forcing logout loops.
    return null;
  }
  if (mode == AbzioAppMode.rider && !hasRiderOperationsAccess(user)) {
    final riderStatus = user.riderApprovalStatus.trim().toLowerCase();
    if (riderStatus != 'approved') {
      // Allow users to continue into rider setup/onboarding
      // flows instead of forcing a logout loop.
      return null;
    }
    return 'This build is for rider operations only. Please use the vendor or customer app for other accounts.';
  }
  if (mode == AbzioAppMode.operations && !canAccessOperationsMode(user)) {
    if (!hasRiderOperationsAccess(user)) {
      final riderStatus = user.riderApprovalStatus.trim().toLowerCase();
      if (riderStatus != 'approved') {
        return 'Your rider profile is not approved yet. Please complete onboarding or wait for approval.';
      }
      return 'This account cannot access partner operations in this build.';
    }
    if (normalizedUserRole(user) == 'vendor') {
      return null;
    }
    return 'This build is for vendor and rider operations only. Please use the customer app for shopping accounts.';
  }
  if (mode == AbzioAppMode.unified &&
      role != 'user' &&
      role != 'customer' &&
      !hasVendorOperationsAccess(user) &&
      !hasRiderOperationsAccess(user) &&
      role != 'admin' &&
      role != 'super_admin') {
    return 'Admin access is available only in the dedicated web panel.';
  }
  return null;
}

bool isBuildScopeRestrictionMessage(String message) {
  return message.startsWith('This build is for ');
}
