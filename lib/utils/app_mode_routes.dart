import '../app_shell.dart';
import '../models/models.dart';

String routeForUserInMode(AppUser? user, AbzioAppMode mode) {
  if (user == null) {
    return '/login';
  }

  switch (mode) {
    case AbzioAppMode.customer:
      return user.role == 'user' || user.role == 'customer' ? '/shop' : '/login';
    case AbzioAppMode.operations:
      if (user.role == 'vendor' || user.role == 'rider') {
        return '/ops';
      }
      return '/login';
    case AbzioAppMode.unified:
      if (user.role == 'admin' || user.role == 'super_admin') {
        return '/admin';
      }
      if (user.role == 'vendor' || user.role == 'rider') {
        return '/ops';
      }
      return user.role == 'user' || user.role == 'customer' ? '/shop' : '/login';
  }
}

String? accessRestrictionMessage(AppUser? user, AbzioAppMode mode) {
  if (user == null) {
    return null;
  }
  if (mode == AbzioAppMode.customer && user.role != 'user' && user.role != 'customer') {
    return 'This build is for customer shopping accounts only. Please use the operations app for vendor or rider access.';
  }
  if (mode == AbzioAppMode.operations &&
      user.role != 'vendor' &&
      user.role != 'rider') {
    return 'This build is for vendor and rider operations only. Please use the customer app for shopping accounts.';
  }
  if (mode == AbzioAppMode.unified &&
      user.role != 'user' &&
      user.role != 'vendor' &&
      user.role != 'rider' &&
      user.role != 'admin' &&
      user.role != 'super_admin') {
    return 'Admin access is available only in the dedicated web panel.';
  }
  return null;
}
