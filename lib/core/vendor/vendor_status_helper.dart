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

    if (onboardingStatus == 'rejected') {
      return VendorAccountStatus.rejected;
    }

    if (onboardingStatus == 'suspended') {
      return VendorAccountStatus.suspended;
    }

    if (onboardingStatus == 'approved' || onboardingStatus == 'active') {
      return VendorAccountStatus.approved;
    }

    if (store != null && store.approvalStatus == 'approved') {
      return VendorAccountStatus.pending;
    }

    return VendorAccountStatus.pending;
  }
}
