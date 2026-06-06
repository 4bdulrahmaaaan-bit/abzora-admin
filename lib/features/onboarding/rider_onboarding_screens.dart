import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:confetti/confetti.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/rider_validators.dart';
import '../../../core/widgets/rider_glass_card.dart';
import '../../../core/widgets/rider_glow_button.dart';
import '../../../core/widgets/rider_validated_text_field.dart';
import '../../../models/rider_signup_model.dart';
import '../../../providers/rider_signup_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../app_shell.dart';
import '../../../services/database_service.dart';
import '../../../services/onboarding_service.dart';
import '../../../core/services/rider_telemetry.dart';
import '../../../models/models.dart';
import '../../../routes/rider_routes.dart';
import '../../../screens/otp_verification_screen.dart';
import '../../../utils/app_mode_routes.dart';
import '../../../utils/app_error_text.dart';
import '../legal/legal_consent_screen.dart';
import '../legal/legal_document_registry.dart';

class RiderSplashScreen extends StatefulWidget {
  const RiderSplashScreen({super.key});

  @override
  State<RiderSplashScreen> createState() => _RiderSplashScreenState();
}

class _RiderSplashScreenState extends State<RiderSplashScreen> {
  static const _splashDuration = Duration(milliseconds: 1500);
  static const _logoAsset = 'assets/branding/abzora_partner_icon.png';

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(_splashDuration, _routeFromSplash);
  }

  Future<void> _routeFromSplash() async {
    if (!mounted) {
      return;
    }

    final auth = context.read<AuthProvider>();
    if (!auth.isInitialized) {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (!mounted) {
          return;
        }
        if (auth.isInitialized) {
          break;
        }
      }
    }

    if (!mounted) {
      return;
    }

    final isAuthenticated = auth.isAuthenticated && auth.user != null;
    context.replace(isAuthenticated ? RiderRoutes.dashboard : RiderRoutes.auth);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child:
            const Image(
                  image: AssetImage(_logoAsset),
                  width: 168,
                  height: 168,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                )
                .animate()
                .fadeIn(duration: _splashDuration, curve: Curves.easeOut)
                .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1, 1),
                  duration: _splashDuration,
                  curve: Curves.easeOut,
                ),
      ),
    );
  }
}

class RiderAuthBannerScreen extends StatefulWidget {
  const RiderAuthBannerScreen({super.key});

  @override
  State<RiderAuthBannerScreen> createState() => _RiderAuthBannerScreenState();
}

class _RiderAuthBannerScreenState extends State<RiderAuthBannerScreen> {
  final PageController _bannerController = PageController();
  final TextEditingController _phoneController = TextEditingController();
  Timer? _bannerTimer;
  int _bannerIndex = 0;

