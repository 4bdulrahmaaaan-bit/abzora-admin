import 'dart:async';
import 'dart:ui' as ui;

import '../../core/vendor/theme/vendor_theme.dart';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../core/utils/vendor_kyc_policy.dart';
import '../../utils/app_error_text.dart';
import '../../core/services/vendor_telemetry.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/state_views.dart';

import '../../services/vendor_onboarding_api.dart';
import '../../services/vendor_onboarding_local_cache.dart';
import '../../services/vendor_onboarding_sync_service.dart';
import '../../services/backend_api_client.dart';
import 'models/vendor_onboarding_draft.dart';
import 'widgets/welcome_screen.dart';
import 'widgets/enterprise_progress_tracker.dart';
import 'widgets/draft_save_badge.dart';
import 'widgets/business_profile_step.dart';
import 'widgets/expertise_step.dart';
import 'widgets/portfolio_studio_step.dart';
import 'widgets/operations_finance_step.dart';
import 'widgets/compliance_step.dart';
import 'widgets/launch_readiness_step.dart';
import 'widgets/vendor_onboarding_success_screen.dart';

class VendorOnboardingFlowScreen extends StatefulWidget {
  final int initialStep;
  const VendorOnboardingFlowScreen({super.key, this.initialStep = 0});

  @override
  State<VendorOnboardingFlowScreen> createState() => _VendorOnboardingFlowScreenState();
}

