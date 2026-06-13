import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../app_shell.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../utils/app_error_text.dart';
import '../utils/app_mode_routes.dart';
import '../features/legal/legal_consent_screen.dart';
import '../features/legal/legal_document_registry.dart';
import '../features/legal/legal_policy_hub_screen.dart';
import '../widgets/brand_logo.dart';
import '../widgets/tap_scale.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.mode = AbzioAppMode.unified,
    this.adminEntry = false,
    this.deferredAction = false,
  });

  final AbzioAppMode mode;
  final bool adminEntry;
  final bool deferredAction;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  String? _phoneError;
  Timer? _adminCooldownTimer;
  int _adminCooldownSeconds = 0;

  bool get _useGoogleAdminLogin => kIsWeb && widget.adminEntry;
  bool get _isPrimaryFashionLogin =>
      !widget.adminEntry && isCustomerMode(widget.mode);
  bool get _isPartnerLogin => !widget.adminEntry && isPartnerMode(widget.mode);

  String get _headline {
    switch (widget.mode) {
      case AbzioAppMode.vendor:
        return 'Vendor Sign In';
      case AbzioAppMode.rider:
        return 'Rider Sign In';
      case AbzioAppMode.operations:
        return 'Partner Sign In';
      case AbzioAppMode.customer:
      case AbzioAppMode.unified:
        return 'Sign in to Abianzo';
    }
  }

  String get _subheading {
    switch (widget.mode) {
      case AbzioAppMode.vendor:
        return 'Manage your store, orders, and payouts';
      case AbzioAppMode.rider:
        return 'Accept deliveries, routes, and payouts';
      case AbzioAppMode.operations:
        return 'Access your vendor or rider workspace';
      case AbzioAppMode.customer:
      case AbzioAppMode.unified:
        return 'Access your AI Fit profile, AR try-ons, wishlist and orders.';
    }
  }

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(_handleFocusChange);
    _phoneController.addListener(_handlePhoneChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _phoneFocusNode.requestFocus();
      }
    });
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handlePhoneChange() {
    final digitsOnly = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly != _phoneController.text) {
      _phoneController.value = TextEditingValue(
        text: digitsOnly,
        selection: TextSelection.collapsed(offset: digitsOnly.length),
      );
      return;
    }

    final nextError = _phoneErrorFor(digitsOnly, showEmpty: false);
    if (mounted && nextError != _phoneError) {
      setState(() => _phoneError = nextError);
    } else if (mounted) {
      setState(() {});
    }
  }

  String _normalizedPhone() =>
      _phoneController.text.replaceAll(RegExp(r'\s+'), '').trim();

  bool get _isPhoneValid => _normalizedPhone().length == 10;
  bool get _canContinueWithOtp => _isPhoneValid;
  bool get _canContinueWithAdminGoogle => _adminCooldownSeconds <= 0;

  String? _phoneErrorFor(String phone, {required bool showEmpty}) {
    if (phone.isEmpty) {
      return showEmpty ? 'Enter a valid 10-digit phone number' : null;
    }
    if (phone.length < 10) {
      return 'Enter a valid 10-digit phone number';
    }
    return null;
  }

  @override
  void dispose() {
    _adminCooldownTimer?.cancel();
    _phoneFocusNode.removeListener(_handleFocusChange);
    _phoneController.removeListener(_handlePhoneChange);
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final phone = _normalizedPhone();
    final validationError = _phoneErrorFor(phone, showEmpty: true);
    if (validationError != null) {
      setState(() => _phoneError = validationError);
      _phoneFocusNode.requestFocus();
      return;
    }

    final authProvider = context.read<AuthProvider>();
    try {
      await authProvider.requestOtp(phone);
      if (!mounted) {
        return;
      }
      final verified = await Navigator.push<bool>(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              OtpVerificationScreen(
                phoneNumber: phone,
                mode: widget.mode,
                adminEntry: widget.adminEntry,
                deferredAction: widget.deferredAction,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final offset =
                Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offset, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 260),
        ),
      );
      if (widget.deferredAction && verified == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(AppErrorText.from(error)),
        ),
      );
    }
  }

  Future<void> _signInWithGoogleAdmin() async {
    if (_adminCooldownSeconds > 0) {
      return;
    }
    final authProvider = context.read<AuthProvider>();
    try {
      final user = await authProvider.signInWithGoogleAdmin();
      if (!mounted || user == null) {
        return;
      }
      Navigator.pushReplacementNamed(context, '/admin');
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = AppErrorText.from(error);
      final normalized = message.toLowerCase();
      if (normalized.contains('too many') ||
          normalized.contains('too-many-requests') ||
          normalized.contains('authentication requests')) {
        _startAdminCooldown();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _adminCooldownSeconds > 0
                ? 'Too many login attempts. Try again in ${_adminCooldownSeconds}s.'
                : message,
          ),
        ),
      );
    }
  }

  void _startAdminCooldown([int seconds = 45]) {
    _adminCooldownTimer?.cancel();
    setState(() => _adminCooldownSeconds = seconds);
    _adminCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_adminCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _adminCooldownSeconds = 0);
        return;
      }
      setState(() => _adminCooldownSeconds -= 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isFocused = _phoneFocusNode.hasFocus;
    final hasError = _phoneError != null;
    final logoAsset = widget.mode == AbzioAppMode.rider
        ? 'assets/branding/abianzo_rider_icon.png'
        : brandAssetForMode(widget.mode);

    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5F2),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              40,
              24,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Hero(
                            tag: 'auth-brand-logo',
                            child: BrandLogo.hero(
                              size: 72,
                              radius: 20,
                              backgroundColor: Colors.white,
                              assetPath: logoAsset,
                              padding: const EdgeInsets.all(4),
                              shadows: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.10),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _headline,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              color: const Color(0xFF111111),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _subheading,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF6B6B6B),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_useGoogleAdminLogin) ...[
                      TapScale(
                        onTap: (auth.isLoading || !_canContinueWithAdminGoogle)
                            ? null
                            : _signInWithGoogleAdmin,
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                auth.isLoading || !_canContinueWithAdminGoogle
                                ? null
                                : _signInWithGoogleAdmin,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(58),
                              elevation: 1,
                              shadowColor: AbzioTheme.accentColor.withValues(
                                alpha: 0.22,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: auth.isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _adminCooldownSeconds > 0
                                        ? 'Try again in ${_adminCooldownSeconds}s'
                                        : 'Continue With Google',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Use the Gmail address that is allowlisted for admin access. Non-admin accounts will be signed out automatically.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: context.abzioSecondaryText,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else ...[
                      if (_isPrimaryFashionLogin) ...[
                        Text(
                          'Why Sign In?',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: const Color(0xFF8A8A8A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _BenefitRow(
                          icon: Icons.straighten_outlined,
                          label: 'Save AI Fit preferences',
                        ),
                        const SizedBox(height: 10),
                        const _BenefitRow(
                          icon: Icons.favorite_border_rounded,
                          label: 'Access your wishlist',
                        ),
                        const SizedBox(height: 10),
                        const _BenefitRow(
                          icon: Icons.local_shipping_outlined,
                          label: 'Track orders easily',
                        ),
                        const SizedBox(height: 10),
                        const _BenefitRow(
                          icon: Icons.refresh_rounded,
                          label: 'Resume AR Try-On sessions',
                        ),
                        const SizedBox(height: 26),
                      ],
                      Text(
                        _isPartnerLogin ? 'Partner Number' : 'Mobile Number',
                        textAlign: TextAlign.left,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                          color: const Color(0xFF8A8A8A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasError
                                ? const Color(0xFFD64C4C)
                                : isFocused
                                ? const Color(0xFFC6A769)
                                : const Color(0xFFE5E5E5),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: hasError
                                  ? const Color(
                                      0xFFD64C4C,
                                    ).withValues(alpha: 0.10)
                                  : const Color(0xFFC6A769).withValues(
                                      alpha: isFocused ? 0.15 : 0.04,
                                    ),
                              blurRadius: isFocused ? 16 : 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 44,
                              constraints: const BoxConstraints(minWidth: 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1EFEA),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '+91',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF111111),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                focusNode: _phoneFocusNode,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.done,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                autofillHints: const [
                                  AutofillHints.telephoneNumber,
                                ],
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF111111),
                                ),
                                decoration: const InputDecoration(
                                  hintText: '9876543210',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onSubmitted: (_) {
                                  if (!auth.isLoading && _canContinueWithOtp) {
                                    _requestOtp();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      TapScale(
                        scale: 0.97,
                        onTap: (auth.isLoading || !_canContinueWithOtp)
                            ? null
                            : _requestOtp,
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (auth.isLoading || !_canContinueWithOtp)
                                ? null
                                : _requestOtp,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              elevation: 1,
                              backgroundColor: const Color(0xFFC6A769),
                              foregroundColor: const Color(0xFF000000),
                              disabledBackgroundColor: const Color(0xFFD6D1C4),
                              disabledForegroundColor: const Color(0xFF888888),
                              shadowColor: const Color(
                                0xFFC6A769,
                              ).withValues(alpha: 0.32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: auth.isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Continue',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text.rich(
                      TextSpan(
                        text: 'By continuing, you agree to our ',
                        children: [
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: const TextStyle(
                              color: Color(0xFF8A6A16),
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const LegalConsentScreen(
                                      audience: LegalAudience.customer,
                                    ),
                                  ),
                                );
                              },
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              color: Color(0xFF8A6A16),
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const LegalPolicyHubScreen(
                                      audience: LegalAudience.customer,
                                      title: 'Privacy Policy',
                                    ),
                                  ),
                                );
                              },
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF716B5E),
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFF4EEE2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 15, color: const Color(0xFF8A6A16)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1C1C1C),
            ),
          ),
        ),
      ],
    );
  }
}
