import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/utils/vendor_kyc_policy.dart';
import '../../core/services/vendor_telemetry.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/state_views.dart';

class VendorOnboardingFlowScreen extends StatefulWidget {
  final int initialStep;
  const VendorOnboardingFlowScreen({super.key, this.initialStep = 0});

  @override
  State<VendorOnboardingFlowScreen> createState() =>
      _VendorOnboardingFlowScreenState();
}

class _VendorOnboardingFlowScreenState
    extends State<VendorOnboardingFlowScreen> {
  late final PageController _pageController;
  final _onboarding = OnboardingService();
  final _db = DatabaseService();
  final _location = LocationService();
  final _picker = ImagePicker();
  late int _step;
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

  final _monthlyCapacity = TextEditingController();
  final _bankAccount = TextEditingController();
  final _ifsc = TextEditingController();
  final _upi = TextEditingController();

  final Set<String> _specializations = <String>{};
  XFile? _ownerPhoto;
  XFile? _storePhoto;
  XFile? _aadhaarPhoto;
  XFile? _panPhoto;
  final List<String> _portfolioPaths = <String>[];

  bool _isProcessingKyc = false;
  bool _kycProcessed = false;
  Map<String, dynamic> _aadhaarOcr = {};
  Map<String, dynamic> _panOcr = {};
  Map<String, dynamic> _vendorVerification = {};
  double _kycConfidence = 0.0;
  String? _aadhaarUrl;
  String? _panUrl;
  String? _ownerPhotoUrl;
  String? _storePhotoUrl;

  final List<String> _specializationOptions = [
    'Shirts',
    'T-Shirts',
    'Jeans',
    'Blazers',
    'Ethnic',
    "Women's Fashion",
    'Kids Wear',
    'Custom Tailoring',
  ];

  static const _bgDark = Color(0xFF0A0A0A);
  static const _cardDark = Color(0xFF141414);

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    int initial = widget.initialStep;
    if (user != null && user.vendorOnboarding != null) {
      final lastStep = user.vendorOnboarding!['lastCompletedStep'];
      if (lastStep != null && lastStep is num) {
        initial = lastStep.toInt();
      }
    }
    _step = initial;
    _pageController = PageController(initialPage: _step);
    if (user != null) {
      _ownerName.text = user.name;
      _phone.text = user.phone ?? '';
      _email.text = user.email;
      _address.text = user.address ?? '';
      _city.text = 'Chennai';
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
    _monthlyCapacity.dispose();
    _bankAccount.dispose();
    _ifsc.dispose();
    _upi.dispose();
    super.dispose();
  }

  Future<void> _pickImage(void Function(XFile) onPicked) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (file == null || !mounted) return;
    setState(() {
      onPicked(file);
      _kycProcessed = false;
    });
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

  void _removePortfolio(int index) {
    setState(() {
      _portfolioPaths.removeAt(index);
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
    if (_step == 2 &&
        (_portfolioPaths.length < 5 || _portfolioPaths.length > 10)) {
      return 'Upload between 5 and 10 portfolio samples';
    }
    if (_step == 3) {
      final start = double.tryParse(_startingPrice.text.trim()) ?? 0;
      final upper = double.tryParse(_upperPrice.text.trim()) ?? 0;
      final days = int.tryParse(_productionDays.text.trim()) ?? 0;
      final capacity = int.tryParse(_monthlyCapacity.text.trim()) ?? 0;
      if (start <= 0) return 'Starting price must be greater than zero';
      if (upper < start) {
        return 'Upper range must be greater than starting price';
      }
      if (days <= 0 || days > 60) {
        return 'Production days must be between 1 and 60';
      }
      if (capacity <= 0) return 'Monthly capacity must be greater than zero';

      if (_bankAccount.text.trim().isEmpty && _upi.text.trim().isEmpty) {
        return 'Provide at least a Bank Account or UPI ID';
      }
      if (_bankAccount.text.trim().isNotEmpty && _ifsc.text.trim().isEmpty) {
        return 'IFSC is required for Bank Account';
      }
    }
    if (_step == 4) {
      if (_ownerPhoto == null ||
          _storePhoto == null ||
          _aadhaarPhoto == null ||
          _panPhoto == null) {
        return 'Owner, store, Aadhaar and PAN images are required';
      }
    }
    return null;
  }

  Future<void> _processKycDocs() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() {
      _isProcessingKyc = true;
    });

    try {
      _ownerPhotoUrl = await _onboarding.uploadVendorOwnerPhoto(
        file: _ownerPhoto!,
        ownerId: user.id,
      );
      _storePhotoUrl = await _onboarding.uploadVendorStoreImage(
        file: _storePhoto!,
        ownerId: user.id,
      );
      _aadhaarUrl = await _onboarding.uploadVendorDocument(
        file: _aadhaarPhoto!,
        ownerId: user.id,
        label: 'aadhaar',
      );
      _panUrl = await _onboarding.uploadVendorDocument(
        file: _panPhoto!,
        ownerId: user.id,
        label: 'pan',
      );

      try {
        _aadhaarOcr = await _onboarding.extractKycFields(
          documentType: 'aadhaar',
          text:
              '${_ownerName.text.trim()} ${_phone.text.trim()} ${_address.text.trim()}',
          documentUrl: _aadhaarUrl!,
        );
        _panOcr = await _onboarding.extractKycFields(
          documentType: 'pan',
          text: '${_ownerName.text.trim()} ${_email.text.trim()}',
          documentUrl: _panUrl!,
        );
        _vendorVerification = await _onboarding.verifyVendorKyc(
          ownerName: _ownerName.text.trim(),
          aadhaarNumber: (_aadhaarOcr['aadhaarNumber'] ?? '').toString(),
          panNumber: (_panOcr['panNumber'] ?? '').toString(),
          ownerPhotoUrl: _ownerPhotoUrl!,
          storePhotoUrl: _storePhotoUrl!,
        );

        _kycConfidence = VendorKycPolicy.confidenceFromVerification(
          _vendorVerification,
        );
      } catch (e) {
        VendorTelemetry.event(
          'vendor_ocr_extract_failed',
          data: {'error': e.toString()},
        );
        _kycConfidence = 0.0;
      }

      _kycProcessed = true;

      if (!mounted) return;
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('KYC Processing Failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingKyc = false;
        });
      }
    }
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

    if (_step == 4 && !_kycProcessed) {
      _processKycDocs();
      return;
    }

    if (_step < 5) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        _db.saveVendorOnboardingStep(user.id, _step);
      }
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

  void _jumpToStep(int step) {
    setState(() => _step = step);
    _pageController.jumpToPage(step);
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    if (VendorKycPolicy.requiresManualReview(_vendorVerification)) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'KYC confidence is low (${_kycConfidence.toStringAsFixed(0)}%). Please re-upload clearer documents.',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      VendorTelemetry.event('submit_started', data: {'userId': user.id});

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
          payoutSetupLabel: _upi.text.trim().isNotEmpty
              ? _upi.text.trim()
              : _bankAccount.text.trim(),
          kyc: KycDocuments(
            ownerPhotoUrl: _ownerPhotoUrl ?? '',
            storeImageUrl: _storePhotoUrl ?? '',
            aadhaarUrl: _aadhaarUrl ?? '',
            panUrl: _panUrl ?? '',
          ),
          metadata: {
            'submittedAt': nowIso,
            'source': 'vendor_flow_v3',
            'experienceYears': int.tryParse(_experienceYears.text.trim()) ?? 0,
            'specializations': _specializations.toList(),
            'startingPrice': double.tryParse(_startingPrice.text.trim()) ?? 0,
            'typicalPriceUpper': double.tryParse(_upperPrice.text.trim()) ?? 0,
            'productionTimeDays':
                int.tryParse(_productionDays.text.trim()) ?? 7,
            'monthlyCapacity': int.tryParse(_monthlyCapacity.text.trim()) ?? 0,
            'payoutDetails': {
              'bankAccount': _bankAccount.text.trim(),
              'ifsc': _ifsc.text.trim(),
              'upi': _upi.text.trim(),
            },
            'ocrAadhaar': _aadhaarOcr,
            'ocrPan': _panOcr,
            'verification': _vendorVerification,
            'ocrCapturedAt': nowIso,
          },
          createdAt: nowIso,
          updatedAt: nowIso,
        ),
      );

      if (_bankAccount.text.isNotEmpty || _upi.text.isNotEmpty) {
        try {
          await _db.saveVendorPayoutProfile(
            actor: user,
            methodType: _upi.text.trim().isNotEmpty ? 'upi' : 'bank',
            accountHolderName: _ownerName.text.trim(),
            upiId: _upi.text.trim(),
            bankAccountNumber: _bankAccount.text.trim(),
            bankIfsc: _ifsc.text.trim(),
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
        backgroundColor: _bgDark,
        body: AbzioLoadingView(
          title: 'Opening vendor onboarding',
          subtitle: 'Preparing your partner application.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        leading: IconButton(
          onPressed: _submitting || _isProcessingKyc ? null : _back,
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          tooltip: 'Back',
        ),
        title: Text(
          'Step ${_step + 1} of 6',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  value: (_step + 1) / 6,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _card('Business Basics', [
                    _field(_storeName, 'Store Name', hint: 'Abianzo Tailors'),
                    _field(
                      _ownerName,
                      'Owner Name',
                      hint: 'A. Rahman',
                      readOnly: true,
                    ),
                    _field(_phone, 'Phone', hint: '9876543210', readOnly: true),
                    _field(
                      _email,
                      'Email',
                      hint: 'owner@store.com',
                      readOnly: true,
                    ),
                    _field(
                      _address,
                      'Address',
                      hint: 'Street, area, landmark',
                      maxLines: 2,
                    ),
                    _field(_city, 'City', hint: 'Chennai', readOnly: true),
                  ]),
                  _card('Craft & Expertise', [
                    _field(
                      _experienceYears,
                      'Experience (years)',
                      hint: '5',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Specializations',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _specializationOptions.map((item) {
                        final selected = _specializations.contains(item);
                        return ChoiceChip(
                          label: Text(item),
                          selected: selected,
                          selectedColor: Colors.white,
                          backgroundColor: Colors.transparent,
                          labelStyle: TextStyle(
                            color: selected ? Colors.black : Colors.white70,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: selected ? Colors.white : Colors.white24,
                            ),
                          ),
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _specializations.add(item);
                              } else {
                                _specializations.remove(item);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ]),
                  _card('Portfolio Uploads', [
                    Text(
                      'Uploaded: ${_portfolioPaths.length}/10 (Min 5 required)',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_portfolioPaths.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: _portfolioPaths.asMap().entries.map((e) {
                            final index = e.key;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              title: Text(
                                'Sample Image ${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (index > 0)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.keyboard_arrow_up,
                                        color: Colors.white70,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          final item = _portfolioPaths.removeAt(
                                            index,
                                          );
                                          _portfolioPaths.insert(
                                            index - 1,
                                            item,
                                          );
                                        });
                                      },
                                    ),
                                  if (index < _portfolioPaths.length - 1)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Colors.white70,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          final item = _portfolioPaths.removeAt(
                                            index,
                                          );
                                          _portfolioPaths.insert(
                                            index + 1,
                                            item,
                                          );
                                        });
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () => _removePortfolio(index),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (_portfolioPaths.length < 10)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _pickPortfolio,
                          icon: const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Add Portfolio Files',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                  ]),
                  _card('Pricing & Capacity', [
                    _field(
                      _startingPrice,
                      'Starting Price (Rs)',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    _field(
                      _upperPrice,
                      'Typical Upper Range (Rs)',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    _field(
                      _productionDays,
                      'Production Days',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    _field(
                      _monthlyCapacity,
                      'Monthly Capacity',
                      hint: 'Number of items per month',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Payout Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      _bankAccount,
                      'Bank Account Number',
                      hint: '1234567890',
                    ),
                    _field(_ifsc, 'IFSC Code', hint: 'HDFC0001234'),
                    _field(_upi, 'UPI ID', hint: 'user@upi'),
                  ]),
                  _card('KYC Documents', [
                    const Text(
                      'Please upload clear photos. These will be verified instantly using our OCR system.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
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
                      'Aadhaar Card',
                      _aadhaarPhoto != null,
                      () => _pickImage((x) => _aadhaarPhoto = x),
                    ),
                    _uploadTile(
                      'PAN Card',
                      _panPhoto != null,
                      () => _pickImage((x) => _panPhoto = x),
                    ),
                  ]),
                  _card('Review & Submit', [
                    _reviewRow(
                      'Store Name',
                      _storeName.text.trim(),
                      () => _jumpToStep(0),
                    ),
                    _reviewRow(
                      'Owner Name',
                      _ownerName.text.trim(),
                      () => _jumpToStep(0),
                    ),
                    _reviewRow(
                      'Specializations',
                      _specializations.join(', '),
                      () => _jumpToStep(1),
                    ),
                    _reviewRow(
                      'Portfolio',
                      '${_portfolioPaths.length} files',
                      () => _jumpToStep(2),
                    ),
                    _reviewRow(
                      'Capacity',
                      '${_monthlyCapacity.text.trim()} items/mo',
                      () => _jumpToStep(3),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: Colors.white12),
                    ),
                    const Text(
                      'KYC Verification Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _reviewRow(
                      'Confidence Score',
                      '${_kycConfidence.toStringAsFixed(1)}%',
                      () => _jumpToStep(4),
                    ),
                    _reviewRow(
                      'Aadhaar',
                      _aadhaarOcr['aadhaarNumber']?.toString() ?? 'Failed',
                      () => _jumpToStep(4),
                    ),
                    _reviewRow(
                      'PAN',
                      _panOcr['panNumber']?.toString() ?? 'Failed',
                      () => _jumpToStep(4),
                    ),
                    if (_kycConfidence <
                        VendorKycPolicy.minConfidenceForAutoSubmit)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Low confidence score. Please retry document upload for faster approval.',
                                      style: TextStyle(
                                        color: Colors.redAccent.shade100,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => _jumpToStep(4),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Retry Document Upload',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                transform: Matrix4.translationValues(
                  _invalidSubmitTick.isOdd ? 6 : 0,
                  0,
                  0,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white30,
                      disabledForegroundColor: Colors.black54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _submitting || _isProcessingKyc ? null : _next,
                    child: _isProcessingKyc
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            _step == 5
                                ? (_submitting
                                      ? 'Submitting...'
                                      : 'Submit Application')
                                : (_step == 4
                                      ? 'Verify Documents'
                                      : 'Continue'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
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
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        readOnly: readOnly,
        style: TextStyle(
          color: readOnly ? Colors.white54 : Colors.white,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60),
          hintText: hint.isEmpty ? null : hint,
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: readOnly
              ? Colors.white.withValues(alpha: 0.02)
              : Colors.black26,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white, width: 1.5),
          ),
        ),
        onChanged: (_) {
          if (_autoValidate) setState(() {});
        },
      ),
    );
  }

  Widget _uploadTile(String label, bool done, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: done
                    ? Colors.green.withValues(alpha: 0.4)
                    : Colors.white12,
              ),
              borderRadius: BorderRadius.circular(8),
              color: done
                  ? Colors.green.withValues(alpha: 0.05)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(
                  done ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                  color: done ? Colors.green : Colors.white54,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        done ? 'Uploaded successfully' : 'Tap to upload',
                        style: TextStyle(
                          color: done ? Colors.green : Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!done)
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white24,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reviewRow(String label, String value, VoidCallback onEdit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorOnboardingSuccessScreen extends StatelessWidget {
  const _VendorOnboardingSuccessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Colors.green,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Application Submitted',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'We are reviewing your details. You will be notified once the process is complete.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/ops', (route) => false),
                  child: const Text(
                    'Go to Dashboard',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