class _VendorOnboardingFlowScreenState extends State<VendorOnboardingFlowScreen>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  final _onboarding = OnboardingService();
  final _db = DatabaseService();
  final _api = const VendorOnboardingApi();
  final _cache = VendorOnboardingLocalCache();
  late final VendorOnboardingSyncService _syncService;
  final VendorOnboardingDraft _draft = VendorOnboardingDraft();
  
  final _picker = ImagePicker();
  
  Timer? _autoSaveTimer;
  late int _step;
  bool _submitting = false;
  bool _autoValidate = false;
  int _invalidSubmitTick = 0;
  DateTime? _lastSaved;
  SyncStatus _syncStatus = SyncStatus.cloudSynced;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final user = context.read<AuthProvider>().user;
    int initial = widget.initialStep;
    if (user != null && user.vendorOnboarding != null) {
      final lastStep = user.vendorOnboarding!['lastCompletedStep'];
      if (lastStep != null && lastStep is num) {
        initial = lastStep.toInt();
      }
    }
    _step = initial;
    _pageController = PageController(initialPage: _step >= 0 ? _step : 0);
    
    _restoreDraft(user);

    _syncService = VendorOnboardingSyncService(
      api: _api, 
      cache: _cache,
      onSyncComplete: () {
        if (mounted) {
          setState(() {
            _syncStatus = SyncStatus.cloudSynced;
            _lastSaved = DateTime.now();
          });
        }
      },
    );
    _syncService.start();

    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _saveDraft();
    });
  }

  Future<void> _restoreDraft(AppUser? user) async {
    if (user == null) return;
    
    _draft.ownerName.text = user.name;
    _draft.phone.text = user.phone ?? '';
    _draft.email.text = user.email;
    _draft.address.text = user.address ?? '';
    _draft.city.text = 'Chennai';

    Map<String, dynamic>? draft;
    Map<String, dynamic>? cachedDraft;
    try {
      draft = await _api.getDraft();
    } catch (e) {
      debugPrint('[RESTORE_STRATEGY] MongoDB unavailable, loading Hive backup...');
    }
    
    cachedDraft = await _cache.getDraft(user.id);
    final localDraft = _draftFromCachedRecord(cachedDraft);
    if (_shouldPreferLocalVendorDraft(cachedDraft, draft)) {
      draft = localDraft ?? draft;
      final cachedDraftSnapshot = cachedDraft;
      if (mounted && cachedDraftSnapshot != null) {
        setState(() {
          _syncStatus = cachedDraftSnapshot['isPendingSync'] == true
              ? SyncStatus.pendingSync
              : SyncStatus.cloudSynced;
        });
      }
    }
    
    if (draft == null) {
      draft = await _db.getVendorOnboardingDraft(user.id);
      if (draft != null) {
        // Safe migration
        draft['draftStatus'] = 'migrated';
        try {
          await _api.saveDraft(draft);
        } catch (e) {
          await _cache.saveDraft(user.id, draft, draft['currentStep'] ?? 0);
        }
        await _db.deleteVendorOnboardingDraft(user.id);
      }
    }

    if (draft != null && mounted) {
      final safeDraft = draft;
      setState(() {
        _step = safeDraft['currentStep'] ?? _step;
        if (_step >= 0 && _pageController.hasClients) {
          _pageController.jumpToPage(_step);
        }
        
        // Business Profile
        if (safeDraft['business'] != null) {
          final biz = safeDraft['business'];
          _draft.storeName.text = biz['storeName'] ?? '';
          _draft.businessType = biz['businessType'] ?? 'Individual Seller';
          _draft.gstNumber.text = biz['gstNumber'] ?? '';
          _draft.address.text = biz['address'] ?? _draft.address.text;
          _draft.city.text = biz['city'] ?? _draft.city.text;
          _draft.latitude = biz['latitude'];
          _draft.longitude = biz['longitude'];
        } else {
          // Fallback to flat map for old RTDB schema
          _draft.storeName.text = safeDraft['storeName'] ?? '';
          _draft.businessType = safeDraft['businessType'] ?? 'Individual Seller';
          _draft.gstNumber.text = safeDraft['gstNumber'] ?? '';
          _draft.address.text = safeDraft['address'] ?? _draft.address.text;
          _draft.city.text = safeDraft['city'] ?? _draft.city.text;
          _draft.latitude = safeDraft['latitude'];
          _draft.longitude = safeDraft['longitude'];
        }
        
        // Expertise
        if (safeDraft['expertise'] != null) {
          final exp = safeDraft['expertise'];
          _draft.experienceYears.text = (exp['experienceYears'] ?? '').toString();
          if (exp['specializations'] != null) {
            _draft.specializations.clear();
            _draft.specializations.addAll(List<String>.from(exp['specializations']));
          }
          if (exp['serviceTypes'] != null) {
            _draft.serviceTypes.clear();
            _draft.serviceTypes.addAll(List<String>.from(exp['serviceTypes']));
          }
          if (exp['tags'] != null) {
            _draft.storeTags.clear();
            _draft.storeTags.addAll(List<String>.from(exp['tags']));
          }
        } else {
          // RTDB Fallback
          _draft.experienceYears.text = (safeDraft['experienceYears'] ?? '').toString();
          if (safeDraft['specializations'] != null) {
            _draft.specializations.clear();
            _draft.specializations.addAll(List<String>.from(safeDraft['specializations']));
          }
          if (safeDraft['serviceTypes'] != null) {
            _draft.serviceTypes.clear();
            _draft.serviceTypes.addAll(List<String>.from(safeDraft['serviceTypes']));
          }
          if (safeDraft['storeTags'] != null) {
            _draft.storeTags.clear();
            _draft.storeTags.addAll(List<String>.from(safeDraft['storeTags']));
          }
        }

        // Portfolio
        if (safeDraft['portfolio'] != null) {
          final port = safeDraft['portfolio'];
          if (port['portfolioImages'] != null) {
            _draft.portfolioPaths.clear();
            _draft.portfolioPaths.addAll(List<String>.from(port['portfolioImages']));
          }
          _draft.primaryPortfolioIndex = port['coverImage'] ?? 0;
        } else {
          // RTDB Fallback
          if (safeDraft['portfolioPaths'] != null) {
            _draft.portfolioPaths.clear();
            _draft.portfolioPaths.addAll(List<String>.from(safeDraft['portfolioPaths']));
          }
          _draft.primaryPortfolioIndex = safeDraft['primaryPortfolioIndex'] ?? 0;
        }

        // Finance
        if (safeDraft['finance'] != null) {
          final fin = safeDraft['finance'];
          _draft.startingPrice.text = (fin['startingPrice'] ?? '').toString();
          _draft.upperPrice.text = (fin['upperRange'] ?? '').toString();
          _draft.productionDays.text = (fin['productionDays'] ?? '7').toString();
          _draft.monthlyCapacity.text = (fin['monthlyCapacity'] ?? '').toString();
          _draft.bankAccount.text = fin['bankAccount'] ?? '';
          _draft.confirmBankAccount.text = fin['bankAccount'] ?? '';
          _draft.ifsc.text = fin['ifscCode'] ?? '';
          _draft.upi.text = fin['upiId'] ?? '';
          _draft.settlementPreference = fin['settlementPreference'] ?? 'Weekly';
          _draft.preferredPaymentMethod = fin['preferredPaymentMethod'] ?? 'Bank Transfer';
        } else {
          // RTDB fallback
          _draft.startingPrice.text = (safeDraft['startingPrice'] ?? '').toString();
          _draft.upperPrice.text = (safeDraft['upperPrice'] ?? '').toString();
          _draft.productionDays.text = (safeDraft['productionDays'] ?? '7').toString();
          _draft.monthlyCapacity.text = (safeDraft['monthlyCapacity'] ?? '').toString();
          _draft.bankAccount.text = safeDraft['bankAccount'] ?? '';
          _draft.confirmBankAccount.text = safeDraft['confirmBankAccount'] ?? '';
          _draft.ifsc.text = safeDraft['ifsc'] ?? '';
          _draft.upi.text = safeDraft['upi'] ?? '';
          _draft.settlementPreference = safeDraft['settlementPreference'] ?? 'Weekly';
          _draft.preferredPaymentMethod = safeDraft['preferredPaymentMethod'] ?? 'Bank Transfer';
        }

        // KYC & OCR
        if (safeDraft['kyc'] != null) {
          final kyc = safeDraft['kyc'];
          _draft.ownerPhotoUrl = kyc['ownerPhotoUrl'];
          _draft.storePhotoUrl = kyc['storePhotoUrl'];
          _draft.aadhaarUrl = kyc['aadhaarUrl'];
          _draft.panUrl = kyc['panUrl'];
          _draft.kycConfidence = (kyc['kycConfidence'] ?? 0).toDouble();
          _draft.kycProcessed = kyc['kycProcessed'] ?? false;
        } else {
          _draft.ownerPhotoUrl = safeDraft['ownerPhotoUrl'];
          _draft.storePhotoUrl = safeDraft['storePhotoUrl'];
          _draft.aadhaarUrl = safeDraft['aadhaarUrl'];
          _draft.panUrl = safeDraft['panUrl'];
          _draft.kycProcessed = safeDraft['kycProcessed'] ?? false;
        }

        if (safeDraft['ocr'] != null) {
          final ocr = safeDraft['ocr'];
          if (ocr['aadhaarOcr'] != null) _draft.aadhaarOcr = Map<String, dynamic>.from(ocr['aadhaarOcr']);
          if (ocr['panOcr'] != null) _draft.panOcr = Map<String, dynamic>.from(ocr['panOcr']);
          if (ocr['verification'] != null) {
             _draft.vendorVerification = Map<String, dynamic>.from(ocr['verification']);
             if (safeDraft['kyc'] == null) {
               _draft.kycConfidence = VendorKycPolicy.confidenceFromVerification(_draft.vendorVerification);
             }
          }
        } else {
          if (safeDraft['ocrAadhaar'] != null) _draft.aadhaarOcr = Map<String, dynamic>.from(safeDraft['ocrAadhaar']);
          if (safeDraft['ocrPan'] != null) _draft.panOcr = Map<String, dynamic>.from(safeDraft['ocrPan']);
          if (safeDraft['verification'] != null) {
             _draft.vendorVerification = Map<String, dynamic>.from(safeDraft['verification']);
             _draft.kycConfidence = VendorKycPolicy.confidenceFromVerification(_draft.vendorVerification);
          }
        }

        if (safeDraft['lastSavedAt'] != null) {
          _lastSaved = DateTime.tryParse(safeDraft['lastSavedAt']);
        }
      });
    }
  }

  Map<String, dynamic>? _draftFromCachedRecord(Map<String, dynamic>? cachedRecord) {
    final payload = cachedRecord?['draftPayload'];
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    return null;
  }

  DateTime? _draftTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  bool _shouldPreferLocalVendorDraft(
    Map<String, dynamic>? cachedRecord,
    Map<String, dynamic>? cloudDraft,
  ) {
    final localDraft = _draftFromCachedRecord(cachedRecord);
    if (localDraft == null) {
      return false;
    }
    final cached = cachedRecord;
    if (cached == null) {
      return true;
    }
    final cloud = cloudDraft;
    if (cloud == null) {
      return true;
    }

    final localUpdatedAt = _draftTimestamp(
      cached['lastUpdatedAt'] ?? cached['lastSavedAt'],
    );
    final cloudUpdatedAt = _draftTimestamp(
      cloud['lastSavedAt'] ?? cloud['updatedAt'],
    );

    if (cached['isPendingSync'] == true) {
      if (cloudUpdatedAt == null || localUpdatedAt == null) {
        return true;
      }
      return !cloudUpdatedAt.isAfter(localUpdatedAt);
    }

    if (localUpdatedAt == null && cloudUpdatedAt == null) {
      return true;
    }
    if (localUpdatedAt == null) {
      return false;
    }
    if (cloudUpdatedAt == null) {
      return true;
    }
    return localUpdatedAt.isAfter(cloudUpdatedAt);
  }

  void _saveDraft() async {
    final user = context.read<AuthProvider>().user;
    if (user == null || _submitting) return;

    if (mounted) {
      setState(() {
        _syncStatus = SyncStatus.saving;
      });
    }

    final data = {
      'userId': user.id,
      'currentStep': _step,
      'draftStatus': 'draft',
      'version': 1,
      'business': {
        'storeName': _draft.storeName.text.trim(),
        'businessType': _draft.businessType,
        'gstNumber': _draft.gstNumber.text.trim(),
        'address': _draft.address.text.trim(),
        'city': _draft.city.text.trim(),
        'latitude': _draft.latitude,
        'longitude': _draft.longitude,
      },
      'expertise': {
        'experienceYears': _draft.experienceYears.text.trim(),
        'specializations': _draft.specializations.toList(),
        'serviceTypes': _draft.serviceTypes.toList(),
        'tags': _draft.storeTags.toList(),
      },
      'portfolio': {
        'portfolioImages': _draft.portfolioPaths,
        'coverImage': _draft.primaryPortfolioIndex,
      },
      'finance': {
        'startingPrice': _draft.startingPrice.text.trim(),
        'upperRange': _draft.upperPrice.text.trim(),
        'productionDays': _draft.productionDays.text.trim(),
        'monthlyCapacity': _draft.monthlyCapacity.text.trim(),
        'bankAccount': _draft.bankAccount.text.trim(),
        'ifscCode': _draft.ifsc.text.trim(),
        'upiId': _draft.upi.text.trim(),
        'settlementPreference': _draft.settlementPreference,
        'preferredPaymentMethod': _draft.preferredPaymentMethod,
      },
      'kyc': {
        'ownerPhotoUrl': _draft.ownerPhotoUrl,
        'storePhotoUrl': _draft.storePhotoUrl,
        'aadhaarUrl': _draft.aadhaarUrl,
        'panUrl': _draft.panUrl,
        'kycConfidence': _draft.kycConfidence,
        'kycProcessed': _draft.kycProcessed,
      },
      'ocr': {
        'aadhaarOcr': _draft.aadhaarOcr,
        'panOcr': _draft.panOcr,
        'verification': _draft.vendorVerification,
      }
    };

    try {
      await _cache.saveDraft(user.id, data, _step);
      if (mounted) {
        setState(() {
          _syncStatus = SyncStatus.syncing;
        });
      }
      await _api.saveDraft(data);
      await _cache.markSynced(user.id);
      if (mounted) {
        setState(() {
          _lastSaved = DateTime.now();
          _syncStatus = SyncStatus.cloudSynced;
        });
      }
    } catch (e) {
      await _cache.markSyncFailed(user.id);
      if (mounted) {
        setState(() {
          _lastSaved = DateTime.now();
          _syncStatus = SyncStatus.pendingSync;
        });
      }
      if (e is BackendApiException && e.isNetworkIssue) {
        _syncService.syncPendingDrafts(); // Try syncing immediately in background
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection temporarily unavailable. Your progress has been saved locally and will sync automatically.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        debugPrint('[ONBOARDING_DRAFT_SAVE_FAILED] Unexpected error: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncService.stop();
    _autoSaveTimer?.cancel();
    if (_step >= 0) _pageController.dispose();
    _draft.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveDraft();
    }
  }

  Future<void> _detectLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')));
      return;
    }

    try {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Detecting location...')));
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _draft.latitude = position.latitude;
      _draft.longitude = position.longitude;

      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _draft.city.text = place.locality ?? place.subAdministrativeArea ?? '';
          final addressParts = [
            place.street,
            place.subLocality,
            place.locality,
            place.postalCode
          ].where((p) => p != null && p.isNotEmpty).join(', ');
          _draft.address.text = addressParts;
        });
      }
      _saveDraft();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error detecting location: $e')));
    }
  }

  Future<void> _pickImage(String uploadType, void Function(XFile file, String url) onPicked) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
    if (file == null || !mounted) return;
    
    setState(() => _submitting = true);
    
    try {
      final fileName = '$uploadType-${DateTime.now().millisecondsSinceEpoch}-${file.name}';
      final url = await _onboarding.uploadDraftKycImage(file: file, ownerId: user.id, fileName: fileName);
      
      setState(() {
        onPicked(file, url);
        _draft.kycProcessed = false;
        _saveDraft();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorText.from(e))),
        );
      }
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _pickPortfolio() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    
    final files = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
    if (files.isEmpty) return;
    
    setState(() => _submitting = true);

    for (final f in files) {
      if (_draft.portfolioPaths.length >= 10) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can upload a maximum of 10 portfolio samples.')));
        break;
      }
      
      try {
        final bytes = await f.readAsBytes();
        final fileSize = bytes.length;
        
        final sizeMb = fileSize / (1024 * 1024);
        final extension = f.name.contains('.') ? f.name.substring(f.name.lastIndexOf('.')).toLowerCase() : '';
        debugPrint('[PORTFOLIO_UPLOAD] name=${f.name} extension=$extension size=${sizeMb.toStringAsFixed(2)}MB status=started');

        if (fileSize > 10 * 1024 * 1024) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image size exceeds 10 MB.')));
          continue;
        }

        if (!['.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'].contains(extension)) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image format not supported. Use JPG, PNG, WEBP, HEIC, or HEIF.')));
          continue;
        }

        bool resolutionOk = true;
        try {
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          debugPrint('[PORTFOLIO_UPLOAD] dimensions=${frame.image.width}x${frame.image.height}');
          if (frame.image.width < 500 || frame.image.height < 500) {
            resolutionOk = false;
          }
        } catch (_) {
          // ignore decoder failure and try to let backend handle it
        }
        
        if (!resolutionOk) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image resolution is too low.')));
          continue;
        }

        String? uploadedUrl;
        int maxAttempts = 3;
        
        for (int attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            debugPrint('[PORTFOLIO_UPLOAD] attempt=$attempt status=uploading');
            uploadedUrl = await _onboarding.uploadDraftPortfolioImage(
              file: f,
              ownerId: user.id,
              fileName: 'portfolio-${DateTime.now().millisecondsSinceEpoch}-${f.name}',
            );
            debugPrint('[PORTFOLIO_UPLOAD] attempt=$attempt status=success url=$uploadedUrl');
            break; // Success
          } catch (e) {
            debugPrint('[PORTFOLIO_UPLOAD] attempt=$attempt status=error error=$e');
            if (attempt == maxAttempts) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppErrorText.from(e))),
                );
              }
            } else {
              await Future.delayed(Duration(seconds: 1 * attempt)); // Exponential backoff
            }
          }
        }

        if (uploadedUrl != null) {
          setState(() {
            _draft.portfolioPaths.add(uploadedUrl!);
            _saveDraft();
          });
        }
      } catch (e) {
        debugPrint('[PORTFOLIO_UPLOAD] name=${f.name} status=fatal_error error=$e');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to process this image. Please select a different image.')));
      }
    }
    
    setState(() => _submitting = false);
  }

  void _removePortfolio(int index) {
    setState(() {
      _draft.portfolioPaths.removeAt(index);
      if (_draft.primaryPortfolioIndex == index) {
         _draft.primaryPortfolioIndex = 0;
      } else if (_draft.primaryPortfolioIndex > index) {
         _draft.primaryPortfolioIndex--;
      }
      _saveDraft();
    });
  }

  void _setCoverPortfolio(int index) {
    setState(() {
      _draft.primaryPortfolioIndex = index;
      _saveDraft();
    });
  }

  void _reorderPortfolio(int oldIndex, int newIndex) {
    setState(() {
      final String item = _draft.portfolioPaths.removeAt(oldIndex);
      _draft.portfolioPaths.insert(newIndex, item);
      
      // Update primary index tracking
      if (_draft.primaryPortfolioIndex == oldIndex) {
        _draft.primaryPortfolioIndex = newIndex;
      } else if (oldIndex < _draft.primaryPortfolioIndex && newIndex >= _draft.primaryPortfolioIndex) {
        _draft.primaryPortfolioIndex--;
      } else if (oldIndex > _draft.primaryPortfolioIndex && newIndex <= _draft.primaryPortfolioIndex) {
        _draft.primaryPortfolioIndex++;
      }
      _saveDraft();
    });
  }

  String? _validateStep() {
    if (_step == 0) {
      if (_draft.storeName.text.trim().isEmpty) return 'Store name is required';
      if (_draft.ownerName.text.trim().isEmpty) return 'Owner name is required';
      if (_draft.phone.text.trim().length < 10) return 'Valid phone is required';
      final email = _draft.email.text.trim();
      if (email.isEmpty || !email.contains('@') || !email.contains('.')) return 'Valid email is required';
      if (_draft.address.text.trim().isEmpty) return 'Address is required';
      if (_draft.city.text.trim().isEmpty) return 'City is required';
      if (_draft.latitude == null || _draft.longitude == null) return 'Please detect your location via GPS';
    }
    if (_step == 1 && _draft.specializations.isEmpty) {
      return 'Choose at least one specialization';
    }
    if (_step == 2 && _draft.portfolioPaths.length > 10) {
      return 'You can upload a maximum of 10 portfolio samples';
    }
    if (_step == 3) {
      final start = double.tryParse(_draft.startingPrice.text.trim()) ?? 0;
      final upper = double.tryParse(_draft.upperPrice.text.trim()) ?? 0;
      final days = int.tryParse(_draft.productionDays.text.trim()) ?? 0;
      final capacity = int.tryParse(_draft.monthlyCapacity.text.trim()) ?? 0;
      if (start <= 0) return 'Starting price must be greater than zero';
      if (upper < start) return 'Upper range must be greater than starting price';
      if (days <= 0 || days > 60) return 'Production days must be between 1 and 60';
      if (capacity <= 0) return 'Monthly capacity must be greater than zero';

      if (_draft.preferredPaymentMethod == 'Bank Transfer') {
        if (_draft.bankAccount.text.trim().isEmpty) return 'Bank Account Number is required';
        if (_draft.ifsc.text.trim().isEmpty) return 'IFSC Code is required';
        if (_draft.bankAccount.text.trim() != _draft.confirmBankAccount.text.trim()) return 'Bank Account numbers do not match';
      } else {
        if (_draft.upi.text.trim().isEmpty) return 'UPI ID is required for UPI method';
      }
    }
    if (_step == 4) {
      if (_draft.ownerPhotoUrl == null || _draft.storePhotoUrl == null || _draft.aadhaarUrl == null || _draft.panUrl == null) {
        return 'Owner, store, Aadhaar and PAN images are required';
      }
      if (!_draft.kycProcessed) return 'Please wait for KYC verification to complete';
    }
    if (_step == 5) {
      if (!_draft.agreedToTruth) return 'You must certify the information is accurate';
      if (!_draft.agreedToTerms) return 'You must agree to the Terms and Conditions';
    }
    return null;
  }

  Future<void> _processKycDocs() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() => _draft.isProcessingKyc = true);

    try {
      _draft.aadhaarOcr = await _onboarding.extractKycFields(
        documentType: 'aadhaar',
        text: '${_draft.ownerName.text.trim()} ${_draft.phone.text.trim()} ${_draft.address.text.trim()}',
        documentUrl: _draft.aadhaarUrl!,
      );
      _draft.panOcr = await _onboarding.extractKycFields(
        documentType: 'pan',
        text: '${_draft.ownerName.text.trim()} ${_draft.email.text.trim()}',
        documentUrl: _draft.panUrl!,
      );
      _draft.vendorVerification = await _onboarding.verifyVendorKyc(
        ownerName: _draft.ownerName.text.trim(),
        aadhaarNumber: (_draft.aadhaarOcr['aadhaarNumber'] ?? '').toString(),
        panNumber: (_draft.panOcr['panNumber'] ?? '').toString(),
        ownerPhotoUrl: _draft.ownerPhotoUrl!,
        storePhotoUrl: _draft.storePhotoUrl!,
      );

      _draft.kycConfidence = VendorKycPolicy.confidenceFromVerification(_draft.vendorVerification);
    } catch (e) {
      VendorTelemetry.event('vendor_ocr_extract_failed', data: {'error': e.toString()});
      _draft.kycConfidence = 0.0;
    }

    if (!mounted) return;
    
    final aadhaarExtracted = _draft.aadhaarOcr['aadhaarNumber']?.toString() ?? 'Failed';
    final panExtracted = _draft.panOcr['panNumber']?.toString() ?? 'Failed';
    final aadhaarName = _draft.aadhaarOcr['ownerName']?.toString() ?? _draft.aadhaarOcr['name']?.toString() ?? 'Unknown';
    final panName = _draft.panOcr['ownerName']?.toString() ?? _draft.panOcr['name']?.toString() ?? 'Unknown';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Confirm KYC Details', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please verify the extracted information matches your documents.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            Text('Aadhaar: $aadhaarExtracted', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Name: $aadhaarName', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            Text('PAN: $panExtracted', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Name: $panName', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            Text('Confidence Score: ${_draft.kycConfidence.toStringAsFixed(1)}%', style: TextStyle(color: _draft.kycConfidence > 70 ? Colors.green : Colors.orangeAccent)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Re-upload', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm & Continue'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _draft.kycProcessed = true;
      _saveDraft();
      _nextStep();
    }
    if (mounted) setState(() => _draft.isProcessingKyc = false);
  }

  void _nextStep() {
    setState(() => _step++);
    if (_step == 0) {
      _pageController = PageController(initialPage: 0);
    } else {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  void _next() {
    if (_step < 0) {
      _nextStep();
      return;
    }

    final error = _validateStep();
    if (error != null) {
      HapticFeedback.heavyImpact();
      setState(() {
        _autoValidate = true;
        _invalidSubmitTick++;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    if (_step == 4 && !_draft.kycProcessed) {
      _processKycDocs();
      return;
    }

    if (_step < 5) {
      _saveDraft();
      _nextStep();
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step <= 0) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacementNamed('/ops');
      }
      return;
    }
    _saveDraft();
    setState(() => _step--);
    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  void _jumpToStep(int step) {
    setState(() => _step = step);
    _pageController.jumpToPage(step);
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    if (VendorKycPolicy.requiresManualReview(_draft.vendorVerification)) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Low KYC Confidence', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('The OCR system could not verify your documents with high confidence (${_draft.kycConfidence.toStringAsFixed(0)}%).', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                if (_draft.vendorVerification['reason'] != null)
                  Text('Reason: ${_draft.vendorVerification['reason']}', style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit Anyway', style: TextStyle(color: Colors.white38)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                onPressed: () {
                  Navigator.pop(context, false);
                  _jumpToStep(4);
                },
                child: const Text('Re-upload Documents'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      } else {
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      VendorTelemetry.event('submit_started', data: {'userId': user.id});

      final portfolioUrls = List<String>.from(_draft.portfolioPaths);
      final nowIso = DateTime.now().toIso8601String();
      final latitude = _draft.latitude ?? user.latitude ?? 0.0;
      final longitude = _draft.longitude ?? user.longitude ?? 0.0;

      await _onboarding.submitVendorRequest(
        actor: user,
        request: VendorKycRequest(
          id: 'vendor-${user.id}',
          userId: user.id,
          storeName: _draft.storeName.text.trim(),
          ownerName: _draft.ownerName.text.trim(),
          phone: _draft.phone.text.trim(),
          email: _draft.email.text.trim(),
          address: _draft.address.text.trim(),
          city: _draft.city.text.trim(),
          latitude: latitude,
          longitude: longitude,
          vendorType: 'custom_vendor',
          experienceYears: int.tryParse(_draft.experienceYears.text.trim()) ?? 0,
          specializations: _draft.specializations.toList(),
          portfolioImageUrls: portfolioUrls,
          startingPrice: double.tryParse(_draft.startingPrice.text.trim()) ?? 0,
          typicalPriceUpper: double.tryParse(_draft.upperPrice.text.trim()) ?? 0,
          productionTimeDays: int.tryParse(_draft.productionDays.text.trim()) ?? 7,
          payoutSetupLabel: _draft.preferredPaymentMethod == 'UPI' ? _draft.upi.text.trim() : _draft.bankAccount.text.trim(),
          kyc: KycDocuments(
            ownerPhotoUrl: _draft.ownerPhotoUrl ?? '',
            storeImageUrl: _draft.storePhotoUrl ?? '',
            aadhaarUrl: _draft.aadhaarUrl ?? '',
            panUrl: _draft.panUrl ?? '',
          ),
          metadata: {
            'submittedAt': nowIso,
            'source': 'vendor_flow_v4',
            'businessType': _draft.businessType,
            'gstNumber': _draft.gstNumber.text.trim(),
            'serviceTypes': _draft.serviceTypes.toList(),
            'storeTags': _draft.storeTags.toList(),
            'primaryPortfolioIndex': _draft.primaryPortfolioIndex,
            'experienceYears': int.tryParse(_draft.experienceYears.text.trim()) ?? 0,
            'specializations': _draft.specializations.toList(),
            'startingPrice': double.tryParse(_draft.startingPrice.text.trim()) ?? 0,
            'typicalPriceUpper': double.tryParse(_draft.upperPrice.text.trim()) ?? 0,
            'productionTimeDays': int.tryParse(_draft.productionDays.text.trim()) ?? 7,
            'monthlyCapacity': int.tryParse(_draft.monthlyCapacity.text.trim()) ?? 0,
            'settlementPreference': _draft.settlementPreference,
            'preferredPaymentMethod': _draft.preferredPaymentMethod,
            'payoutDetails': {
              'bankAccount': _draft.bankAccount.text.trim(),
              'ifsc': _draft.ifsc.text.trim(),
              'upi': _draft.upi.text.trim(),
            },
            'ocrAadhaar': _draft.aadhaarOcr,
            'ocrPan': _draft.panOcr,
            'verification': _draft.vendorVerification,
            'ocrCapturedAt': nowIso,
            'gpsLocation': {
              'latitude': latitude,
              'longitude': longitude,
              'capturedAt': nowIso,
            },
          },
          createdAt: nowIso,
          updatedAt: nowIso,
        ),
      );

      if (_draft.bankAccount.text.isNotEmpty || _draft.upi.text.isNotEmpty) {
        try {
          await _db.saveVendorPayoutProfile(
            actor: user,
            methodType: _draft.preferredPaymentMethod == 'UPI' ? 'upi' : 'bank',
            accountHolderName: _draft.ownerName.text.trim(),
            upiId: _draft.upi.text.trim(),
            bankAccountNumber: _draft.bankAccount.text.trim(),
            bankIfsc: _draft.ifsc.text.trim(),
            bankName: '',
          );
        } catch (error) {
          VendorTelemetry.event('payout_save_failed_post_submit', data: {'error': error.toString()});
        }
      }

      try {
        await _api.deleteDraft();
      } catch (_) {}
      await _cache.deleteDraft(user.id);

      await auth.refreshCurrentUser();
      VendorTelemetry.event('submit_success', data: {'userId': user.id});
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const VendorOnboardingSuccessScreen()),
      );
    } catch (error) {
      VendorTelemetry.event('submit_failed', data: {'error': error.toString()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return Scaffold(
        backgroundColor: VendorTheme.onboardingBackground,
        body: const AbzioLoadingView(title: 'Opening vendor onboarding', subtitle: 'Preparing your partner application.'),
      );
    }

    if (_step < 0) {
      return Scaffold(
        backgroundColor: VendorTheme.onboardingBackground,
        appBar: AppBar(
          backgroundColor: VendorTheme.onboardingBackground,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: VendorTheme.onboardingPrimaryText),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: WelcomeScreen(onStart: _next),
        ),
      );
    }

    return Scaffold(
      backgroundColor: VendorTheme.onboardingBackground,
      appBar: AppBar(
        backgroundColor: VendorTheme.onboardingBackground,
        elevation: 0,
        leading: IconButton(
          onPressed: _submitting || _draft.isProcessingKyc ? null : _back,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: VendorTheme.onboardingPrimaryText),
          tooltip: 'Back',
        ),
        title: const Text('Vendor Partner Setup', style: TextStyle(color: VendorTheme.onboardingPrimaryText, fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          DraftSaveBadge(lastSaved: _lastSaved, status: _syncStatus),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            EnterpriseProgressTracker(currentStep: _step, totalSteps: 6),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    BusinessProfileStep(
                      storeNameController: _draft.storeName,
                      ownerNameController: _draft.ownerName,
                      phoneController: _draft.phone,
                      emailController: _draft.email,
                      gstNumberController: _draft.gstNumber,
                      businessType: _draft.businessType,
                      onBusinessTypeChanged: (val) {
                        if (val != null) {
                          setState(() => _draft.businessType = val);
                          _saveDraft();
                        }
                      },
                      addressController: _draft.address,
                      cityController: _draft.city,
                      hasLocation: _draft.latitude != null && _draft.longitude != null,
                      onDetectLocation: _detectLocation,
                      onChanged: () {
                        if (_autoValidate) setState(() {});
                        _saveDraft();
                      },
                    ),
                    ExpertiseStep(
                      experienceYearsController: _draft.experienceYears,
                      specializations: _draft.specializations,
                      serviceTypes: _draft.serviceTypes,
                      storeTags: _draft.storeTags,
                      onToggleSpecialization: (val) {
                        setState(() {
                          if (_draft.specializations.contains(val)) {
                            _draft.specializations.remove(val);
                          } else {
                            _draft.specializations.add(val);
                          }
                          _saveDraft();
                        });
                      },
                      onToggleServiceType: (val) {
                        setState(() {
                          if (_draft.serviceTypes.contains(val)) {
                            _draft.serviceTypes.remove(val);
                          } else {
                            _draft.serviceTypes.add(val);
                          }
                          _saveDraft();
                        });
                      },
                      onToggleStoreTag: (val) {
                        setState(() {
                          if (_draft.storeTags.contains(val)) {
                            _draft.storeTags.remove(val);
                          } else if (_draft.storeTags.length < 5) {
                            _draft.storeTags.add(val);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 5 tags allowed')));
                          }
                          _saveDraft();
                        });
                      },
                      onChanged: () {
                        if (_autoValidate) setState(() {});
                        _saveDraft();
                      },
                    ),
                    PortfolioStudioStep(
                      images: _draft.portfolioPaths,
                      primaryIndex: _draft.primaryPortfolioIndex,
                      onAddImages: _pickPortfolio,
                      onRemoveImage: _removePortfolio,
                      onSetCover: _setCoverPortfolio,
                      onReorder: _reorderPortfolio,
                    ),
                    OperationsFinanceStep(
                      startingPriceController: _draft.startingPrice,
                      upperPriceController: _draft.upperPrice,
                      productionDaysController: _draft.productionDays,
                      monthlyCapacityController: _draft.monthlyCapacity,
                      preferredPaymentMethod: _draft.preferredPaymentMethod,
                      settlementPreference: _draft.settlementPreference,
                      onPaymentMethodChanged: (val) {
                        if (val != null) setState(() => _draft.preferredPaymentMethod = val);
                      },
                      onSettlementChanged: (val) {
                        if (val != null) setState(() => _draft.settlementPreference = val);
                      },
                      bankAccountController: _draft.bankAccount,
                      confirmBankAccountController: _draft.confirmBankAccount,
                      ifscController: _draft.ifsc,
                      upiController: _draft.upi,
                      onChanged: () {
                        if (_autoValidate) setState(() {});
                        _saveDraft();
                      },
                    ),
                    ComplianceStep(
                      ownerPhotoUrl: _draft.ownerPhotoUrl,
                      ownerStatus: _getDocStatus(_draft.ownerPhotoUrl),
                      storePhotoUrl: _draft.storePhotoUrl,
                      storeStatus: _getDocStatus(_draft.storePhotoUrl),
                      aadhaarUrl: _draft.aadhaarUrl,
                      aadhaarStatus: _getDocStatus(_draft.aadhaarUrl),
                      panUrl: _draft.panUrl,
                      panStatus: _getDocStatus(_draft.panUrl),
                      onUploadOwner: () => _pickImage('owner', (x, url) => _draft.ownerPhotoUrl = url),
                      onUploadStore: () => _pickImage('store', (x, url) => _draft.storePhotoUrl = url),
                      onUploadAadhaar: () => _pickImage('aadhaar', (x, url) => _draft.aadhaarUrl = url),
                      onUploadPan: () => _pickImage('pan', (x, url) => _draft.panUrl = url),
                    ),
                    LaunchReadinessStep(
                      storeName: _draft.storeName.text.trim(),
                      ownerName: _draft.ownerName.text.trim(),
                      specializationsSummary: _draft.specializations.join(', '),
                      portfolioCount: _draft.portfolioPaths.length,
                      capacitySummary: _draft.monthlyCapacity.text.trim().isNotEmpty ? '${_draft.monthlyCapacity.text.trim()} items/mo' : '',
                      kycConfidence: _draft.kycConfidence,
                      aadhaarOcr: _draft.aadhaarOcr,
                      panOcr: _draft.panOcr,
                      kycProcessed: _draft.kycProcessed,
                      agreedToTruth: _draft.agreedToTruth,
                      agreedToTerms: _draft.agreedToTerms,
                      onAgreedToTruth: (val) {
                        setState(() => _draft.agreedToTruth = val ?? false);
                        _saveDraft();
                      },
                      onAgreedToTerms: (val) {
                        setState(() => _draft.agreedToTerms = val ?? false);
                        _saveDraft();
                      },
                      onJumpToStep: _jumpToStep,
                      onRetryKyc: () => _jumpToStep(4),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                transform: Matrix4.translationValues(_invalidSubmitTick.isOdd ? 6 : 0, 0, 0),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VendorTheme.onboardingGold,
                      foregroundColor: VendorTheme.onboardingBackground,
                      disabledBackgroundColor: VendorTheme.onboardingGold.withValues(alpha: 0.3),
                      disabledForegroundColor: VendorTheme.onboardingBackground.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _submitting || _draft.isProcessingKyc ? null : _next,
                    child: _draft.isProcessingKyc
                        ? SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: VendorTheme.onboardingBackground),
                          )
                        : Text(
                            _step == 5 ? (_submitting ? 'Submitting Application...' : 'Submit Application →') : 'Save & Continue →',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
  DocumentStatus _getDocStatus(String? url) {
    if (url == null || url.isEmpty) return DocumentStatus.required;
    if (_draft.kycProcessed) return DocumentStatus.verified;
    // Additional backend logic could set this to underReview or actionRequired,
    // but default to uploaded if we just have the file.
    return DocumentStatus.uploaded;
  }
}
