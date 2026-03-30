import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/body_scan_service.dart';
import '../../services/database_service.dart';
import '../../services/pose_measurement_service.dart';
import '../../theme.dart';
import '../../widgets/tap_scale.dart';
import 'live_body_scan_camera_screen.dart';

class BodyScanScreen extends StatefulWidget {
  const BodyScanScreen({super.key});

  @override
  State<BodyScanScreen> createState() => _BodyScanScreenState();
}

class _BodyScanScreenState extends State<BodyScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final DatabaseService _database = DatabaseService();
  final BodyScanService _bodyScanService = const BodyScanService();
  final TextEditingController _labelController = TextEditingController(
    text: 'AI Scan Profile',
  );

  XFile? _frontImage;
  XFile? _sideImage;
  PoseRefinementResult? _frontPoseRefinement;
  PoseRefinementResult? _sidePoseRefinement;
  double _heightCm = 170;
  double _weightKg = 68;
  String _bodyFrame = 'regular';
  bool _isAnalyzing = false;
  bool _isSaving = false;
  SizePredictionResult? _result;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({
    required ImageSource source,
    required bool isFront,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1280,
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      if (isFront) {
        _frontImage = picked;
      } else {
        _sideImage = picked;
      }
    });
  }

  Future<void> _openLiveCapture({required bool isFront}) async {
    final capture = await Navigator.push<LiveBodyScanCapture>(
      context,
      MaterialPageRoute(
        builder: (_) => LiveBodyScanCameraScreen(
          title: isFront ? 'Front body scan' : 'Side body scan',
        ),
      ),
    );
    if (!mounted || capture == null) {
      return;
    }
    setState(() {
      final file = XFile(capture.imagePath);
      if (isFront) {
        _frontImage = file;
        _frontPoseRefinement = capture.poseRefinement;
      } else {
        _sideImage = file;
        _sidePoseRefinement = capture.poseRefinement;
      }
    });
  }

  Future<void> _analyze() async {
    setState(() => _isAnalyzing = true);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    final poseRefinement = PoseRefinementResult.merge(
      _frontPoseRefinement,
      _sidePoseRefinement,
    );
    final result = _bodyScanService.analyze(
      BodyScanInput(
        heightCm: _heightCm,
        weightKg: _weightKg,
        bodyFrame: _bodyFrame,
        frontImagePath: _frontImage?.path,
        sideImagePath: _sideImage?.path,
      ),
      poseRefinement: poseRefinement,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _result = result;
      _isAnalyzing = false;
    });
  }

  Future<void> _saveProfile() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final result = _result;
    if (user == null || result == null) {
      return;
    }

    setState(() => _isSaving = true);
    final profile = result.toMeasurementProfile(
      userId: user.id,
      label: _labelController.text.trim().isEmpty
          ? 'AI Scan Profile'
          : _labelController.text.trim(),
    );
    final bodyProfile = BodyProfile(
      heightCm: _heightCm,
      weightKg: _weightKg,
      bodyType: _bodyFrame,
      recommendedSize: result.shirtSize,
      pantSize: result.pantSize,
      shoulderCm: result.shoulderCm,
      chestCm: result.chestCm,
      waistCm: result.waistCm,
      hipCm: result.hipCm,
      confidence: result.confidence,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _database.saveMeasurementProfile(profile);
    await _database.saveBodyProfile(user.id, bodyProfile);
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Body profile saved and ready to use.'),
      ),
    );
    Navigator.pop(context, profile);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: const Color(0xFF050505),
        appBar: AppBar(
          title: const Text('Scan Your Body'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0A0A0A),
                      const Color(0xFF16120A),
                      const Color(0xFFFFFDFC),
                    ],
                    stops: const [0.0, 0.34, 0.34],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroCard(),
                    const SizedBox(height: 20),
                    _captureCard(
                      title: 'Front view',
                      subtitle: 'Stand straight inside the silhouette guide.',
                      file: _frontImage,
                      hasPoseRefinement: _frontPoseRefinement != null,
                      accent: const Color(0xFFE7C95E),
                      onCamera: () => _openLiveCapture(isFront: true),
                      onGallery: () => _pickImage(
                        source: ImageSource.gallery,
                        isFront: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _captureCard(
                      title: 'Side view',
                      subtitle: 'Optional, but improves torso depth confidence.',
                      file: _sideImage,
                      hasPoseRefinement: _sidePoseRefinement != null,
                      accent: const Color(0xFFD7B149),
                      onCamera: () => _openLiveCapture(isFront: false),
                      onGallery: () => _pickImage(
                        source: ImageSource.gallery,
                        isFront: false,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _bodyInputsCard(),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: TapScale(
                        onTap: _isAnalyzing ? null : _analyze,
                        child: ElevatedButton.icon(
                          onPressed: _isAnalyzing ? null : _analyze,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Analyze my perfect fit'),
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
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _result = null;
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Rescan'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: user != null && !_isSaving ? _saveProfile : null,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(Icons.bookmark_add_outlined),
                              label: Text(
                                user == null
                                    ? 'Sign in to save'
                                    : _isSaving
                                        ? 'Saving...'
                                        : 'Save Measurements',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AbzioTheme.accentColor,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (user != null) ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: _labelController,
                          decoration: const InputDecoration(
                            labelText: 'Profile label',
                            hintText: 'AI Scan Profile',
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            if (_isAnalyzing) Positioned.fill(child: _processingOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF19130A),
            Color(0xFF070707),
          ],
        ),
        border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: AbzioTheme.accentColor.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stand straight and align within frame',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Capture a guided body outline, estimate your core measurements, and save a premium fit profile without keeping raw images permanently.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _ScanStepChip(icon: Icons.phone_android_rounded, label: 'Phone at chest level'),
              _ScanStepChip(icon: Icons.accessibility_new_rounded, label: 'Full body visible'),
              _ScanStepChip(icon: Icons.wb_sunny_outlined, label: 'Good lighting'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _captureCard({
    required String title,
    required String subtitle,
    required XFile? file,
    required bool hasPoseRefinement,
    required Color accent,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.abzioBorder.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.accessibility_new_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: context.abzioSecondaryText),
                    ),
                  ],
                ),
              ),
              if (hasPoseRefinement)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Pose refined',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 0.72,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (file != null)
                    Image.file(File(file.path), fit: BoxFit.cover)
                  else
                    Container(
                      color: const Color(0xFFFFFBF4),
                      child: Center(
                        child: Container(
                          width: 140,
                          height: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(80),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.45),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 152,
                        height: 264,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(82),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.78),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCamera,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Live Scan'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton.icon(
                  onPressed: onGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bodyInputsCard() {
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
            'Fine tune your scan',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'These details help the size engine refine your final recommendation.',
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
          const SizedBox(height: 8),
          _metricSlider(
            label: 'Weight',
            value: _weightKg,
            min: 40,
            max: 130,
            suffix: 'kg',
            onChanged: (value) => setState(() => _weightKg = value),
          ),
          const SizedBox(height: 14),
          Text(
            'Body frame',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended size',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AbzioTheme.accentColor,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${result.shirtSize} top  •  ${result.pantSize} trouser',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6DA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${(result.confidence * 100).round()}% confidence',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _resultMetric('Chest', result.chestCm),
              _resultMetric('Waist', result.waistCm),
              _resultMetric('Hip', result.hipCm),
              _resultMetric('Shoulder', result.shoulderCm),
              _resultMetric('Sleeve', result.sleeveCm),
              _resultMetric('Length', result.lengthCm),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Fit type: ${result.fit}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
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
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(color: context.abzioSecondaryText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _processingOverlay() {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.68),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AbzioTheme.accentColor.withValues(alpha: 0.24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AbzioTheme.accentColor,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Analyzing your body...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Getting your perfect fit with body proportions, confidence scoring, and size prediction.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultMetric(String label, double value) {
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
            style: TextStyle(
              color: context.abzioSecondaryText,
              fontSize: 12,
            ),
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

class _ScanStepChip extends StatelessWidget {
  const _ScanStepChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AbzioTheme.accentColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
