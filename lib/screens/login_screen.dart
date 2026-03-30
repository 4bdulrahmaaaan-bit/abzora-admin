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
  });

  final AbzioAppMode mode;
  final bool adminEntry;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  String? _phoneError;

  bool get _useGoogleAdminLogin => kIsWeb && widget.adminEntry;

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
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              OtpVerificationScreen(
            phoneNumber: phone,
            mode: widget.mode,
            adminEntry: widget.adminEntry,
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
                                    : 'WELCOME BACK',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _useGoogleAdminLogin
                                ? 'Continue with your Google account'
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
                      Text(
                        'PHONE NUMBER',
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
                          horizontal: 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: hasError
                                ? const Color(0xFFD64C4C)
                                : isFocused
                                    ? AbzioTheme.accentColor
                                    : context.abzioBorder,
                            width: isFocused || hasError ? 1.4 : 1,
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
                              offset: const Offset(0, 8),
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
                                      : 'Use your phone number to continue securely.'),
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
                                    'Send OTP',
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
                            : 'Help is available if you have trouble receiving your OTP.',
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
