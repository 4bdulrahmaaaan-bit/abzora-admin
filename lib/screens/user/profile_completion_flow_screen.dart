import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_error_text.dart';
import '../../theme.dart';
import '../../widgets/abzio_motion.dart';
import 'address_screen.dart';
import 'body_scan_screen.dart';

class ProfileCompletionFlowScreen extends StatefulWidget {
  const ProfileCompletionFlowScreen({super.key, this.initialStep = 0});

  final int initialStep;

  @override
  State<ProfileCompletionFlowScreen> createState() =>
      _ProfileCompletionFlowScreenState();
}

class _ProfileCompletionFlowScreenState
    extends State<ProfileCompletionFlowScreen> {
  final DatabaseService _database = DatabaseService();
  final GlobalKey<FormState> _fitFormKey = GlobalKey<FormState>();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final FocusNode _heightFocus = FocusNode();
  final FocusNode _weightFocus = FocusNode();

  bool _loading = true;
  bool _savingFit = false;
  bool _addressDone = false;
  bool _fitDone = false;
  bool _scanUsed = false;
  bool _openingScan = false;
  MeasurementProfile? _scanProfile;
  BodyProfile? _savedBodyProfile;
  String _bodyType = 'Regular';
  String _fitPreference = 'Regular';
  int _step = 0;

  static const _bodyTypes = ['Slim', 'Regular', 'Athletic', 'Broad'];
  static const _fitPreferences = ['Tight', 'Regular', 'Loose'];

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep.clamp(0, 2).toInt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_loadStatus());
      }
    });
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _heightFocus.dispose();
    _weightFocus.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    try {
      final results = await Future.wait<Object?>([
        _database
            .getUserAddresses(user.id)
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                debugPrint('Profile completion address status timed out.');
                return <UserAddress>[];
              },
            ),
        _database
            .getBodyProfile(user.id)
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                debugPrint('Profile completion fit status timed out.');
                return null;
              },
            ),
      ]);
      if (!mounted) return;

      final addresses = results[0] as List<UserAddress>;
      final bodyProfile = results[1] as BodyProfile?;

      setState(() {
        _addressDone = addresses.isNotEmpty;
        _fitDone = bodyProfile != null;
        _savedBodyProfile = bodyProfile;
        if (bodyProfile != null) {
          _heightController.text = bodyProfile.heightCm.toStringAsFixed(0);
          _weightController.text = bodyProfile.weightKg.toStringAsFixed(0);
          _bodyType = _labelCase(bodyProfile.bodyType);
          _fitPreference = _labelCase(bodyProfile.fitPreference);
          _scanUsed = bodyProfile.scanSource == 'smart_scan';
        }
        if (!_addressDone) {
          _step = 0;
        } else if (!_fitDone) {
          _step = 1;
        } else {
          _step = 2;
        }
        _loading = false;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      debugPrint('Profile completion status fallback: $error');
      debugPrintStack(stackTrace: stackTrace);
      setState(() => _loading = false);
    }
  }

  String _labelCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Regular';
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  Future<void> _openAddress() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddressScreen()),
    );
    if (mounted) {
      await _loadStatus();
      if (_addressDone && _step < 1) {
        setState(() => _step = 1);
      }
    }
  }

  Future<void> _runSmartScan() async {
    if (_openingScan) return;
    HapticFeedback.mediumImpact();
    setState(() => _openingScan = true);
    try {
      final profile = await Navigator.push<MeasurementProfile>(
        context,
        MaterialPageRoute(builder: (_) => const BodyScanScreen()),
      );
      if (!mounted) return;
      setState(() {
        _scanUsed = profile != null;
        _scanProfile = profile;
      });
      if (profile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Smart scan captured. You can now analyze fit.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _openingScan = false);
      }
    }
  }

  double _heightValue() => double.tryParse(_heightController.text.trim()) ?? 0;
  double _weightValue() => double.tryParse(_weightController.text.trim()) ?? 0;

  String _recommendedSize() {
    final height = _heightValue();
    final weight = _weightValue();
    final score = (height * 0.42) + (weight * 0.58);
    if (score < 95) return 'S';
    if (score < 120) return 'M';
    if (score < 145) return 'L';
    return 'XL';
  }

  double _confidenceScore() {
    final height = _heightValue();
    final weight = _weightValue();
    if (height <= 0 || weight <= 0) {
      return 0;
    }

    var score = 0.78;
    if (_bodyType == 'Regular') score += 0.06;
    if (_fitPreference == 'Regular') score += 0.06;
    if (_scanUsed) score += 0.08;
    if (height > 0 && weight > 0) score += 0.02;
    return score.clamp(0.72, 0.96);
  }

  Future<void> _analyzeFit() async {
    if (_savingFit) return;
    final valid = _fitFormKey.currentState?.validate() ?? false;
    if (!valid) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _savingFit = true);
    try {
      final profile = BodyProfile(
        heightCm: _heightValue(),
        weightKg: _weightValue(),
        bodyType: _bodyType.toLowerCase(),
        recommendedSize: _recommendedSize(),
        fitPreference: _fitPreference.toLowerCase(),
        confidence: _confidenceScore(),
        scanFrameCount: _scanUsed ? 72 : 0,
        scanSource: _scanUsed ? 'smart_scan' : 'manual',
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _database.saveBodyProfile(user.id, profile);
      if (!mounted) return;
      setState(() {
        _savedBodyProfile = profile;
        _fitDone = true;
        _savingFit = false;
        _step = 2;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fit profile saved')));
    } catch (error, stackTrace) {
      if (!mounted) return;
      debugPrint('ProfileCompletionFlow: save fit profile failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      setState(() => _savingFit = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorText.from(error))));
    }
  }

  void _startExploring() {
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      return AbzioThemeScope.light(
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(title: const Text('Complete Your Profile')),
          body: const Center(child: Text('Sign in to continue profile setup.')),
        ),
      );
    }

    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Complete Your Profile')),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AbzioTheme.screenHorizontalPadding,
                    20,
                    AbzioTheme.screenHorizontalPadding,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProgressHeader(
                        progress: _progress,
                        addressDone: _addressDone,
                        fitDone: _fitDone,
                        step: _step,
                      ),
                      const SizedBox(height: 20),
                      if (_step >= 2)
                        _CompletionScreen(onStartExploring: _startExploring)
                      else ...[
                        if (_step <= 0) ...[
                          _IntroStepCard(
                            step: 'Step 1',
                            title: 'Address',
                            subtitle:
                                'Add your delivery address so checkout and tailoring stay seamless.',
                            completed: _addressDone,
                            actionLabel: _addressDone
                                ? 'Edit address'
                                : 'Add address',
                            onTap: _openAddress,
                            bullets: const [
                              'Delivery destination',
                              'Location autofill',
                              'Service-area validation',
                            ],
                          ),
                        ],
                        if (_step >= 1) ...[
                          _FitStepCard(
                            formKey: _fitFormKey,
                            heightController: _heightController,
                            weightController: _weightController,
                            bodyType: _bodyType,
                            fitPreference: _fitPreference,
                            scanUsed: _scanUsed,
                            scanProfile: _scanProfile,
                            recommendedSize: _fitDone
                                ? _savedBodyProfile?.recommendedSize ??
                                      _recommendedSize()
                                : _recommendedSize(),
                            confidenceScore: _fitDone
                                ? _savedBodyProfile?.confidence ??
                                      _confidenceScore()
                                : _confidenceScore(),
                            bodyTypes: _bodyTypes,
                            fitPreferences: _fitPreferences,
                            onBodyTypeChanged: (value) =>
                                setState(() => _bodyType = value),
                            onFitPreferenceChanged: (value) =>
                                setState(() => _fitPreference = value),
                            onRunSmartScan: _runSmartScan,
                            onAnalyzeFit: _analyzeFit,
                            onHeightSubmitted: () =>
                                _weightFocus.requestFocus(),
                            onWeightSubmitted: () =>
                                FocusScope.of(context).unfocus(),
                            heightFocus: _heightFocus,
                            weightFocus: _weightFocus,
                            saving: _savingFit,
                            scanBusy: _openingScan,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  double get _progress {
    var value = 0.0;
    if (_addressDone) value += 1;
    if (_fitDone) value += 1;
    return value / 2.0;
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.progress,
    required this.addressDone,
    required this.fitDone,
    required this.step,
  });

  final double progress;
  final bool addressDone;
  final bool fitDone;
  final int step;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round().clamp(0, 100);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(color: context.abzioBorder),
        boxShadow: AbzioTheme.shadowFor(Brightness.light),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Complete Your Profile',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$percent%',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AbzioTheme.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              duration: AbzioMotion.medium,
              curve: AbzioMotion.curve,
              tween: Tween<double>(begin: 0, end: progress),
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF2E8D9),
                  color: AbzioTheme.accentColor,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ProgressStepPill(
                  label: 'Address',
                  complete: addressDone,
                  active: step == 0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProgressStepPill(
                  label: 'Fit Profile',
                  complete: fitDone,
                  active: step == 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressStepPill extends StatelessWidget {
  const _ProgressStepPill({
    required this.label,
    required this.complete,
    required this.active,
  });

  final String label;
  final bool complete;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final background = complete
        ? const Color(0xFFEAF5E9)
        : active
        ? AbzioTheme.accentColor.withValues(alpha: 0.12)
        : const Color(0xFFF6F0E6);
    final color = complete
        ? const Color(0xFF2F7A3D)
        : active
        ? AbzioTheme.textPrimary
        : context.abzioSecondaryText;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            complete ? Icons.check_rounded : Icons.circle_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroStepCard extends StatelessWidget {
  const _IntroStepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.completed,
    required this.actionLabel,
    required this.onTap,
    required this.bullets,
  });

  final String step;
  final String title;
  final String subtitle;
  final bool completed;
  final String actionLabel;
  final VoidCallback onTap;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StepPill(label: step, complete: completed),
              const Spacer(),
              Icon(
                completed
                    ? Icons.check_circle_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: completed ? 20 : 16,
                color: completed
                    ? const Color(0xFF2F7A3D)
                    : AbzioTheme.accentColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.abzioSecondaryText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          ...bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F1E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Color(0xFF8D6C22),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      bullet,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(onPressed: onTap, child: Text(actionLabel)),
          ),
        ],
      ),
    );
  }
}

