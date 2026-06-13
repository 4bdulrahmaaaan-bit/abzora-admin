import '../../models/models.dart';

enum VendorAccountStatus { pending, approved, rejected, suspended }

class VendorStatusHelper {
  static VendorAccountStatus getVendorStatus({
    required AppUser user,
    Store? store,
  }) {
    if (store != null && store.approvalStatus == 'approved') {
      return VendorAccountStatus.approved;
    }

    if (user.roles['vendor'] == true || user.role == 'vendor') {
      return VendorAccountStatus.approved;
    }

    return VendorAccountStatus.pending;
  }
}
