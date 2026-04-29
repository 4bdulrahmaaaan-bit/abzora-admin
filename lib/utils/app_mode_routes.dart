import '../app_shell.dart';
import '../models/models.dart';

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
  if (normalizedUserRole(user) == 'vendor') {
    return true;
  }
  final roles = normalizedUserRoles(user);
  return roles['vendor'] == true || (user.storeId ?? '').trim().isNotEmpty;
}

bool hasRiderOperationsAccess(AppUser? user) {
  if (user == null) {
    return false;
  }
  if (normalizedUserRole(user) == 'rider') {
    return true;
  }
  final roles = normalizedUserRoles(user);
  if (roles['rider'] == true) {
    return true;
  }
  final riderStatus = user.riderApprovalStatus.trim().toLowerCase();
  return riderStatus == 'approved';
}

bool canAccessOperationsMode(AppUser? user) {
  if (user == null) {
    return false;
  }
  return hasVendorOperationsAccess(user) || hasRiderOperationsAccess(user);
}

String routeForUserInMode(AppUser? user, AbzioAppMode mode) {
  if (user == null) {
    return '/login';
  }

  switch (mode) {
    case AbzioAppMode.customer:
      // Customer app supports guest-style browsing for all roles.
      // High-intent actions are gated by soft auth prompts at action time.
      return '/shop';
    case AbzioAppMode.operations:
      if (canAccessOperationsMode(user)) {
        return '/ops';
      }
      return '/login';
    case AbzioAppMode.unified:
      if (normalizedUserRole(user) == 'admin' ||
          normalizedUserRole(user) == 'super_admin') {
        return '/admin';
      }
      if (canAccessOperationsMode(user)) {
        return '/ops';
      }
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
  if (mode == AbzioAppMode.customer && role != 'user' && role != 'customer') {
    return null;
  }
  if (mode == AbzioAppMode.operations && !canAccessOperationsMode(user)) {
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