  static const List<
    ({
      String title,
      String subtitle,
      IconData icon,
      String imagePath,
      double textTopOffset,
    })
  >
  _banners = [
    (
      title: 'Earn More',
      subtitle: 'Weekly payouts and performance bonuses',
      icon: Icons.currency_rupee_rounded,
      imagePath: 'assets/onboarding/rider_visual_0.jpg',
      textTopOffset: 2,
    ),
    (
      title: 'Real-Time Orders',
      subtitle: 'Accept and manage deliveries instantly',
      icon: Icons.route_rounded,
      imagePath: 'assets/onboarding/rider_visual_1.jpg',
      textTopOffset: 6,
    ),
    (
      title: 'Deliver with Confidence',
      subtitle: 'Navigation, support and secure payments',
      icon: Icons.verified_user_rounded,
      imagePath: 'assets/onboarding/rider_visual_2.jpg',
      textTopOffset: -2,
    ),
    (
      title: 'Flexible Working Hours',
      subtitle: 'Ride whenever it suits your schedule',
      icon: Icons.schedule_rounded,
      imagePath: 'assets/onboarding/rider_visual_3.jpg',
      textTopOffset: 8,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_bannerController.hasClients) {
        return;
      }
      final next = (_bannerIndex + 1) % _banners.length;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
      setState(() => _bannerIndex = next);
    });
  }

  String _normalizedPhone() {
    return _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> _startOtp() async {
    final phone = _normalizedPhone();
    if (phone.length != 10) {
      context.showRiderSnack('Enter a valid 10-digit mobile number.');
      return;
    }
    final auth = context.read<AuthProvider>();
    try {
      await auth.requestOtp(phone);
      if (!mounted) {
        return;
      }
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            phoneNumber: phone,
            mode: AbzioAppMode.rider,
            deferredAction: true,
            allowPartnerOnboarding: true,
          ),
        ),
      );
      if (!mounted || verified != true) {
        return;
      }
      final user =
          await auth.refreshProfileFromBackendIfPossible() ?? auth.user;
      if (!mounted) {
        return;
      }
      context.go(
        hasRiderOperationsAccess(user)
            ? RiderRoutes.dashboard
            : RiderRoutes.profileSetup,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      context.showRiderSnack(AppErrorText.from(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final screenHeight = MediaQuery.sizeOf(context).height;
    final loginCardHeight = screenHeight < 720 ? 356.0 : 390.0;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _bannerController,
              onPageChanged: (index) => setState(() => _bannerIndex = index),
              itemCount: _banners.length,
              itemBuilder: (context, index) {
                final banner = _banners[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    TweenAnimationBuilder<double>(
                      key: ValueKey(banner.imagePath),
                      tween: Tween(begin: 1.0, end: 1.035),
                      duration: const Duration(seconds: 7),
                      curve: Curves.easeOutCubic,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Image.asset(banner.imagePath, fit: BoxFit.cover),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.black.withValues(alpha: 0.20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 360),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: Column(
                          key: ValueKey(banner.title),
                          children: [
                            SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: 80 + banner.textTopOffset,
                                ),
                                child: SizedBox(
                                  width: MediaQuery.sizeOf(context).width * 0.8,
                                  child: Column(
                                    children: [
                                      Text(
                                        banner.title,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontFamily: 'Cormorant Garamond',
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFFFFFFF),
                                          letterSpacing: 0.5,
                                          height: 1.05,
                                          shadows: [
                                            Shadow(
                                              color: Color(0x40000000),
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        banner.subtitle,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white.withValues(
                                            alpha: 0.90,
                                          ),
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w500,
                                          height: 1.4,
                                          shadows: const [
                                            Shadow(
                                              color: Color(0x33000000),
                                              blurRadius: 6,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: loginCardHeight + 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(_banners.length, (index) {
                final active = index == _bannerIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFD4AF37)
                        : const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
              decoration: const BoxDecoration(
                color: Color(0xEB111111),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter rider workspace',
                      style: TextStyle(
                        fontSize: 27,
                        fontFamily: 'Cormorant Garamond',
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF5E7C1),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Use your registered mobile number to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFC8A96B),
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontWeight: FontWeight.w700,
                      ),
                      cursorColor: Color(0xFFD4AF37),
                      decoration: InputDecoration(
                        prefixText: '+91  ',
                        prefixStyle: const TextStyle(
                          color: Color(0xFF111111),
                          fontWeight: FontWeight.w800,
                        ),
                        counterText: '',
                        hintText: 'Enter 10 digit mobile number',
                        hintStyle: const TextStyle(color: Color(0xFF9A958B)),
                        filled: true,
                        fillColor: const Color(0xFFFAF8F2),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5D7B3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFD4AF37),
                            width: 1.4,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _startOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: const Color(0xFFE0D8C9),
                          foregroundColor: const Color(0xFF111111),
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD4AF37), Color(0xFFF5E7C1)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF111111),
                                    ),
                                  )
                                : const Text(
                                    'Continue with Mobile',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        text: "By logging in, I agree to Abianzo's ",
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
                                      audience: LegalAudience.rider,
                                    ),
                                  ),
                                );
                              },
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFC8A96B),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RiderOnboardingFlowScreen extends ConsumerStatefulWidget {
  const RiderOnboardingFlowScreen({super.key});

  @override
  ConsumerState<RiderOnboardingFlowScreen> createState() =>
      _RiderOnboardingFlowScreenState();
}

class _RiderOnboardingFlowScreenState
    extends ConsumerState<RiderOnboardingFlowScreen> {
  static const double _kycMinimumConfidence = 75;
  final _pageController = PageController();
  final _otpController = TextEditingController();
  final _onboardingService = OnboardingService();
  final _db = DatabaseService();
  int _step = 0;
  bool _verifying = false;
  bool _submitting = false;
  int _invalidSubmitTick = 0;
  bool _ifscLookupLoading = false;
  String _ifscLookupMessage = '';
  String _detectedBankName = '';
  static const _draftKey = 'rider_onboarding_draft_v1';
  static const List<String> _stepTitles = <String>[
    'Phone Authentication',
    'OTP Verification',
    'Personal Details',
    'Vehicle Details',
    'KYC Verification',
    'Bank Details',
    'Delivery Preferences',
    'Terms & Agreement',
    'Application Review',
  ];
  static const List<String> _stepSubtitles = <String>[
    'Verify your phone to start secure onboarding.',
    'Enter the 6-digit code to continue.',
    'Share your basic identity and profile photo.',
    'Add your vehicle and mandatory transport docs.',
    'Complete rider identity checks with confidence.',
    'Set payout details for weekly settlements.',
    'Choose shifts, work mode, and service zone.',
    'Accept policies and add your digital signature.',
    'Review progress before final submission.',
  ];

  @override
  void initState() {
    super.initState();
    _restoreDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final auth = context.read<AuthProvider>();
      final pendingPhone = (auth.pendingPhoneNumber ?? '').replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      if (pendingPhone.length == 10 || pendingPhone.length == 12) {
        final normalized = pendingPhone.length == 12
            ? pendingPhone.substring(2)
            : pendingPhone;
        final model = ref.read(riderSignupProvider);
        ref
            .read(riderSignupProvider.notifier)
            .update(model.copyWith(phone: normalized));
        if (_step == 0) {
          setState(() => _step = 1);
          _pageController.jumpToPage(1);
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (x == null) return;
    final m = ref.read(riderSignupProvider);
    ref
        .read(riderSignupProvider.notifier)
        .update(m.copyWith(profilePhotoPath: x.path));
    _saveDraft(ref.read(riderSignupProvider));
  }

  Future<void> _pickFile(void Function(String) setter) async {
    final file = await FilePicker.platform.pickFiles();
    if (file?.files.single.path != null) {
      setter(file!.files.single.path!);
      _saveDraft(ref.read(riderSignupProvider));
    }
  }

  void _next() {
    final model = ref.read(riderSignupProvider);
    final error = _validateStep(model, _step);
    if (error != null) {
      HapticFeedback.mediumImpact();
      setState(() => _invalidSubmitTick++);
      context.showRiderSnack(error);
      return;
    }
    if (_step < 8) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    context.replace(RiderRoutes.success);
  }

  void _back() {
    if (_step == 0) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go(RiderRoutes.auth);
      }
      return;
    }
    setState(() => _step--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  String? _validateStep(RiderSignupModel model, int step) {
    switch (step) {
      case 0:
        return AppValidators.phone(model.phone);
      case 1:
        return _otpController.text.trim().length == 6
            ? null
            : 'Verify OTP to continue';
      case 2:
        return AppValidators.requiredField(model.fullName, 'Full name') ??
            AppValidators.email(model.email) ??
            AppValidators.requiredField(model.city, 'City');
      case 3:
        return AppValidators.vehicleNumber(model.vehicleNumber) ??
            AppValidators.requiredField(model.licenseNumber, 'License number');
      case 4:
        return AppValidators.aadhaar(model.aadhaar) ??
            AppValidators.pan(model.pan);
      case 5:
        return AppValidators.requiredField(
              model.accountHolder,
              'Account holder',
            ) ??
            AppValidators.requiredField(model.bankName, 'Bank name') ??
            AppValidators.bankAccount(model.accountNumber) ??
            AppValidators.ifsc(model.ifsc) ??
            AppValidators.upi(model.upi);
      case 7:
        return model.acceptedTerms
            ? null
            : 'Accept terms and provide signature';
      default:
        return null;
    }
  }

  Future<void> _saveDraft(RiderSignupModel model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(model.toJson()));
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      ref
          .read(riderSignupProvider.notifier)
          .update(RiderSignupModel.fromJson(decoded));
    } catch (_) {}
  }

  Future<void> _requestOtp(RiderSignupModel model) async {
    final phoneError = AppValidators.phone(model.phone);
    if (phoneError != null) {
      context.showRiderSnack(phoneError);
      return;
    }
    final auth = context.read<AuthProvider>();
    try {
      RiderTelemetry.event('otp_request_started', data: {'step': _step});
      await auth.requestOtp(model.phone);
      if (!mounted) return;
      RiderTelemetry.event('otp_request_success', data: {'step': _step});
      context.showRiderSnack('OTP sent successfully');
    } catch (e) {
      if (!mounted) return;
      RiderTelemetry.event('otp_request_failed', data: {'error': e.toString()});
      context.showRiderSnack(e.toString());
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().length != 6) {
      context.showRiderSnack('Enter the 6-digit OTP');
      return;
    }
    setState(() => _verifying = true);
    final auth = context.read<AuthProvider>();
    try {
      RiderTelemetry.event('otp_verify_started', data: {'step': _step});
      final user = await auth.verifyOtp(_otpController.text.trim());
      if (!mounted) return;
      if (user == null) {
        RiderTelemetry.event('otp_verify_failed_null_user');
        context.showRiderSnack('OTP verification failed');
      } else {
        RiderTelemetry.event('otp_verify_success', data: {'userId': user.id});
        context.showRiderSnack('Phone verified successfully');
      }
    } catch (e) {
      if (!mounted) return;
      RiderTelemetry.event('otp_verify_failed', data: {'error': e.toString()});
      context.showRiderSnack(e.toString());
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<T> _withRetry<T>(
    Future<T> Function() action, {
    int attempts = 2,
  }) async {
    Object? lastError;
    for (var i = 0; i < attempts; i++) {
      try {
        return await action();
      } catch (e) {
        lastError = e;
        if (i < attempts - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
      }
    }
    throw lastError ?? StateError('Unknown retry failure');
  }

  Future<void> _submitApplication(RiderSignupModel model) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      context.showRiderSnack('Please verify phone number first.');
      return;
    }
    if (model.profilePhotoPath == null ||
        model.licenseDocPath == null ||
        model.selfiePath == null) {
      context.showRiderSnack('Upload profile photo, license, and selfie.');
      return;
    }

    setState(() => _submitting = true);
    try {
      RiderTelemetry.event('rider_submit_started', data: {'userId': user.id});
      final profileUrl = await _withRetry(
        () => _onboardingService.uploadRiderProfilePhoto(
          file: XFile(model.profilePhotoPath!),
          ownerId: user.id,
        ),
      );
      final aadhaarUrl = await _withRetry(
        () => _onboardingService.uploadRiderDocument(
          file: XFile(model.selfiePath!),
          ownerId: user.id,
          label: 'aadhaar',
        ),
      );
      final licenseUrl = await _withRetry(
        () => _onboardingService.uploadRiderDocument(
          file: XFile(model.licenseDocPath!),
          ownerId: user.id,
          label: 'license',
        ),
      );

      final ocrExtraction = await _withRetry(
        () => _onboardingService.extractKycFields(
          documentType: 'aadhaar_pan',
          text: '${model.aadhaar} ${model.pan} ${model.fullName}',
          documentUrl: aadhaarUrl,
        ),
      );

      final verificationSummary = await _withRetry(
        () => _onboardingService.verifyRiderKyc(
          aadhaarNumber: model.aadhaar,
          panNumber: model.pan,
          profilePhotoUrl: profileUrl,
          selfieUrl: aadhaarUrl,
          licenseUrl: licenseUrl,
        ),
      );
      final confidence =
          (verificationSummary['confidenceScore'] as num?)?.toDouble() ?? 0;
      final verificationStatus = (verificationSummary['status'] ?? '')
          .toString()
          .trim();
      if (confidence < _kycMinimumConfidence ||
          verificationStatus == 'manual_review') {
        if (mounted) {
          HapticFeedback.heavyImpact();
          context.showRiderSnack(
            'KYC confidence is low (${confidence.toStringAsFixed(0)}%). Please re-upload clearer documents before submission.',
          );
        }
        return;
      }

      final nowIso = DateTime.now().toIso8601String();
      await _onboardingService.submitRiderRequest(
        actor: user,
        request: RiderKycRequest(
          id: 'rider-${user.id}',
          userId: user.id,
          name: model.fullName.trim(),
          phone: model.phone.trim(),
          vehicle: model.vehicleType.name,
          city: model.city.trim(),
          kyc: KycDocuments(
            profilePhotoUrl: profileUrl,
            aadhaarUrl: aadhaarUrl,
            licenseUrl: licenseUrl,
          ),
          metadata: {
            'email': model.email.trim(),
            'dob': model.dob?.toIso8601String() ?? '',
            'gender': model.gender,
            'profilePhotoPath': model.profilePhotoPath ?? '',
            'vehicle': {
              'vehicleType': model.vehicleType.name,
              'vehicleNumber': model.vehicleNumber.trim(),
              'licenseNumber': model.licenseNumber.trim(),
              'rcPath': model.rcPath ?? '',
              'insurancePath': model.insurancePath ?? '',
            },
            'bank': {
              'accountHolder': model.accountHolder.trim(),
              'bankName': model.bankName.trim(),
              'accountNumber': model.accountNumber.trim(),
              'ifsc': model.ifsc.trim(),
              'upi': model.upi.trim(),
            },
            'preferences': {
              'referral': model.referral.trim(),
              'workType': model.workType.name,
              'shift': model.shift,
              'zone': {
                'lat': model.zoneLat,
                'lng': model.zoneLng,
                'radiusKm': model.zoneRadiusKm,
              },
            },
            'terms': {
              'acceptedTerms': model.acceptedTerms,
              'signature': model.signature.trim(),
            },
            'ocrExtraction': ocrExtraction,
            'verification': verificationSummary,
            'submittedAt': nowIso,
            'source': 'rider_app_v2',
          },
          createdAt: nowIso,
          updatedAt: nowIso,
        ),
      );
      if (model.accountHolder.trim().isNotEmpty &&
          (model.upi.trim().isNotEmpty ||
              (model.accountNumber.trim().isNotEmpty &&
                  model.ifsc.trim().isNotEmpty))) {
        await _withRetry(
          () => _db.saveRiderPayoutProfile(
            actor: user,
            methodType: model.upi.trim().isNotEmpty ? 'upi' : 'bank',
            accountHolderName: model.accountHolder.trim(),
            upiId: model.upi.trim(),
            bankAccountNumber: model.accountNumber.trim(),
            bankIfsc: model.ifsc.trim(),
            bankName: model.bankName.trim(),
          ),
        );
      }
      if (!mounted) return;
      RiderTelemetry.event('rider_submit_success', data: {'userId': user.id});
      context.replace(RiderRoutes.success);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      await prefs.remove(_draftKey);
    } catch (e) {
      if (!mounted) return;
      RiderTelemetry.event(
        'rider_submit_failed',
        data: {'error': e.toString()},
      );
      context.showRiderSnack(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _lookupIfscIfReady(RiderSignupModel model, String value) async {
    final code = value.trim().toUpperCase();
    if (code.length != 11) {
      if (!mounted) return;
      setState(() {
        _ifscLookupLoading = false;
        _ifscLookupMessage = '';
        _detectedBankName = '';
      });
      return;
    }
    setState(() {
      _ifscLookupLoading = true;
      _ifscLookupMessage = '';
    });
    try {
      final result = await _onboardingService.lookupIfsc(code);
      if (!mounted) return;
      setState(() {
        _detectedBankName = (result['bankName'] ?? '').toString();
        _ifscLookupMessage = _detectedBankName.isEmpty
            ? 'IFSC verified'
            : 'Bank detected: $_detectedBankName';
      });
      if (_detectedBankName.isNotEmpty &&
          model.bankName.trim().isEmpty &&
          mounted) {
        ref
            .read(riderSignupProvider.notifier)
            .update(model.copyWith(bankName: _detectedBankName));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ifscLookupMessage = 'Unable to auto-detect bank right now';
      });
    } finally {
      if (mounted) {
        setState(() => _ifscLookupLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(riderSignupProvider);
    final stepError = _validateStep(model, _step);
    final canContinue = stepError == null;

    final progress = (_step + 1) / 9;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _back,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Back',
        ),
        title: Text(_stepTitles[_step]),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFF080808)),
          ),
          Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _stepIndicatorChip(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _stepSubtitles[_step],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFD0D0D0),
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(
                            color: Color(0xFFFFB300),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: progress,
                        backgroundColor: Color(0x33FFFFFF),
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFF5D76E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: List<Widget>.generate(9, (index) {
                        final active = index == _step;
                        final complete = index < _step;
                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: EdgeInsets.only(right: index == 8 ? 0 : 4),
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              color: complete
                                  ? const Color(0xFFD4AF37)
                                  : active
                                  ? const Color(0xFFF5D76E)
                                  : Color(0x33FFFFFF),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _phoneStep(model),
                    _otpStep(),
                    _personalStep(model),
                    _vehicleStep(model),
                    _kycStep(model),
                    _bankStep(model),
                    _preferencesStep(model),
                    _termsStep(model),
                    _reviewStep(model),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  transform: Matrix4.translationValues(
                    _invalidSubmitTick.isOdd ? 6 : 0,
                    0,
                    0,
                  ),
                  child: RiderGlowButton(
                    label: _step == 8
                        ? (_submitting ? 'Submitting...' : 'Submit Application')
                        : 'Save & Continue',
                    onPressed: _step == 8
                        ? (_submitting ? null : () => _submitApplication(model))
                        : (canContinue ? _next : null),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _phoneStep(RiderSignupModel model) {
    return _formCard(
      title: 'Phone Authentication',
      child: Column(
        children: [
          RiderValidatedTextField(
            initialValue: model.phone,
            label: 'Phone Number (+91)',
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
            helperText: '10 digits starting with 6, 7, 8, or 9',
            exampleText: 'Example: 9876543210',
            validator: AppValidators.phone,
            onChanged: (v) => ref
                .read(riderSignupProvider.notifier)
                .update(model.copyWith(phone: v)),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _requestOtp(model),
              child: const Text('Send OTP'),
            ),
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(value: 0.4, color: Color(0xFFD4AF37)),
        ],
      ),
    );
  }

  Widget _otpStep() {
    return _formCard(
      title: 'OTP Verification',
      child: Column(
        children: [
          PinCodeTextField(
            appContext: context,
            length: 6,
            controller: _otpController,
            keyboardType: TextInputType.number,
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(14),
              fieldWidth: 44,
              activeColor: const Color(0xFFD4AF37),
              inactiveColor: Color(0x55FFFFFF),
              selectedColor: const Color(0xFFD4AF37),
            ),
            onChanged: (_) {},
          ),
          const SizedBox(height: 8),
          if (_verifying)
            const CircularProgressIndicator(color: Color(0xFFD4AF37)),
          if (!_verifying)
            TextButton(onPressed: _verifyOtp, child: const Text('Verify OTP')),
        ],
      ),
    );
  }

  Widget _personalStep(RiderSignupModel model) {
    final content = <Widget>[
      TextFormField(
        initialValue: model.fullName,
        decoration: _onboardingInputDecoration('Full Name'),
        onChanged: (v) => ref
            .read(riderSignupProvider.notifier)
            .update(model.copyWith(fullName: v)),
        onTapOutside: (_) => _saveDraft(ref.read(riderSignupProvider)),
      ),
      const SizedBox(height: 10),
      TextFormField(
        initialValue: model.email,
        decoration: _onboardingInputDecoration('Email Address'),
        onChanged: (v) => ref
            .read(riderSignupProvider.notifier)
            .update(model.copyWith(email: v)),
        onTapOutside: (_) => _saveDraft(ref.read(riderSignupProvider)),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: model.city.isEmpty ? null : model.city,
        hint: const Text('Select City'),
        items: const [
          'Bengaluru',
          'Mumbai',
          'Delhi',
          'Hyderabad',
        ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => ref
            .read(riderSignupProvider.notifier)
            .update(model.copyWith(city: v ?? '')),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: _statusPill(model.profilePhotoPath != null)),
          TextButton(onPressed: _pickImage, child: const Text('Upload')),
        ],
      ),
    ];
    return _formCard(title: 'Personal Details', child: _staggerColumn(content));
  }

  Widget _vehicleStep(RiderSignupModel model) {
    return _formCard(
      title: 'Vehicle Details',
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            children: VehicleType.values.map((v) {
              final selected = model.vehicleType == v;
              return ChoiceChip(
                label: Text(v.name),
                selected: selected,
                selectedColor: const Color(0xFFD4AF37),
                onSelected: (selected) => ref
                    .read(riderSignupProvider.notifier)
                    .update(model.copyWith(vehicleType: v)),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          RiderValidatedTextField(
            initialValue: model.vehicleNumber,
            label: 'Vehicle Number',
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                final normalized = newValue.text
                    .replaceAll(RegExp(r'\s+'), '')
                    .toUpperCase();
                return TextEditingValue(
                  text: normalized,
                  selection: TextSelection.collapsed(offset: normalized.length),
                );
              }),
            ],
            helperText: 'Format: TN01AB1234 or KA05MK9090',
            validator: AppValidators.vehicleNumber,
            onChanged: (v) => ref
                .read(riderSignupProvider.notifier)
                .update(model.copyWith(vehicleNumber: v)),
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: model.licenseNumber,
            decoration: _onboardingInputDecoration('Driving License Number'),
            onChanged: (v) => ref
                .read(riderSignupProvider.notifier)
                .update(model.copyWith(licenseNumber: v)),
          ),
          const SizedBox(height: 10),
          _uploadRow(
            'RC Book',
            model.rcPath,
            (p) => ref
                .read(riderSignupProvider.notifier)
                .update(model.copyWith(rcPath: p)),
          ),
          _uploadRow(
            'Insurance',
            model.insurancePath,
            (p) => ref
                .read(riderSignupProvider.notifier)
                .update(model.copyWith(insurancePath: p)),
          ),
        ],
      ),
    );
  }

  Widget _kycStep(RiderSignupModel model) {
    return _formCard(
      title: 'KYC Verification',
      child: Column(
        children: [
          RiderValidatedTextField(
            initialValue: model.aadhaar,
            label: 'Aadhaar Number',
            keyboardType: TextInputType.number,
            inputFormatters: [AadhaarInputFormatter()],
            helperText: '12 digits in XXXX XXXX XXXX format',
            validator: AppValidators.aadhaar,
            onChanged: (v) => ref
                .read(riderSignupProvider.notifier)
                .update(model.copyWith(aadhaar: v)),
          ),
          const SizedBox(height: 10),
          RiderValidatedTextField(
            initialValue: model.pan,
            label: 'PAN Number',
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              LengthLimitingTextInputFormatter(10),
              TextInputFormatter.withFunction((oldValue, newValue) {
                final upper = newValue.text.toUpperCase();
                return TextEditingValue(
                  text: upper,
                  selection: TextSelection.collapsed(offset: upper.length),
                );
              }),
            ],
            helperText: 'Format: AAAAA9999A',
            validator: AppValidators.pan,
            onChanged: (v) => ref
                .read(riderSignupProvider.notifier)
                .update(model.copyWith(pan: v)),
          ),
          const SizedBox(height: 10),
          _uploadRow(
            'Driving License Upload',
            model.licenseDocPath,
            (p) => ref
                .read(riderSignupProvider.notifier)
                .update(model.copyWith(licenseDocPath: p)),
          ),
          _uploadRow(
            'Selfie Verification',
            model.selfiePath,
            (p) => ref
                .read(riderSignupProvider.notifier)
                .update(model.copyWith(selfiePath: p)),
          ),
          const SizedBox(height: 10),
          const LinearProgressIndicator(value: 0.75, color: Color(0xFFD4AF37)),
          const SizedBox(height: 8),
          const Text(
            'Secure encrypted verification in progress',
            style: TextStyle(color: Color.fromRGBO(255, 255, 255, 0.78)),
          ),
        ],
      ),
    );
  }

  Widget _bankStep(RiderSignupModel model) {
    return _formCard(
      title: 'Bank Details',
      child: Column(
        children: [
          TextFormField(
            initialValue: model.accountHolder,
            decoration: _onboardingInputDecoration('Account Holder Name'),
            onChanged: (v) => ref
                .read(riderSignupProvider.notifier)
                .update(model.copyWith(accountHolder: v)),
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: model.bankName,
            decoration: _onboardingInputDecoration('Bank Name'),
            onChanged: (v) => ref
                .read(riderSignupProvider.notifier)
                .update(model.copyWith(bankName: v)),
          ),
          const SizedBox(height: 10),
          RiderValidatedTextField(
            initialValue: model.accountNumber,
            label: 'Account Number',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 18,
            helperText: '9 to 18 digits',
            validator: AppValidators.bankAccount,
            onChanged: (v) => ref
                .read(riderSignupProvider.notifier)
                .update(model.copyWith(accountNumber: v)),
          ),
          const SizedBox(height: 10),
          RiderValidatedTextField(
            initialValue: model.ifsc,
            label: 'IFSC Code',
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              LengthLimitingTextInputFormatter(11),
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                final upper = newValue.text.toUpperCase();
                return TextEditingValue(
                  text: upper,
                  selection: TextSelection.collapsed(offset: upper.length),
                );
              }),
            ],
            helperText: 'Format: HDFC0001234',
            validator: AppValidators.ifsc,
            onChanged: (v) {
              ref
                  .read(riderSignupProvider.notifier)
                  .update(model.copyWith(ifsc: v));
              _lookupIfscIfReady(model, v);
            },
          ),
          const SizedBox(height: 6),
          if (_ifscLookupLoading)
            const Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (_ifscLookupMessage.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _ifscLookupMessage,
                style: const TextStyle(
                  color: Color.fromRGBO(255, 255, 255, 0.78),
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 10),
          RiderValidatedTextField(
            initialValue: model.upi,
            label: 'UPI ID (optional)',
            keyboardType: TextInputType.emailAddress,
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            helperText: 'Format: username@bank',
            validator: AppValidators.upi,
            onChanged: (v) => ref
                .read(riderSignupProvider.notifier)
                .update(model.copyWith(upi: v)),
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Icon(Icons.lock_rounded, color: Colors.greenAccent, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Encrypted payout details. Stored securely for settlement only.',
                  style: TextStyle(
                    color: Color.fromRGBO(255, 255, 255, 0.78),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _preferencesStep(RiderSignupModel model) {
    return _formCard(
      title: 'Delivery Preferences',
      child: Column(
        children: [
          TextFormField(
            initialValue: model.referral,
            decoration: _onboardingInputDecoration('Referral Code (optional)'),
            onChanged: (v) => ref
                .read(riderSignupProvider.notifier)
                .update(model.copyWith(referral: v)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: WorkType.values.map((w) {
              return ChoiceChip(
                label: Text(w == WorkType.fullTime ? 'Full-time' : 'Part-time'),
                selected: model.workType == w,
                selectedColor: const Color(0xFFD4AF37),
                onSelected: (selected) => ref
                    .read(riderSignupProvider.notifier)
                    .update(model.copyWith(workType: w)),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['Morning', 'Afternoon', 'Night'].map((shift) {
              return ChoiceChip(
                label: Text(shift),
                selected: model.shift == shift,
                selectedColor: const Color(0xFFD4AF37),
                onSelected: (selected) => ref
                    .read(riderSignupProvider.notifier)
                    .update(model.copyWith(shift: shift)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Zone Radius'),
              Expanded(
                child: Slider(
                  value: model.zoneRadiusKm.clamp(1, 20),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  label: '${model.zoneRadiusKm.toStringAsFixed(0)} km',
                  onChanged: (v) => ref
                      .read(riderSignupProvider.notifier)
                      .update(model.copyWith(zoneRadiusKm: v)),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      model.zoneLat ?? 12.9716,
                      model.zoneLng ?? 77.5946,
                    ),
                    zoom: 11,
                  ),
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  onTap: (point) {
                    ref
                        .read(riderSignupProvider.notifier)
                        .update(
                          model.copyWith(
                            zoneLat: point.latitude,
                            zoneLng: point.longitude,
                          ),
                        );
                  },
                  markers: {
                    if (model.zoneLat != null && model.zoneLng != null)
                      Marker(
                        markerId: const MarkerId('zone'),
                        position: LatLng(model.zoneLat!, model.zoneLng!),
                      ),
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _termsStep(RiderSignupModel model) {
    return _formCard(
      title: 'Terms & Agreement',
      child: Column(
        children: [
          const SizedBox(
            height: 150,
            child: SingleChildScrollView(
              child: Text(
                'By joining Abianzo Rider, you agree to service standards, customer safety policies, payout terms, and data processing clauses for verification and operations.',
              ),
            ),
          ),
          CheckboxListTile(
            value: model.acceptedTerms,
            onChanged: (v) => ref
                .read(riderSignupProvider.notifier)
                .update(model.copyWith(acceptedTerms: v ?? false)),
            title: const Text('I agree to all terms and policies'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          TextFormField(
            initialValue: model.signature,
            decoration: _onboardingInputDecoration(
              'Digital Signature (type full name)',
            ),
            onChanged: (v) => ref
                .read(riderSignupProvider.notifier)
                .update(model.copyWith(signature: v)),
          ),
        ],
      ),
    );
  }

  Widget _reviewStep(RiderSignupModel model) {
    final progress = [
      ('Personal Details', model.fullName.isNotEmpty),
      ('Vehicle Details', model.vehicleNumber.isNotEmpty),
      ('KYC', model.aadhaar.isNotEmpty && model.pan.isNotEmpty),
      ('Bank Verification', model.accountNumber.isNotEmpty),
    ];
    return _formCard(
      title: 'Application Review',
      child: _staggerColumn([
        ...progress.map((e) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0x33FFFFFF)),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: e.$2
                        ? Colors.green.withValues(alpha: 0.18)
                        : const Color(0xFFD4AF37).withValues(alpha: 0.16),
                  ),
                  child: Icon(
                    e.$2 ? Icons.check_rounded : Icons.pending_outlined,
                    color: e.$2
                        ? const Color(0xFF30D158)
                        : const Color(0xFFF5D76E),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(e.$1)),
                Text(
                  e.$2 ? 'Completed' : 'Pending',
                  style: TextStyle(
                    color: e.$2
                        ? const Color(0xFF30D158)
                        : const Color(0xFFF5D76E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: progress.where((p) => p.$2).length / progress.length,
          color: const Color(0xFFD4AF37),
        ),
      ]),
    );
  }

  Widget _staggerColumn(List<Widget> children) {
    return Column(
      children: List<Widget>.generate(children.length, (index) {
        return children[index]
            .animate()
            .fadeIn(
              delay: Duration(milliseconds: 40 * index),
              duration: 260.ms,
              curve: Curves.easeOutCubic,
            )
            .slideY(begin: 0.04, end: 0, duration: 300.ms);
      }),
    );
  }

  Widget _formCard({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: RiderGlassCard(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 21,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'All details are encrypted and reviewed for rider safety and payout accuracy.',
                style: TextStyle(
                  color: Color.fromRGBO(255, 255, 255, 0.76),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              _stepVisualBanner(),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.08, end: 0);
  }

  Widget _stepVisualBanner() {
    final accent = _stepAccentColor();
    final icon = _stepIllustrationIcon();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.22), const Color(0xFF0D0D0D)],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 48,
              height: 48,
              color: Colors.white.withValues(alpha: 0.92),
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                'assets/branding/abzora_rider_icon.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _stepVisualLine(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE5E5E5),
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.26),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
        ],
      ),
    );
  }

  IconData _stepIllustrationIcon() {
    switch (_step) {
      case 0:
        return Icons.sms_outlined;
      case 1:
        return Icons.verified_user_outlined;
      case 2:
        return Icons.badge_outlined;
      case 3:
        return Icons.two_wheeler_outlined;
      case 4:
        return Icons.fact_check_outlined;
      case 5:
        return Icons.account_balance_outlined;
      case 6:
        return Icons.route_outlined;
      case 7:
        return Icons.gavel_outlined;
      case 8:
        return Icons.task_alt_outlined;
      default:
        return Icons.local_shipping_outlined;
    }
  }

  Color _stepAccentColor() {
    switch (_step) {
      case 0:
        return const Color(0xFFF5D76E);
      case 1:
        return const Color(0xFF7EDB8F);
      case 2:
        return const Color(0xFF69D7FF);
      case 3:
        return const Color(0xFFFFB36A);
      case 4:
        return const Color(0xFF9CD37E);
      case 5:
        return const Color(0xFF8CB7FF);
      case 6:
        return const Color(0xFFFFD26A);
      case 7:
        return const Color(0xFFCDA8FF);
      case 8:
        return const Color(0xFF7EE3BA);
      default:
        return const Color(0xFFF5D76E);
    }
  }

  String _stepVisualLine() {
    switch (_step) {
      case 0:
        return 'Secure OTP verification protects your rider account from day one.';
      case 1:
        return 'Instant code confirmation unlocks the next onboarding stage.';
      case 2:
        return 'A complete profile improves trust and approval turnaround.';
      case 3:
        return 'Vehicle details help route matching and delivery assignment quality.';
      case 4:
        return 'KYC checks run through encrypted verification workflows.';
      case 5:
        return 'Payout setup ensures smooth weekly settlement transfers.';
      case 6:
        return 'Delivery preferences tune jobs to your shift and service radius.';
      case 7:
        return 'Policy acceptance keeps rider, customer, and platform standards aligned.';
      case 8:
        return 'Final review confirms every critical step before submission.';
      default:
        return 'Complete your onboarding to start earning as an Abianzo rider.';
    }
  }

  Widget _stepIndicatorChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        'Step ${_step + 1}/9',
        style: const TextStyle(
          color: Color(0xFFF5D76E),
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _uploadRow(
    String label,
    String? path,
    void Function(String) onPicked,
  ) {
    final uploaded = path != null && path.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0x33FFFFFF)),
        color: Colors.white.withValues(alpha: 0.03),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          _statusPill(uploaded),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _pickFile(onPicked),
            child: Text(uploaded ? 'Replace' : 'Upload'),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(bool complete) {
    final bg = complete
        ? const Color(0xFF30D158).withValues(alpha: 0.15)
        : const Color(0xFFF5D76E).withValues(alpha: 0.15);
    final fg = complete ? const Color(0xFF30D158) : const Color(0xFFF5D76E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        complete ? 'Uploaded' : 'Pending',
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  InputDecoration _onboardingInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.3),
      ),
    );
  }
}

class RiderSuccessScreen extends StatefulWidget {
  const RiderSuccessScreen({super.key});

  @override
  State<RiderSuccessScreen> createState() => _RiderSuccessScreenState();
}

class _RiderSuccessScreenState extends State<RiderSuccessScreen> {
  late final ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 2))
      ..play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final riderId =
        'RDR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go(RiderRoutes.dashboard);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Container(color: const Color(0xFF050505)),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _controller,
                blastDirectionality: BlastDirectionality.explosive,
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: RiderGlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: Colors.greenAccent,
                        size: 66,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Application Submitted',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Rider ID: $riderId'),
                      const SizedBox(height: 8),
                      const Text(
                        'Estimated approval: within 24-48 hours',
                        style: TextStyle(
                          color: Color.fromRGBO(255, 255, 255, 0.78),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.tips_and_updates_outlined),
                        title: Text(
                          'Accept high-demand time slots for higher earnings',
                        ),
                      ),
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.tips_and_updates_outlined),
                        title: Text(
                          'Keep documents updated for faster activation',
                        ),
                      ),
                      const SizedBox(height: 8),
                      RiderGlowButton(
                        label: 'Go To Dashboard',
                        onPressed: () => context.go(RiderRoutes.dashboard),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
