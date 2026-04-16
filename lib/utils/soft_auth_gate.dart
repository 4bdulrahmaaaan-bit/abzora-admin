import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_shell.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../theme.dart';

enum AuthPromptStyle {
  softSheet,
  fullScreen,
}

class SoftAuthGate {
  const SoftAuthGate._();

  static Future<bool> ensureAuthenticated(
    BuildContext context, {
    required String intentLabel,
    String message =
        'Sign in to continue your trial, save your size, and track orders.',
    AuthPromptStyle promptStyle = AuthPromptStyle.softSheet,
    bool allowSkip = true,
  }) async {
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    if (auth.isAuthenticated) {
      return true;
    }

    bool? continueToLogin;
    if (promptStyle == AuthPromptStyle.fullScreen) {
      continueToLogin = await navigator.push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _CriticalAuthPromptPage(
            intentLabel: intentLabel,
            message: message,
            allowSkip: allowSkip,
          ),
        ),
      );
    } else {
      continueToLogin = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.38),
        isDismissible: true,
        enableDrag: true,
        isScrollControlled: true,
        builder: (sheetContext) {
          return SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                18 + MediaQuery.of(sheetContext).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF9),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 34,
                    offset: const Offset(0, -10),
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
                  const SizedBox(height: 18),
                  Text(
                    'Unlock your perfect fit',
                    style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF181410),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Login to continue',
                    style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B6257),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F3E7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '- Save your picks',
                          style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF2A241D),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '- Get perfect size',
                          style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF2A241D),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '- Track your orders',
                          style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF2A241D),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'For: $intentLabel',
                    style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF8B7B65),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AbzioTheme.accentColor,
                        foregroundColor: const Color(0xFF111111),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: Text(
                        'Continue with OTP',
                        style: Theme.of(sheetContext).textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF111111),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: allowSkip
                          ? () => Navigator.pop(sheetContext, false)
                          : null,
                      child: Text(
                        allowSkip ? 'Skip for now' : 'Continue',
                        style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6B6257),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (!context.mounted) {
      return false;
    }

    if (continueToLogin == null) {
      return false;
    }

    if (continueToLogin != true) {
      return false;
    }

    final result = await navigator.push<bool>(
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
    if (result == true || auth.isAuthenticated) {
      return true;
    }
    return false;
  }
}

class _CriticalAuthPromptPage extends StatelessWidget {
  const _CriticalAuthPromptPage({
    required this.intentLabel,
    required this.message,
    required this.allowSkip,
  });

  final String intentLabel;
  final String message;
  final bool allowSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: allowSkip
                      ? () => Navigator.of(context).pop(false)
                      : null,
                  child: Text(
                    allowSkip ? 'Skip for now' : 'Continue',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B6257),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Unlock your perfect fit',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF17120B),
                          ),
                    ),
                  ),
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFC89D34),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Login to continue',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF5E5548),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF7A7063),
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F3E7),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '- Save your picks',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF2A241D),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '- Get perfect size',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF2A241D),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '- Track your orders',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF2A241D),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAEF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'For: $intentLabel',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF8B7B65),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: AbzioTheme.accentColor,
                    foregroundColor: const Color(0xFF111111),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: const Text(
                    'Continue with OTP',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

