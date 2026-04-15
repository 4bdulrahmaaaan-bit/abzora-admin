import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../app_shell.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../theme.dart';

class SoftAuthGate {
  const SoftAuthGate._();

  static Future<bool> ensureAuthenticated(
    BuildContext context, {
    required String intentLabel,
    String message =
        'Sign in to continue your trial, save your size, and track orders.',
  }) async {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      return true;
    }

    final continueToLogin = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              20 + MediaQuery.of(sheetContext).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDED8CC),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sign in to continue',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF68635A),
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EFE2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Action: $intentLabel',
                    style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF7A6235),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.phone_android_rounded),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AbzioTheme.accentColor,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    label: const Text(
                      'Continue with Phone OTP',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, null),
                      icon: const Icon(Icons.g_mobiledata_rounded),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                      label: const Text('Continue with Google'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: const Text('Not now'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted) {
      return false;
    }

    if (continueToLogin == null && kIsWeb) {
      try {
        final signedIn = await context.read<AuthProvider>().signInWithGoogle();
        return signedIn != null;
      } catch (error) {
        if (!context.mounted) {
          return false;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
        return false;
      }
    }

    if (continueToLogin != true) {
      return false;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(
          mode: AbzioAppMode.customer,
          deferredAction: true,
        ),
      ),
    );
    if (!context.mounted) {
      return false;
    }
    if (result == true || context.read<AuthProvider>().isAuthenticated) {
      return true;
    }
    return false;
  }
}
