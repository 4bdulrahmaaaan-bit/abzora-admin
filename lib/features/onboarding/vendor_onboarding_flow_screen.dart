import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/rider_glass_card.dart';
import '../../core/widgets/rider_glow_button.dart';
import '../../core/widgets/rider_particle_background.dart';
import '../../core/utils/vendor_kyc_policy.dart';
import '../../core/services/vendor_telemetry.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/state_views.dart';

class VendorOnboardingFlowScreen extends StatefulWidget {
  const VendorOnboardingFlowScreen({super.key});

  @override
  State<VendorOnboardingFlowScreen> createState() =>
      _VendorOnboardingFlowScreenState();
}

class _VendorOnboardingFlowScreenState
    extends State<VendorOnboardingFlowScreen> {
  final _pageController = PageController();
  final _onboarding = OnboardingService();
  final _db = DatabaseService();
  final _location = LocationService();
  final _picker = ImagePicker();
  int _step = 0;
  bool _submitting = false;
  bool _autoValidate = false;
  int _invalidSubmitTick = 0;

  final _storeName = TextEditingController();
  final _ownerName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _experienceYears = TextEditingController();
  final _startingPrice = TextEditingController();
  final _upperPrice = TextEditingController();
  final _productionDays = TextEditingController(text: '7');
  final _payout = TextEditingController();

  final Set<String> _specializations = <String>{};
  XFile? _ownerPhoto;
  XFile? _storePhoto;
  XFile? _aadhaarPhoto;
  XFile? _panPhoto;
  final List<String> _portfolioPaths = <String>[];

  static const _goldPrimary = Color(0xFFD4AF37);
  static const _goldAccent = Color(0xFFF5D76E);

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _ownerName.text = user.name;
      _phone.text = user.phone ?? '';
      _email.text = user.email;
      _address.text = user.address ?? '';
      _city.text = user.city ?? '';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _storeName.dispose();
    _ownerName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _city.dispose();
    _experienceYears.dispose();
    _startingPrice.dispose();
    _upperPrice.dispose();
    _productionDays.dispose();
    _payout.dispose();
    super.dispose();
  }

  Future<void> _pickImage(void Function(XFile) onPicked) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (file == null || !mounted) return;
    setState(() => onPicked(file));
  }

  Future<void> _pickPortfolio() async {
    final files = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (files == null) return;
    setState(() {
      for (final f in files.files) {
        final path = f.path;
        if (path != null && _portfolioPaths.length < 10) {
          _portfolioPaths.add(path);
        }
      }
    });
  }

  String? _validateStep() {
    if (_step == 0) {
      if (_storeName.text.trim().isEmpty) return 'Store name is required';
      if (_ownerName.text.trim().isEmpty) return 'Owner name is required';
      if (_phone.text.trim().length < 10) return 'Valid phone is required';
      final email = _email.text.trim();
      if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
        return 'Valid email is required';
      }
      if (_address.text.trim().isEmpty) return 'Address is required';
      if (_city.text.trim().isEmpty) return 'City is required';
    }
    if (_step == 1 && _specializations.isEmpty) {
      return 'Choose at least one specialization';
    }
    if (_step == 2 && _portfolioPaths.length < 5) {
      return 'Upload at least 5 portfolio samples';
    }
    if (_step == 3) {
      final start = double.tryParse(_startingPrice.text.trim()) ?? 0;
      final upper = double.tryParse(_upperPrice.text.trim()) ?? 0;
      final days = int.tryParse(_productionDays.text.trim()) ?? 0;
      if (start <= 0) {
        return 'Starting price must be greater than zero';
      }
      if (upper < start) {
        return 'Upper range must be greater than starting price';
      }
      if (days <= 0 || days > 60) {
        return 'Production days must be between 1 and 60';
      }
    }
    if (_step == 4 &&
        (_ownerPhoto == null ||
            _storePhoto == null ||
            _aadhaarPhoto == null ||
            _panPhoto == null)) {
      return 'Owner, store, Aadhaar and PAN images are required';
    }
    return null;
  }

  void _next() {
    final error = _validateStep();
    if (error != null) {
      HapticFeedback.heavyImpact();
      setState(() {
        _autoValidate = true;
        _invalidSubmitTick++;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (_step < 5) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step == 0) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacementNamed('/ops');
      }
      return;
    }
    setState(() => _step--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      VendorTelemetry.event('submit_started', data: {'userId': user.id});
      final ownerPhotoUrl = await _onboarding.uploadVendorOwnerPhoto(
        file: _ownerPhoto!,
        ownerId: user.id,
      );
      final storePhotoUrl = await _onboarding.uploadVendorStoreImage(
        file: _storePhoto!,
        ownerId: user.id,
      );
      final aadhaarUrl = await _onboarding.uploadVendorDocument(
        file: _aadhaarPhoto!,
        ownerId: user.id,
        label: 'aadhaar',
      );
      final panUrl = await _onboarding.uploadVendorDocument(
        file: _panPhoto!,
        ownerId: user.id,
        label: 'pan',
      );

      Map<String, dynamic> aadhaarOcr = const <String, dynamic>{};
      Map<String, dynamic> panOcr = const <String, dynamic>{};
      Map<String, dynamic> vendorVerification = const <String, dynamic>{};
      try {
        aadhaarOcr = await _onboarding.extractKycFields(
          documentType: 'aadhaar',
          text:
              '${_ownerName.text.trim()} ${_phone.text.trim()} ${_address.text.trim()}',
          documentUrl: aadhaarUrl,
        );
        panOcr = await _onboarding.extractKycFields(
          documentType: 'pan',
          text: '${_ownerName.text.trim()} ${_email.text.trim()}',
          documentUrl: panUrl,
        );
        vendorVerification = await _onboarding.verifyVendorKyc(
          ownerName: _ownerName.text.trim(),
          aadhaarNumber: (aadhaarOcr['aadhaarNumber'] ?? '').toString(),
          panNumber: (panOcr['panNumber'] ?? '').toString(),
          ownerPhotoUrl: ownerPhotoUrl,
          storePhotoUrl: storePhotoUrl,
        );
      } catch (error) {
        VendorTelemetry.event(
          'vendor_ocr_extract_failed',
          data: {'error': error.toString()},
        );
      }

      if (VendorKycPolicy.requiresManualReview(vendorVerification)) {
        final confidence = VendorKycPolicy.confidenceFromVerification(
          vendorVerification,
        );
        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'KYC confidence is low (${confidence.toStringAsFixed(0)}%). Please re-upload clearer Aadhaar and PAN documents.',
              ),
            ),
          );
        }
        return;
      }

      final portfolioUrls = <String>[];
      for (var i = 0; i < _portfolioPaths.length; i++) {
        final url = await _onboarding.uploadVendorDocument(
          file: XFile(_portfolioPaths[i]),
          ownerId: user.id,
          label: 'portfolio-$i',
        );
        portfolioUrls.add(url);
      }

      final nowIso = DateTime.now().toIso8601String();
      var latitude = user.latitude;
      var longitude = user.longitude;
      if (latitude == null || longitude == null) {
        final geo = await _location.geocodeAddress(_address.text.trim());
        if (geo.status == AddressLookupStatus.success &&
            geo.latitude != null &&
            geo.longitude != null) {
          latitude = geo.latitude;
          longitude = geo.longitude;
        }
      }

      await _onboarding.submitVendorRequest(
        actor: user,
        request: VendorKycRequest(
          id: 'vendor-${user.id}',
          userId: user.id,
          storeName: _storeName.text.trim(),
          ownerName: _ownerName.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          address: _address.text.trim(),
          city: _city.text.trim(),
          latitude: latitude ?? 0,
          longitude: longitude ?? 0,
          vendorType: 'custom_vendor',
          experienceYears: int.tryParse(_experienceYears.text.trim()) ?? 0,
          specializations: _specializations.toList(),
          portfolioImageUrls: portfolioUrls,
          startingPrice: double.tryParse(_startingPrice.text.trim()) ?? 0,
          typicalPriceUpper: double.tryParse(_upperPrice.text.trim()) ?? 0,
          productionTimeDays: int.tryParse(_productionDays.text.trim()) ?? 7,
          payoutSetupLabel: _payout.text.trim(),
          kyc: KycDocuments(
            ownerPhotoUrl: ownerPhotoUrl,
            storeImageUrl: storePhotoUrl,
            aadhaarUrl: aadhaarUrl,
            panUrl: panUrl,
          ),
          metadata: {
            'submittedAt': nowIso,
            'source': 'vendor_flow_v2',
            'experienceYears': int.tryParse(_experienceYears.text.trim()) ?? 0,
            'specializations': _specializations.toList(),
            'startingPrice': double.tryParse(_startingPrice.text.trim()) ?? 0,
            'typicalPriceUpper': double.tryParse(_upperPrice.text.trim()) ?? 0,
            'productionTimeDays':
                int.tryParse(_productionDays.text.trim()) ?? 7,
            'ocrAadhaar': aadhaarOcr,
            'ocrPan': panOcr,
            'verification': vendorVerification,
            'ocrCapturedAt': nowIso,
          },
          createdAt: nowIso,
          updatedAt: nowIso,
        ),
      );

      if (_payout.text.trim().isNotEmpty) {
        final value = _payout.text.trim();
        if (!value.contains('@') && value.length < 8) {
          throw StateError('Enter a valid UPI ID or bank account number');
        }
        try {
          await _db.saveVendorPayoutProfile(
            actor: user,
            methodType: value.contains('@') ? 'upi' : 'bank',
            accountHolderName: _ownerName.text.trim(),
            upiId: value.contains('@') ? value : '',
            bankAccountNumber: value.contains('@') ? '' : value,
            bankIfsc: '',
            bankName: '',
          );
        } catch (error) {
          VendorTelemetry.event(
            'payout_save_failed_post_submit',
            data: {'error': error.toString()},
          );
        }
      }
      await auth.refreshCurrentUser();
      VendorTelemetry.event('submit_success', data: {'userId': user.id});
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const _VendorOnboardingSuccessScreen(),
        ),
      );
    } catch (error) {
      VendorTelemetry.event('submit_failed', data: {'error': error.toString()});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Scaffold(
        body: AbzioLoadingView(
          title: 'Opening vendor onboarding',
          subtitle: 'Preparing your partner application.',
        ),
      );
    }
    final canContinue = _validateStep() == null;
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: _back,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Back',
        ),
        title: Text('Vendor Onboarding ${_step + 1}/6'),
      ),
      body: Stack(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 2400),
            builder: (context, value, _) =>
                RiderParticleBackground(progress: value),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: RiderGlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'Step ${_step + 1} of 6',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(((_step + 1) / 6) * 100).round()}%',
                            style: const TextStyle(
                              color: _goldAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: (_step + 1) / 6,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation(
                            _goldPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _card('Business Basics', [
                      _field(_storeName, 'Store Name', hint: 'Abzora Tailors'),
                      _field(_ownerName, 'Owner Name', hint: 'A. Rahman'),
                      _field(
                        _phone,
                        'Phone',
                        hint: '9876543210',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                      _field(
                        _email,
                        'Email',
                        hint: 'owner@store.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      _field(
                        _address,
                        'Address',
                        hint: 'Street, area, landmark',
                        maxLines: 2,
                      ),
                      _field(_city, 'City', hint: 'Bengaluru'),
                    ]),
                    _card('Craft & Expertise', [
                      _field(
                        _experienceYears,
                        'Experience (years)',
                        hint: '5',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['Shirts', 'Blazers', 'Dresses', 'Ethnic']
                            .map(
                              (item) => FilterChip(
                                label: Text(item),
                                selected: _specializations.contains(item),
                                selectedColor: _goldPrimary.withValues(
                                  alpha: 0.24,
                                ),
                                checkmarkColor: _goldAccent,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _specializations.add(item);
                                    } else {
                                      _specializations.remove(item);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ]),
                    _card('Portfolio Uploads', [
                      Text(
                        'Uploaded: ${_portfolioPaths.length}/10',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _pickPortfolio,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _goldPrimary.withValues(alpha: 0.45),
                          ),
                        ),
                        child: const Text('Add Portfolio Files'),
                      ),
                    ]),
                    _card('Pricing & Capacity', [
                      _field(
                        _startingPrice,
                        'Starting Price (Rs)',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      _field(
                        _upperPrice,
                        'Typical Upper Range (Rs)',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      _field(
                        _productionDays,
                        'Production Days',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      _field(
                        _payout,
                        'UPI or Bank Account Number',
                        hint: 'rahman@upi',
                      ),
                    ]),
                    _card('KYC Documents', [
                      _uploadTile(
                        'Owner Photo',
                        _ownerPhoto != null,
                        () => _pickImage((x) => _ownerPhoto = x),
                      ),
                      _uploadTile(
                        'Store Photo',
                        _storePhoto != null,
                        () => _pickImage((x) => _storePhoto = x),
                      ),
                      _uploadTile(
                        'Aadhaar',
                        _aadhaarPhoto != null,
                        () => _pickImage((x) => _aadhaarPhoto = x),
                      ),
                      _uploadTile(
                        'PAN',
                        _panPhoto != null,
                        () => _pickImage((x) => _panPhoto = x),
                      ),
                    ]),
                    _card('Review & Submit', [
                      Text('Store: ${_storeName.text.trim()}'),
                      Text('City: ${_city.text.trim()}'),
                      Text('Specializations: ${_specializations.join(', ')}'),
                      Text('Portfolio: ${_portfolioPaths.length} files'),
                      const SizedBox(height: 10),
                      const Text(
                        'Your application will be reviewed after document checks.',
                      ),
                    ]),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  transform: Matrix4.translationValues(
                    _invalidSubmitTick.isOdd ? 6 : 0,
                    0,
                    0,
                  ),
                  child: AnimatedOpacity(
                    opacity: (_submitting || canContinue) ? 1 : 0.7,
                    duration: const Duration(milliseconds: 180),
                    child: RiderGlowButton(
                      label: _step == 5
                          ? (_submitting
                                ? 'Submitting...'
                                : 'Submit Application')
                          : 'Continue',
                      onPressed: _submitting
                          ? null
                          : (canContinue ? _next : null),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RiderGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    String hint = '',
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint.isEmpty ? null : hint,
          filled: true,
          fillColor: const Color(0xFF101010),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _goldPrimary, width: 1.4),
          ),
        ),
        onChanged: (_) {
          if (_autoValidate) {
            setState(() {});
          }
        },
      ),
    );
  }

  Widget _uploadTile(String label, bool done, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        done ? Icons.check_circle_rounded : Icons.upload_file_rounded,
        color: done ? const Color(0xFF30D158) : _goldAccent,
      ),
      title: Text(label),
      subtitle: Text(done ? 'Uploaded' : 'Not uploaded'),
      trailing: TextButton(onPressed: onTap, child: const Text('Upload')),
    );
  }
}

class _VendorOnboardingSuccessScreen extends StatelessWidget {
  const _VendorOnboardingSuccessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, color: Colors.green, size: 64),
              const SizedBox(height: 12),
              const Text(
                'Vendor Application Submitted',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'We will notify you after KYC and quality review.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/ops', (route) => false),
                child: const Text('Go to Vendor Workspace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
