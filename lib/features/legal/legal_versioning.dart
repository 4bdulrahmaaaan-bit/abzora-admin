import '../../app_shell.dart';
import '../../models/models.dart';

import 'legal_document_registry.dart';

class LegalVersioning {
  static const String customerVersion = 'v1.0.0';
  static const String vendorVersion = 'v1.0.0';
  static const String riderVersion = 'v1.0.0';

  static LegalAudience audienceFor({required AppUser user, required AbzioAppMode mode}) {
    switch (mode) {
      case AbzioAppMode.vendor:
        return LegalAudience.vendor;
      case AbzioAppMode.rider:
        return LegalAudience.rider;
      case AbzioAppMode.operations:
        if ((user.role).toLowerCase() == 'rider') {
          return LegalAudience.rider;
        }
        return LegalAudience.vendor;
      case AbzioAppMode.customer:
      case AbzioAppMode.unified:
        if ((user.role).toLowerCase() == 'vendor') {
          return LegalAudience.vendor;
        }
        if ((user.role).toLowerCase() == 'rider') {
          return LegalAudience.rider;
        }
        return LegalAudience.customer;
    }
  }

  static String defaultVersionFor(LegalAudience audience) {
    switch (audience) {
      case LegalAudience.customer:
        return customerVersion;
      case LegalAudience.vendor:
        return vendorVersion;
      case LegalAudience.rider:
        return riderVersion;
      case LegalAudience.common:
        return customerVersion;
    }
  }
}
