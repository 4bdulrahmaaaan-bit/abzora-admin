import '../../models/models.dart';

enum VendorAccountStatus { pending, approved, rejected, suspended }

class VendorStatusHelper {
  static String _vendorOnboardingStatus(AppUser user) {
    final onboarding = user.vendorOnboarding;
    return onboarding?['status']?.toString().trim().toLowerCase() ?? '';
  }

  static VendorAccountStatus getVendorStatus({
    required AppUser user,
    Store? store,
  }) {
    final onboardingStatus = _vendorOnboardingStatus(user);
    final storeStatus = store?.approvalStatus.toString().trim().toLowerCase() ?? '';
    final storeApproved = store != null &&
        (store.isApproved || storeStatus == 'approved' || storeStatus == 'active');

    if (onboardingStatus == 'rejected' || storeStatus == 'rejected') {
      return VendorAccountStatus.rejected;
    }

    if (onboardingStatus == 'suspended' || storeStatus == 'suspended' || (store != null && !store.isActive)) {
      return VendorAccountStatus.suspended;
    }

    if (onboardingStatus == 'approved' || onboardingStatus == 'active' || storeApproved) {
      return VendorAccountStatus.approved;
    }

    return VendorAccountStatus.pending;
  }
}

