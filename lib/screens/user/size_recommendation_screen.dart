import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/backend_commerce_service.dart';
import '../../services/body_scan_service.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/tap_scale.dart';
import 'body_scan_screen.dart';

class SizeRecommendationScreen extends StatefulWidget {
  const SizeRecommendationScreen({
    super.key,
    this.product,
  });

  final Product? product;

  @override
  State<SizeRecommendationScreen> createState() =>
      _SizeRecommendationScreenState();
}

class _SizeRecommendationScreenState extends State<SizeRecommendationScreen> {
  final DatabaseService _database = DatabaseService();
  final BackendCommerceService _backendCommerce = BackendCommerceService();
  final BodyScanService _bodyScanService = const BodyScanService();
  static const String _heightStorageKey = 'size_recommendation_height_cm';
  static const String _weightStorageKey = 'size_recommendation_weight_kg';
  static const String _bodyTypeStorageKey = 'size_recommendation_body_type';
  static const String _fitPreferenceStorageKey =
      'size_recommendation_fit_preference';

  double _heightCm = 170;
  double _weightKg = 68;
  String _bodyFrame = 'regular';
  String _fitPreference = 'regular';
  MeasurementProfile? _selectedProfile;
  BodyProfile? _bodyProfile;
  List<MeasurementProfile> _profiles = const [];
  bool _isLoadingProfiles = true;
  bool _isCalculating = false;
  SizePredictionResult? _result;
  String? _recommendedVariant;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _loadLocalBodyInputs();
    await _loadProfiles();
  }

  Future<void> _loadLocalBodyInputs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _heightCm = prefs.getDouble(_heightStorageKey) ?? _heightCm;
      _weightKg = prefs.getDouble(_weightStorageKey) ?? _weightKg;
      _bodyFrame = prefs.getString(_bodyTypeStorageKey) ?? _bodyFrame;
      _fitPreference =
          prefs.getString(_fitPreferenceStorageKey) ?? _fitPreference;
    });
  }

  Future<void> _saveLocalBodyInputs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_heightStorageKey, _heightCm);
    await prefs.setDouble(_weightStorageKey, _weightKg);
    await prefs.setString(_bodyTypeStorageKey, _bodyFrame);
    await prefs.setString(_fitPreferenceStorageKey, _fitPreference);
  }

  Future<void> _loadProfiles() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingProfiles = false);
      return;
    }
    final results = await Future.wait([
      _database.getMeasurementProfiles(user.id),
      _database.getBodyProfile(user.id),
    ]);
    final profiles = results[0] as List<MeasurementProfile>;
    final bodyProfile = results[1] as BodyProfile?;
    if (!mounted) {
      return;
    }
    setState(() {
      _profiles = profiles;
      _selectedProfile = profiles.isEmpty ? null : profiles.first;
      _bodyProfile = bodyProfile;
      if (bodyProfile != null) {
        _heightCm = bodyProfile.heightCm;
        _weightKg = bodyProfile.weightKg;
        _bodyFrame = bodyProfile.bodyType;
        _fitPreference = bodyProfile.fitPreference;
      }
      _isLoadingProfiles = false;
    });
  }

  Future<void> _openBodyScan() async {
    final profile = await Navigator.push<MeasurementProfile>(
      context,
      MaterialPageRoute(builder: (_) => const BodyScanScreen()),
    );
    if (!mounted || profile == null) {
      return;
    }
    setState(() {
      _selectedProfile = profile;
      _profiles = [profile, ..._profiles.where((item) => item.id != profile.id)];
    });
  }

  String? _resolveProductFit() {
    final normalized = widget.product?.outfitType?.trim().toLowerCase() ?? '';
    if (normalized == 'slim' ||
        normalized == 'regular' ||
        normalized == 'oversized') {
      return normalized;
    }
    return null;
  }

  double _confidenceValue(dynamic value) {
    if (value is num) {
      final numeric = value.toDouble();
      final normalized = numeric > 1 ? (numeric / 100) : numeric;
      return normalized.clamp(0.0, 1.0);
    }
    switch ((value ?? '').toString().trim().toLowerCase()) {
      case 'high':
        return 0.9;
      case 'medium':
        return 0.78;
      case 'low':
        return 0.66;
      default:
        return 0.74;
    }
  }

  SizePredictionResult _mergeRecommendation(
    SizePredictionResult seed,
    Map<String, dynamic> payload,
  ) {
    final recommendedSize =
        (payload['recommendedSize'] ?? seed.shirtSize).toString().toUpperCase();
    final confidence = _confidenceValue(
      payload['confidencePercent'] ?? payload['confidence'] ?? seed.confidence,
    );
    final reasoning = (payload['reasoning'] ?? payload['reason'] ?? seed.reasoning)
        .toString()
        .trim();
    final message = (payload['message'] ?? seed.message).toString().trim();

    return SizePredictionResult(
      shirtSize: recommendedSize,
      pantSize: seed.pantSize,
      chestCm: seed.chestCm,
      waistCm: seed.waistCm,
      hipCm: seed.hipCm,
      shoulderCm: seed.shoulderCm,
      armLengthCm: seed.armLengthCm,
      inseamCm: seed.inseamCm,
      sleeveCm: seed.sleeveCm,
      lengthCm: seed.lengthCm,
      fit: seed.fit,
      confidence: confidence,
      message: message.isEmpty
          ? 'Best fit based on your body profile'
          : message,
      reasoning: reasoning,
      bodyOutlineHighlights: [
        'We suggest size $recommendedSize',
        '${(confidence * 100).round()}% match with your body profile',
        'Confidence ${confidence >= 0.86 ? 'High' : confidence >= 0.72 ? 'Medium' : 'Low'} based on height, weight, and body type',
        ...seed.bodyOutlineHighlights,
      ],
    );
  }

  Future<void> _calculate() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final productFit = _resolveProductFit();
    setState(() => _isCalculating = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    late final SizePredictionResult result;
    if (_selectedProfile != null) {
      result = SizePredictionResult(
        shirtSize:
            _selectedProfile!.recommendedSize ??
            _sizeFromChest(_selectedProfile!.chest),
        pantSize: _pantSizeFromWaist(_selectedProfile!.waist),
        chestCm: _selectedProfile!.chest,
        waistCm: _selectedProfile!.waist,
        hipCm: _selectedProfile!.waist + 8,
        shoulderCm: _selectedProfile!.shoulder,
        armLengthCm: (_heightCm * 0.36),
        inseamCm: (_heightCm * 0.46),
        sleeveCm: _selectedProfile!.sleeve,
        lengthCm: _selectedProfile!.length,
        fit: 'Regular',
        confidence: 0.92,
        message: 'Best fit based on your saved measurements',
        reasoning:
            'Using your saved body scan profile for a more accurate recommendation',
        bodyOutlineHighlights: [
          'Using your saved profile ${_selectedProfile!.label}',
          'Chest and waist are already measured for a stronger fit match',
        ],
      );
    } else {
      final seed = _bodyScanService.analyze(
        BodyScanInput(
          heightCm: _heightCm,
          weightKg: _weightKg,
          bodyFrame: _bodyFrame,
          fitPreference: _fitPreference,
        ),
        productFit: productFit,
      );
      if (_backendCommerce.isConfigured) {
        try {
          final response = await _backendCommerce.recommendSize(
            heightCm: _heightCm,
            weightKg: _weightKg,
            bodyType: _bodyFrame,
            fitPreference: _fitPreference,
            productFit: productFit,
            shoulderCm: seed.shoulderCm,
            chestCm: seed.chestCm,
            waistCm: seed.waistCm,
            hipCm: seed.hipCm,
            armLengthCm: seed.armLengthCm,
            inseamCm: seed.inseamCm,
            availableSizes: widget.product?.sizes,
            sizeChart: widget.product?.attributes,
          );
          final payload = response['data'] is Map
              ? Map<String, dynamic>.from(response['data'] as Map)
              : response;
          result = _mergeRecommendation(seed, payload);
        } catch (_) {
          result = seed;
        }
      } else {
        result = seed;
      }
    }

    final variant = widget.product == null
        ? null
        : _bodyScanService.chooseBestProductSize(widget.product!, result);

    if (user != null) {
      final bodyProfile = BodyProfile(
        heightCm: _heightCm,
        weightKg: _weightKg,
        bodyType: _bodyFrame,
        recommendedSize: result.shirtSize,
        pantSize: result.pantSize,
        fitPreference: _fitPreference,
        shoulderCm: result.shoulderCm,
        chestCm: result.chestCm,
        waistCm: result.waistCm,
        hipCm: result.hipCm,
        armLengthCm: result.armLengthCm,
        inseamCm: result.inseamCm,
        confidence: result.confidence,
        scanSource: _selectedProfile != null ? 'saved_profile' : 'manual',
        scanFrameCount: _selectedProfile != null ? 30 : 0,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _database.saveBodyProfile(user.id, bodyProfile);
      _bodyProfile = bodyProfile;
    }
    await _saveLocalBodyInputs();

    if (!mounted) {
      return;
    }
    setState(() {
      _result = result;
      _recommendedVariant = variant;
      _isCalculating = false;
    });
  }

  String _sizeFromChest(double chest) {
    if (chest < 88) return 'XS';
    if (chest < 95) return 'S';
    if (chest < 102) return 'M';
    if (chest < 110) return 'L';
    if (chest < 118) return 'XL';
    return 'XXL';
  }

  String _pantSizeFromWaist(double waist) {
    if (waist < 73) return '28';
    if (waist < 78) return '30';
    if (waist < 84) return '32';
    if (waist < 90) return '34';
    if (waist < 96) return '36';
    return '38';
  }

  void _useRecommendation() {
    if (_result == null) {
      return;
    }
    Navigator.pop(
      context,
      SizeRecommendationOutcome(
        measurementProfile: _selectedProfile,
        recommendedSize: _recommendedVariant ?? _result!.shirtSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDFC),
        appBar: AppBar(title: const Text('Find My Perfect Size')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heroCard(),
                if (widget.product != null) ...[
                  const SizedBox(height: 14),
                  _productCard(widget.product!),
                ],
                const SizedBox(height: 20),
                _profilePickerCard(),
                const SizedBox(height: 16),
                _manualFallbackCard(),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: TapScale(
                    onTap: _isCalculating ? null : _calculate,
                    child: ElevatedButton.icon(
                      onPressed: _isCalculating ? null : _calculate,
                      icon: _isCalculating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          _isCalculating
                              ? 'Finding your best fit...'
                              : 'Get recommendation',
                          key: ValueKey(_isCalculating),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AbzioTheme.accentColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 22),
                  _resultCard(_result!),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _useRecommendation,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Use this recommendation'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF8E6),
            Colors.white,
          ],
        ),
        border: Border.all(
          color: AbzioTheme.accentColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal size prediction',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use your saved body profile or a quick manual fallback to get a stronger size recommendation before you order.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.abzioSecondaryText,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(Product product) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.abzioBorder.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5DA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.checkroom_rounded,
              color: AbzioTheme.accentColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  product.sizes.isEmpty
                      ? 'No sizes listed yet'
                      : 'Available sizes: ${product.sizes.join(', ')}',
                  style: TextStyle(color: context.abzioSecondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profilePickerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.abzioBorder.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saved body profile',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (_bodyProfile != null) ...[
            const SizedBox(height: 6),
            Text(
              'Last saved: ${_bodyProfile!.recommendedSize} top, ${_bodyProfile!.pantSize.isEmpty ? 'tailored trouser fit' : '${_bodyProfile!.pantSize} trousers'}',
              style: TextStyle(color: context.abzioSecondaryText),
            ),
          ],
          const SizedBox(height: 10),
          if (_isLoadingProfiles)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(),
            )
          else if (_profiles.isEmpty)
            Text(
              'No saved scan yet. Create one with camera for a stronger fit recommendation.',
              style: TextStyle(color: context.abzioSecondaryText, height: 1.45),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _selectedProfile?.id,
              items: _profiles
                  .map(
                    (profile) => DropdownMenuItem<String>(
                      value: profile.id,
                      child: Text(profile.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProfile =
                      _profiles.firstWhere((item) => item.id == value);
                });
              },
              decoration: const InputDecoration(
                labelText: 'Measurement profile',
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openBodyScan,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Scan with camera'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _manualFallbackCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.abzioBorder.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manual fallback',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'If you skip the camera, we can still estimate a reliable fit from your body frame, height, and weight.',
            style: TextStyle(color: context.abzioSecondaryText, height: 1.45),
          ),
          const SizedBox(height: 14),
          _metricSlider(
            label: 'Height',
            value: _heightCm,
            min: 145,
            max: 205,
            suffix: 'cm',
            onChanged: (value) => setState(() => _heightCm = value),
          ),
          _metricSlider(
            label: 'Weight',
            value: _weightKg,
            min: 40,
            max: 130,
            suffix: 'kg',
            onChanged: (value) => setState(() => _weightKg = value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ['slim', 'regular', 'heavy']
                .map(
                  (frame) => ChoiceChip(
                    label: Text(
                      '${frame[0].toUpperCase()}${frame.substring(1)}',
                    ),
                    selected: _bodyFrame == frame,
                    onSelected: (_) => setState(() => _bodyFrame = frame),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ['slim', 'regular', 'loose']
                .map(
                  (fit) => ChoiceChip(
                    label: Text(
                      '${fit[0].toUpperCase()}${fit.substring(1)} fit',
                    ),
                    selected: _fitPreference == fit,
                    onSelected: (_) => setState(() => _fitPreference = fit),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _metricSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              '${value.round()} $suffix',
              style: TextStyle(color: context.abzioSecondaryText),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round(),
          activeColor: AbzioTheme.accentColor,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _resultCard(SizePredictionResult result) {
    final displayedSize = _recommendedVariant ?? result.shirtSize;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AbzioTheme.accentColor.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: AbzioTheme.accentColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your best fit',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AbzioTheme.accentColor,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              _confidenceBadge(result.confidenceLabel),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Recommended for you: $displayedSize (${(result.confidence * 100).round()}% match)',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (_recommendedVariant != null) ...[
            const SizedBox(height: 6),
            Text(
              'Best available match for this product from ${widget.product!.sizes.join(', ')}',
              style: TextStyle(color: context.abzioSecondaryText),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            result.message,
            style: TextStyle(
              color: context.abzioSecondaryText,
              height: 1.45,
            ),
          ),
          if (result.reasoning.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7DE),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.insights_rounded,
                    size: 18,
                    color: AbzioTheme.accentColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.reasoning,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.product != null && widget.product!.sizes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.product!.sizes.map((size) {
                final normalized = size.toUpperCase();
                final isSelected = normalized == displayedSize.toUpperCase();
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AbzioTheme.accentColor
                        : const Color(0xFFFFFBF2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AbzioTheme.accentColor
                          : context.abzioBorder,
                    ),
                  ),
                  child: Text(
                    normalized,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.black : Colors.black87,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricChip('Chest', result.chestCm),
              _metricChip('Waist', result.waistCm),
              _metricChip('Shoulder', result.shoulderCm),
              _metricChip('Sleeve', result.sleeveCm),
            ],
          ),
          const SizedBox(height: 14),
          ...result.bodyOutlineHighlights.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AbzioTheme.accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confidenceBadge(String confidenceLabel) {
    final normalized = confidenceLabel.toLowerCase();
    final badgeColor = switch (normalized) {
      'high' => const Color(0xFFE7F7EC),
      'medium' => const Color(0xFFFFF2D8),
      _ => const Color(0xFFF3F4F6),
    };
    final textColor = switch (normalized) {
      'high' => const Color(0xFF18794E),
      'medium' => const Color(0xFFA15C00),
      _ => const Color(0xFF5B6470),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${confidenceLabel[0].toUpperCase()}${confidenceLabel.substring(1)} confidence',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }

  Widget _metricChip(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: context.abzioSecondaryText, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(0)} cm',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class SizeRecommendationOutcome {
  const SizeRecommendationOutcome({
    this.measurementProfile,
    required this.recommendedSize,
  });

  final MeasurementProfile? measurementProfile;
  final String recommendedSize;
}