class _FitStepCard extends StatelessWidget {
  const _FitStepCard({
    required this.formKey,
    required this.heightController,
    required this.weightController,
    required this.bodyType,
    required this.fitPreference,
    required this.scanUsed,
    required this.scanProfile,
    required this.recommendedSize,
    required this.confidenceScore,
    required this.bodyTypes,
    required this.fitPreferences,
    required this.onBodyTypeChanged,
    required this.onFitPreferenceChanged,
    required this.onRunSmartScan,
    required this.onAnalyzeFit,
    required this.onHeightSubmitted,
    required this.onWeightSubmitted,
    required this.heightFocus,
    required this.weightFocus,
    required this.saving,
    required this.scanBusy,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final String bodyType;
  final String fitPreference;
  final bool scanUsed;
  final MeasurementProfile? scanProfile;
  final String recommendedSize;
  final double confidenceScore;
  final List<String> bodyTypes;
  final List<String> fitPreferences;
  final ValueChanged<String> onBodyTypeChanged;
  final ValueChanged<String> onFitPreferenceChanged;
  final VoidCallback onRunSmartScan;
  final VoidCallback onAnalyzeFit;
  final VoidCallback onHeightSubmitted;
  final VoidCallback onWeightSubmitted;
  final FocusNode heightFocus;
  final FocusNode weightFocus;
  final bool saving;
  final bool scanBusy;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StepPill(label: 'Step 2', complete: false),
                const Spacer(),
                if (scanUsed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF5E9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Smart scan applied',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF2F7A3D),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Fit Profile',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter your measurements and preferences once. We will save the recommended size and confidence score for future checkouts.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.abzioSecondaryText,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: heightController,
              focusNode: heightFocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: const InputDecoration(
                labelText: 'Height',
                hintText: 'cm',
                suffixText: 'cm',
              ),
              validator: (value) {
                final parsed = double.tryParse((value ?? '').trim()) ?? 0;
                if (parsed <= 0) {
                  return 'Height is required';
                }
                if (parsed < 120 || parsed > 230) {
                  return 'Enter a realistic height';
                }
                return null;
              },
              onFieldSubmitted: (_) => onHeightSubmitted(),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: weightController,
              focusNode: weightFocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: const InputDecoration(
                labelText: 'Weight',
                hintText: 'kg',
                suffixText: 'kg',
              ),
              validator: (value) {
                final parsed = double.tryParse((value ?? '').trim()) ?? 0;
                if (parsed <= 0) {
                  return 'Weight is required';
                }
                if (parsed < 30 || parsed > 250) {
                  return 'Enter a realistic weight';
                }
                return null;
              },
              onFieldSubmitted: (_) => onWeightSubmitted(),
            ),
            const SizedBox(height: 12),
            Text(
              'Body Type',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: bodyTypes
                  .map(
                    (value) => ChoiceChip(
                      label: Text(value),
                      selected: bodyType == value,
                      showCheckmark: false,
                      selectedColor: AbzioTheme.accentColor.withValues(
                        alpha: 0.16,
                      ),
                      backgroundColor: const Color(0xFFF6F1E8),
                      labelStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: bodyType == value
                                ? AbzioTheme.textPrimary
                                : context.abzioSecondaryText,
                          ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: BorderSide(
                          color: bodyType == value
                              ? AbzioTheme.accentColor.withValues(alpha: 0.40)
                              : const Color(0xFFE4D8C7),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onSelected: (_) => onBodyTypeChanged(value),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text(
              'Fit Preference',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: fitPreferences
                  .map(
                    (value) => ChoiceChip(
                      label: Text(value),
                      selected: fitPreference == value,
                      showCheckmark: false,
                      selectedColor: AbzioTheme.accentColor.withValues(
                        alpha: 0.16,
                      ),
                      backgroundColor: const Color(0xFFF6F1E8),
                      labelStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: fitPreference == value
                                ? AbzioTheme.textPrimary
                                : context.abzioSecondaryText,
                          ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: BorderSide(
                          color: fitPreference == value
                              ? AbzioTheme.accentColor.withValues(alpha: 0.40)
                              : const Color(0xFFE4D8C7),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onSelected: (_) => onFitPreferenceChanged(value),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            _ScanBlock(
              scanUsed: scanUsed,
              scanProfile: scanProfile,
              busy: scanBusy,
              onRunSmartScan: onRunSmartScan,
            ),
            const SizedBox(height: 16),
            _FitSummaryCard(
              recommendedSize: recommendedSize,
              confidenceScore: confidenceScore,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (saving || scanBusy) ? null : onAnalyzeFit,
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Text('Analyze Fit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanBlock extends StatelessWidget {
  const _ScanBlock({
    required this.scanUsed,
    required this.scanProfile,
    required this.busy,
    required this.onRunSmartScan,
  });

  final bool scanUsed;
  final MeasurementProfile? scanProfile;
  final bool busy;
  final VoidCallback onRunSmartScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3),
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(
          color: AbzioTheme.accentColor.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  color: AbzioTheme.accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Optional Smart Body Scan',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (scanUsed)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2F7A3D),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            scanUsed
                ? 'Smart scan captured. We will use it to improve confidence.'
                : 'Run a smart scan to increase confidence and fine-tune fit recommendations.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.abzioSecondaryText,
              height: 1.45,
            ),
          ),
          if (scanProfile != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last scan: ${scanProfile!.recommendedSize}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF2F7A3D),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: busy ? null : onRunSmartScan,
              child: Text(
                scanUsed ? 'Run Smart Scan Again' : 'Run Smart Body Scan',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FitSummaryCard extends StatelessWidget {
  const _FitSummaryCard({
    required this.recommendedSize,
    required this.confidenceScore,
  });

  final String recommendedSize;
  final double confidenceScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F1E2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.straighten_rounded,
              color: AbzioTheme.accentColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fit Preview',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recommended size: $recommendedSize',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence score: ${(confidenceScore * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.abzioSecondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionScreen extends StatelessWidget {
  const _CompletionScreen({required this.onStartExploring});

  final VoidCallback onStartExploring;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5E9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Color(0xFF2F7A3D),
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Profile Complete',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Address Added\nFit Profile Saved',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.abzioSecondaryText,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "You're ready to shop.",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: onStartExploring,
              child: const Text('Start Exploring'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(color: context.abzioBorder),
        boxShadow: AbzioTheme.shadowFor(Brightness.light),
      ),
      child: child,
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: complete
            ? const Color(0xFFEAF5E9)
            : AbzioTheme.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: complete ? const Color(0xFF2F7A3D) : AbzioTheme.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
