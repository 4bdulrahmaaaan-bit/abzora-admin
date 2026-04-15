import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../app_shell.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../theme.dart';
import '../utils/app_mode_routes.dart';
import '../widgets/brand_logo.dart';
import '../widgets/tap_scale.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    this.phoneNumber,
    this.mode = AbzioAppMode.unified,
    this.adminEntry = false,
    this.deferredAction = false,
  });

  final String? phoneNumber;
  final AbzioAppMode mode;
  final bool adminEntry;
  final bool deferredAction;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with SingleTickerProviderStateMixin, CodeAutoFill {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  late final AnimationController _errorShakeController;
  late final Animation<double> _errorShakeAnimation;
  Timer? _timer;
  int _remainingSeconds = 30;
  bool _autoSubmitting = false;
  String? _inlineError;

  Future<bool> _verifyAdminPinIfRequired(AppUser user) async {
    if (!widget.adminEntry || (user.role != 'admin' && user.role != 'super_admin')) {
      return true;
    }

    final settings = await DatabaseService().getPlatformSettings();
    if (!settings.adminPinEnabled) {
      return true;
    }
    if (!mounted) {
      return false;
    }

    final pinController = TextEditingController();
    final isValid = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Admin PIN'),
            content: TextField(
              controller: pinController,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Enter admin PIN',
                hintText: '4-digit pin',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, pinController.text.trim() == settings.adminPin),
                child: const Text('Verify'),
              ),
            ],
          ),
        ) ??
        false;
    pinController.dispose();
    return isValid;
  }

  @override
  void initState() {
    super.initState();
    _errorShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _errorShakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 2),
    ]).animate(
      CurvedAnimation(parent: _errorShakeController, curve: Curves.easeOutCubic),
    );
    _startTimer();
    _listenForOtpCode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    cancel();
    _errorShakeController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _listenForOtpCode() async {
    try {
      await SmsAutoFill().listenForCode();
    } catch (_) {
      // Auto-read is best-effort; manual OTP entry remains available.
    }
  }

  void _applyOtpCode(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return;
    }

    for (var i = 0; i < _controllers.length; i++) {
      _controllers[i].text = i < digits.length ? digits[i] : '';
    }

    final nextIndex = digits.length >= 6 ? 5 : digits.length;
    _focusNodes[nextIndex.clamp(0, 5)].requestFocus();
    if (mounted) {
      setState(() {
        _inlineError = null;
      });
    }

    if (_isOtpComplete) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _verifyOtp(autoTriggered: true),
      );
    }
  }

  @override
  void codeUpdated() {
    final latestCode = code;
    if (latestCode == null || latestCode.isEmpty) {
      return;
    }
    _applyOtpCode(latestCode);
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _remainingSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds == 0) {
        timer.cancel();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  String get _otpCode => _controllers.map((controller) => controller.text).join();

  bool get _isOtpComplete => _otpCode.length == 6;

  String _maskedPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\s+'), '');
    if (digits.length <= 6) {
      return phone;
    }
    final visiblePrefix = digits.substring(0, digits.length.clamp(0, 3));
    final visibleSuffix = digits.substring(digits.length - 2);
    final hiddenCount = (digits.length - visiblePrefix.length - visibleSuffix.length).clamp(0, 8);
    return '$visiblePrefix${'X' * hiddenCount}$visibleSuffix';
  }

  Future<void> _verifyOtp({bool autoTriggered = false}) async {
    if (!_isOtpComplete) {
      setState(() {
        _inlineError = 'Invalid OTP. Try again.';
      });
      _triggerOtpErrorFeedback();
      return;
    }

    if (_autoSubmitting) {
      return;
    }

    setState(() {
      _inlineError = null;
      _autoSubmitting = autoTriggered;
    });

    final authProvider = context.read<AuthProvider>();
    try {
      final user = await authProvider.verifyOtp(_otpCode);
      if (!mounted) {
        return;
      }
      if (user == null) {
        setState(() {
          _inlineError = 'Invalid OTP. Try again.';
        });
        _triggerOtpErrorFeedback();
        return;
      }
      final restriction = widget.adminEntry ? null : accessRestrictionMessage(user, widget.mode);
      final adminRestriction =
          widget.adminEntry && user.role != 'admin' && user.role != 'super_admin'
              ? 'This OTP entry is reserved for super admin access.'
              : null;
      final combinedRestriction = adminRestriction ?? restriction;
      if (combinedRestriction != null) {
        await authProvider.logout();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(combinedRestriction),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, widget.adminEntry ? '/admin-login' : '/login', (route) => false);
        return;
      }
      final adminPinOk = await _verifyAdminPinIfRequired(user);
      if (!mounted) {
        return;
      }
      if (!adminPinOk) {
        await authProvider.logout();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Admin PIN verification failed.'),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/admin-login', (route) => false);
        return;
      }
      if (widget.deferredAction) {
        Navigator.of(context).pop(true);
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        routeForUserInMode(user, widget.mode),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString().replaceFirst('Bad state: ', '').trim();
      setState(() {
        _inlineError = message.isEmpty ? 'Invalid OTP. Try again.' : message;
      });
      _triggerOtpErrorFeedback();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(_inlineError!),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _autoSubmitting = false;
        });
      }
    }
  }

  Future<void> _resendOtp(String phone) async {
    if (_remainingSeconds > 0) {
      return;
    }
    final authProvider = context.read<AuthProvider>();
    try {
      await authProvider.requestOtp(phone);
      if (!mounted) {
        return;
      }
      for (final controller in _controllers) {
        controller.clear();
      }
      setState(() {
        _inlineError = null;
      });
      _focusNodes.first.requestFocus();
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('A new OTP has been sent.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString().replaceFirst('Bad state: ', '').trim();
      setState(() {
        _inlineError = message.isEmpty ? 'Unable to resend OTP right now' : message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(_inlineError!),
        ),
      );
    }
  }

  void _handleOtpChange(int index, String value) {
    if (_inlineError != null) {
      setState(() => _inlineError = null);
    }

    if (value.length > 1) {
      _applyOtpCode(value);
      return;
    }

    if (value.isNotEmpty && index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    setState(() {});

    if (_isOtpComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verifyOtp(autoTriggered: true));
    }
  }

  void _triggerOtpErrorFeedback() {
    HapticFeedback.mediumImpact();
    _errorShakeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final phone = widget.phoneNumber ?? auth.pendingPhoneNumber ?? '';
    final isBusy = auth.isLoading || _autoSubmitting;

    return AbzioThemeScope.light(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).colorScheme.onSurface, size: 20),
            onPressed: isBusy ? null : () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: AutofillGroup(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      Hero(
                        tag: 'auth-brand-logo',
                        child: BrandLogo.hero(
                          size: 82,
                          radius: 22,
                          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                          padding: const EdgeInsets.all(6),
                          shadows: [
                            BoxShadow(
                              color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        widget.adminEntry ? 'VERIFY ACCESS' : 'VERIFY YOUR NUMBER',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: context.abzioSecondaryText,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                          children: [
                            const TextSpan(text: 'Enter the 6-digit code sent to '),
                            TextSpan(
                              text: _maskedPhone(phone),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: isBusy ? null : () => Navigator.pop(context),
                        child: const Text('Change number'),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: isBusy
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AbzioTheme.accentColor,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Verifying securely...',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: context.abzioSecondaryText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox(height: 6),
                      ),
                      const SizedBox(height: 24),
                      AnimatedBuilder(
                        animation: _errorShakeAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_errorShakeAnimation.value, 0),
                            child: child,
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            6,
                            (index) => Padding(
                              padding: EdgeInsets.only(right: index == 5 ? 0 : 8),
                              child: _OtpDigitBox(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                autoFocus: index == 0,
                                isActive: _focusNodes[index].hasFocus,
                                isFilled: _controllers[index].text.isNotEmpty,
                                hasError: _inlineError != null,
                                onChanged: (value) => _handleOtpChange(index, value),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: _inlineError == null
                            ? const SizedBox(height: 18)
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  _inlineError!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.red.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _remainingSeconds > 0
                            ? Text(
                                'Resend code in ${_remainingSeconds}s',
                                key: ValueKey(_remainingSeconds),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: context.abzioSecondaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : TextButton(
                                key: const ValueKey('resend'),
                                onPressed: isBusy ? null : () => _resendOtp(phone),
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                child: Text(
                                  'Resend OTP',
                                  style: GoogleFonts.poppins(
                                    color: AbzioTheme.accentColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 26),
                      TapScale(
                        onTap: (!isBusy && _isOtpComplete) ? _verifyOtp : null,
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (!isBusy && _isOtpComplete) ? () => _verifyOtp() : null,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              elevation: 1,
                              shadowColor: AbzioTheme.accentColor.withValues(alpha: 0.18),
                              backgroundColor: Theme.of(context).colorScheme.onSurface,
                              foregroundColor: Theme.of(context).colorScheme.surface,
                              disabledBackgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
                              disabledForegroundColor: context.abzioSecondaryText,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            child: isBusy
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Theme.of(context).colorScheme.surface,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Continue',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Secure login via OTP',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: context.abzioSecondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The code may be filled automatically if your device detects it.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: context.abzioSecondaryText,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpDigitBox extends StatelessWidget {
  const _OtpDigitBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.isActive,
    required this.isFilled,
    required this.hasError,
    this.autoFocus = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool isActive;
  final bool isFilled;
  final bool hasError;
  final bool autoFocus;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 50,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError
              ? const Color(0xFFD64C4C)
              : isActive
                  ? AbzioTheme.accentColor
                  : context.abzioBorder,
          width: isActive ? 1.6 : 1,
        ),
        boxShadow: isActive || hasError
            ? [
                BoxShadow(
                  color: (hasError ? const Color(0xFFD64C4C) : AbzioTheme.accentColor)
                      .withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autoFocus,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        maxLength: 1,
        autofillHints: const [AutofillHints.oneTimeCode],
        style: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: isFilled ? FontWeight.w800 : FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
      ),
    );
  }
}
