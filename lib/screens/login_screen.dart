import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../app_shell.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
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

  bool get _useGoogleAdminLogin => kIsWeb && widget.adminEntry;
  bool get _isPrimaryFashionLogin =>
      !widget.adminEntry && widget.mode != AbzioAppMode.operations;

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
            final offset = Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
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
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _signInWithGoogleAdmin() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  void _showPolicySheet({
    required String title,
    required String body,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.55,
                    color: context.abzioSecondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isFocused = _phoneFocusNode.hasFocus;
    final hasError = _phoneError != null;

    return AbzioThemeScope.light(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              20,
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
                              size: 92,
                              radius: 24,
                              backgroundColor:
                                  Theme.of(context).scaffoldBackgroundColor,
                              padding: const EdgeInsets.all(6),
                              shadows: [
                                BoxShadow(
                                  color: AbzioTheme.accentColor.withValues(
                                    alpha: 0.14,
                                  ),
                                  blurRadius: 22,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            widget.adminEntry
                                ? 'ADMIN LOGIN'
                                : widget.mode == AbzioAppMode.operations
                                    ? 'OPS LOGIN'
                                    : 'UNLOCK YOUR ABZORA FIT',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _useGoogleAdminLogin
                                ? 'Continue with your Google account'
                                : _isPrimaryFashionLogin
                                    ? 'Continue where your style journey left off.'
                                    : 'Enter your phone number',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: context.abzioSecondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _useGoogleAdminLogin
                                ? 'Only approved admin Gmail accounts can access the web control panel.'
                                : widget.adminEntry
                                ? 'Secure login. Continue with your phone number for admin access.'
                                : _isPrimaryFashionLogin
                                    ? 'Save your trial picks, keep your fit profile, and track every order in one place.'
                                : 'Secure login. Continue with your phone number.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: context.abzioSecondaryText,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 42),
                    if (_useGoogleAdminLogin) ...[
                      TapScale(
                        onTap: auth.isLoading ? null : _signInWithGoogleAdmin,
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _signInWithGoogleAdmin,
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
                                      color:
                                          Theme.of(context).colorScheme.onPrimary,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Continue With Google',
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F6F1),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color:
                                  AbzioTheme.accentColor.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: const [
                              _BenefitChip(
                                icon: Icons.auto_awesome_outlined,
                                label: 'Resume Trial',
                              ),
                              _BenefitChip(
                                icon: Icons.straighten_outlined,
                                label: 'Save Fit Profile',
                              ),
                              _BenefitChip(
                                icon: Icons.local_shipping_outlined,
                                label: 'Track Orders',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],
                      Text(
                        _isPrimaryFashionLogin ? 'MOBILE NUMBER' : 'PHONE NUMBER',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.7,
                          color: context.abzioSecondaryText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBFBFB),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: hasError
                                ? const Color(0xFFD64C4C)
                                : isFocused
                                    ? AbzioTheme.accentColor.withValues(alpha: 0.78)
                                    : context.abzioBorder.withValues(alpha: 0.85),
                            width: isFocused || hasError ? 1.25 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: hasError
                                  ? const Color(0xFFD64C4C).withValues(
                                      alpha: 0.10,
                                    )
                                  : AbzioTheme.accentColor.withValues(
                                      alpha: isFocused ? 0.10 : 0.03,
                                    ),
                              blurRadius: isFocused ? 20 : 12,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.only(left: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isFocused
                                    ? AbzioTheme.accentColor.withValues(
                                        alpha: 0.10,
                                      )
                                    : Theme.of(context)
                                        .inputDecorationTheme
                                        .fillColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '+91',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
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
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '98765 43210',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onSubmitted: (_) {
                                  if (!auth.isLoading && _isPhoneValid) {
                                    _requestOtp();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          _phoneError ??
                              (widget.adminEntry
                                  ? 'Only approved admin accounts can continue after OTP verification.'
                                  : widget.mode == AbzioAppMode.operations
                                      ? 'Your access is resolved after OTP verification.'
                                      : 'A quick OTP verifies your number and unlocks your saved experience.'),
                          key: ValueKey<String>(_phoneError ?? 'help'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: hasError
                                ? const Color(0xFFD64C4C)
                                : context.abzioSecondaryText,
                            height: 1.5,
                            fontWeight:
                                hasError ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      TapScale(
                        onTap:
                            (auth.isLoading || !_isPhoneValid) ? null : _requestOtp,
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                (auth.isLoading || !_isPhoneValid) ? null : _requestOtp,
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
                                      color:
                                          Theme.of(context).colorScheme.onPrimary,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Continue \u2192',
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
                        kIsWeb
                            ? 'A quick security check may appear once before the OTP is sent.'
                            : 'Help is available anytime if your OTP is delayed.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: context.abzioSecondaryText,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (widget.mode != AbzioAppMode.operations &&
                        !widget.adminEntry)
                      Center(
                        child: TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/signup'),
                          child: const Text(
                            'Need help with new account access?',
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'By continuing, you agree to our policies.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: context.abzioSecondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        _PolicyLinkButton(
                          label: 'Privacy Policy',
                          onTap: () => _showPolicySheet(
                            title: 'Privacy Policy',
                            body: '''Privacy Policy - ABZORA

Effective Date: [Add Date]

ABZORA ("we", "our", "us") respects your privacy. This policy explains how we collect, use, and protect your information.

1. Information We Collect
We may collect:
- Phone number (for OTP login)
- Name and delivery address
- Body measurements (for fit recommendations)
- Order and browsing activity
- Device and app usage data
- Location (for delivery and nearby stores)

2. How We Use Your Data
We use your data to:
- Provide login and account access
- Deliver products and manage orders
- Recommend sizes and styles using AI
- Improve user experience
- Prevent fraud and misuse

3. Sharing of Data
We may share limited data with:
- Vendors (to fulfill orders or tailoring)
- Logistics partners (for delivery)
- Payment providers (for transactions)

We do NOT sell your personal data.

4. Data Security
We use secure systems and encryption to protect your data. However, no system is 100% secure.

5. Your Rights
You can:
- Update your profile
- Request data deletion
- Contact us for any privacy concerns

6. Data Retention
We retain data only as long as needed for services and legal purposes.

7. Contact Us
Email: support@abzora.com

By using ABZORA, you agree to this policy.''',
                          ),
                        ),
                        _PolicyLinkButton(
                          label: 'Terms of Use',
                          onTap: () => _showPolicySheet(
                            title: 'Terms of Use',
                            body:
                                'Using ABZORA means agreeing to platform rules for account usage, acceptable conduct, order flow, and payment handling. Continued usage confirms acceptance of these terms.',
                          ),
                        ),
                        _PolicyLinkButton(
                          label: 'Try at Home Policy',
                          onTap: () => _showPolicySheet(
                            title: 'Try at Home Policy',
                            body:
                                'Try-at-home slots are subject to availability and location. Product handling and return timing must follow the listed appointment and pickup guidelines.',
                          ),
                        ),
                        _PolicyLinkButton(
                          label: 'Refund & Cancellation',
                          onTap: () => _showPolicySheet(
                            title: 'Refund and Cancellation Policy',
                            body:
                                'Cancellations and refunds depend on order stage, product type, and quality checks. Eligible refunds are processed back to the original payment source as per platform timelines.',
                          ),
                        ),
                        _PolicyLinkButton(
                          label: 'Shipping Policy',
                          onTap: () => _showPolicySheet(
                            title: 'Shipping Policy',
                            body:
                                'Delivery timelines vary by seller location, custom-tailoring lead times, and service level. Tracking updates are available inside your order section after dispatch.',
                          ),
                        ),
                      ],
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

class _BenefitChip extends StatelessWidget {
  const _BenefitChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.abzioBorder.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AbzioTheme.accentColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyLinkButton extends StatelessWidget {
  const _PolicyLinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}
