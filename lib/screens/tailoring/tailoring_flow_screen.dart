import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import 'tailor_booking_screen.dart';

enum MeasurementMethod { manual, standard, previous }

enum MeasurementUnit { cm, inch }

class CustomTailoringFlowScreen extends StatefulWidget {
  const CustomTailoringFlowScreen({
    super.key,
    this.selectionOnly = false,
  });

  final bool selectionOnly;

  @override
  State<CustomTailoringFlowScreen> createState() => _CustomTailoringFlowScreenState();
}

class _CustomTailoringFlowScreenState extends State<CustomTailoringFlowScreen> {
  static const List<_MeasurementFieldDefinition> _fields = [
    _MeasurementFieldDefinition(
      key: 'chest',
      label: 'Chest',
      helpText: 'Measure around the fullest part of your chest.',
      minCm: 70,
      maxCm: 160,
      icon: Icons.accessibility_new_rounded,
    ),
    _MeasurementFieldDefinition(
      key: 'waist',
      label: 'Waist',
      helpText: 'Wrap the tape around your natural waist, just above the navel.',
      minCm: 55,
      maxCm: 150,
      icon: Icons.straighten_rounded,
    ),
    _MeasurementFieldDefinition(
      key: 'shoulder',
      label: 'Shoulder',
      helpText: 'Measure straight across from one shoulder edge to the other.',
      minCm: 30,
      maxCm: 70,
      icon: Icons.accessibility_rounded,
    ),
    _MeasurementFieldDefinition(
      key: 'sleeve',
      label: 'Sleeve Length',
      helpText: 'Measure from the shoulder point down to the wrist.',
      minCm: 45,
      maxCm: 75,
      icon: Icons.swipe_vertical_rounded,
    ),
    _MeasurementFieldDefinition(
      key: 'length',
      label: 'Shirt Length',
      helpText: 'Measure from the highest shoulder point down to the desired hem.',
      minCm: 55,
      maxCm: 100,
      icon: Icons.height_rounded,
    ),
  ];

  static const Map<String, Map<String, double>> _standardProfiles = {
    'S': {'chest': 92, 'waist': 80, 'shoulder': 43, 'sleeve': 61, 'length': 70},
    'M': {'chest': 100, 'waist': 88, 'shoulder': 45, 'sleeve': 62, 'length': 72},
    'L': {'chest': 108, 'waist': 96, 'shoulder': 47, 'sleeve': 63, 'length': 74},
    'XL': {'chest': 116, 'waist': 104, 'shoulder': 49, 'sleeve': 64, 'length': 76},
  };

  final DatabaseService _database = DatabaseService();
  final GlobalKey<FormState> _manualFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _standardRecommendationKey = GlobalKey<FormState>();
  final TextEditingController _profileNameController = TextEditingController(text: 'My Size');
  final TextEditingController _standardChestController = TextEditingController();
  final TextEditingController _standardWaistController = TextEditingController();

  late final Map<String, TextEditingController> _manualControllers;
  late final Map<String, MeasurementUnit> _manualUnits;

  MeasurementMethod? _selectedMethod;
  int _stepIndex = 0;
  bool _saveProfile = true;
  bool _isSaving = false;
  bool _hasLoadedProfiles = false;
  Future<List<MeasurementProfile>>? _profilesFuture;
  String _selectedStandardSize = 'M';
  String? _recommendedStandardSize;
  MeasurementProfile? _selectedExistingProfile;
  MeasurementProfile? _reviewProfile;

  @override
  void initState() {
    super.initState();
    _manualControllers = {
      for (final field in _fields) field.key: TextEditingController(),
    };
    _manualUnits = {
      for (final field in _fields) field.key: MeasurementUnit.cm,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoadedProfiles) {
      return;
    }
    _hasLoadedProfiles = true;
    _profilesFuture = _loadProfiles();
  }

  @override
  void dispose() {
    for (final controller in _manualControllers.values) {
      controller.dispose();
    }
    _profileNameController.dispose();
    _standardChestController.dispose();
    _standardWaistController.dispose();
    super.dispose();
  }

  Future<List<MeasurementProfile>> _loadProfiles() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      return const [];
    }
    return _database.getMeasurementProfiles(user.id);
  }

  @override
  Widget build(BuildContext context) {
    return AbzioThemeScope.dark(
      child: Scaffold(
      backgroundColor: AbzioTheme.darkBackground,
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter Your Measurements', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              'Ensure the perfect fit',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AbzioTheme.grey600),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _buildStepHeader(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _stepIndex == 0 ? _buildMethodSelection() : _buildCurrentStep(),
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStepHeader() {
    const labels = ['Method', 'Input', 'Review'];
    return Row(
      children: List.generate(labels.length, (index) {
        final isActive = index == _stepIndex;
        final isComplete = index < _stepIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive || isComplete ? AbzioTheme.accentColor : AbzioTheme.grey100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  labels[index],
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isActive || isComplete ? AbzioTheme.accentColor : AbzioTheme.grey500,
                      ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMethodSelection() {
    return Column(
      key: const ValueKey('method-selection'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Measurement Method (Step 1)'),
        const SizedBox(height: 12),
        _methodCard(
          method: MeasurementMethod.manual,
          title: 'Manual Entry',
          description: 'Enter each measurement with guided help and inline validation.',
          icon: Icons.edit_note_rounded,
        ),
        const SizedBox(height: 12),
        _methodCard(
          method: MeasurementMethod.standard,
          title: 'Use Standard Size',
          description: 'Choose S, M, L, or XL and see the recommended size based on your input.',
          icon: Icons.checkroom_rounded,
        ),
        const SizedBox(height: 12),
        _methodCard(
          method: MeasurementMethod.previous,
          title: 'Upload Previous Measurements',
          description: 'Reuse a saved measurement profile from your ABZOVA account to avoid starting over.',
          icon: Icons.cloud_upload_rounded,
        ),
        const SizedBox(height: 24),
        _heroNote(),
      ],
    );
  }

  Widget _buildCurrentStep() {
    if (_stepIndex == 1) {
      switch (_selectedMethod) {
        case MeasurementMethod.manual:
          return _buildManualStep();
        case MeasurementMethod.standard:
          return _buildStandardSizeStep();
        case MeasurementMethod.previous:
          return _buildPreviousMeasurementsStep();
        case null:
          return const SizedBox.shrink();
      }
    }
    return _buildReviewStep();
  }

  Widget _buildManualStep() {
    return Form(
      key: _manualFormKey,
      child: Column(
        key: const ValueKey('manual-step'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Manual Entry'),
          const SizedBox(height: 8),
          Text(
            'Simple, guided fields help you capture accurate body measurements without second guessing.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          for (final field in _fields) ...[
            _measurementFieldCard(field),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildStandardSizeStep() {
    return Column(
      key: const ValueKey('standard-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Use Standard Size'),
        const SizedBox(height: 8),
        Text(
          'Pick a base size and refine it with a recommendation from your chest and waist.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose a size', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _standardProfiles.keys.map((size) {
                  final isSelected = _selectedStandardSize == size;
                  return ChoiceChip(
                    label: Text(size),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedStandardSize = size),
                    selectedColor: AbzioTheme.accentColor,
                    backgroundColor: AbzioTheme.grey100,
                    labelStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.black : AbzioTheme.textPrimary,
                    ),
                    side: BorderSide(color: isSelected ? AbzioTheme.accentColor : AbzioTheme.grey300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Form(
                key: _standardRecommendationKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _standardChestController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Chest for recommendation',
                        suffixText: 'cm',
                      ),
                      validator: (value) => _validateStandardInput(value, min: 70, max: 160, label: 'Chest'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _standardWaistController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Waist for recommendation',
                        suffixText: 'cm',
                      ),
                      validator: (value) => _validateStandardInput(value, min: 55, max: 150, label: 'Waist'),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _recommendStandardSize,
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text('Recommend my size'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended size based on your input',
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _recommendedStandardSize ?? _selectedStandardSize,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AbzioTheme.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviousMeasurementsStep() {
    return Column(
      key: const ValueKey('previous-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Upload Previous Measurements'),
        const SizedBox(height: 8),
        Text(
          'Choose a saved profile to instantly reuse your earlier tailoring measurements.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        FutureBuilder<List<MeasurementProfile>>(
          future: _profilesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AbzioTheme.accentColor),
                ),
              );
            }
            final profiles = snapshot.data ?? const <MeasurementProfile>[];
            if (profiles.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: _panelDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No saved profiles yet', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Create a measurement profile once and it will appear here for future custom orders.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: profiles.map((profile) => _previousProfileCard(profile)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final profile = _reviewProfile;
    if (profile == null) {
      return const SizedBox.shrink();
    }
    final methodLabel = _methodLabel(_selectedMethod);
    final standardSize = _selectedMethod == MeasurementMethod.standard ? _selectedStandardSize : profile.standardSize;
    return Column(
      key: const ValueKey('review-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Review Before Order'),
        const SizedBox(height: 8),
        Text(
          'Double check your measurements before you continue to the tailoring booking step.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.label, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Method: $methodLabel',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AbzioTheme.grey600),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _stepIndex = 1),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit'),
                  ),
                ],
              ),
              if (standardSize != null) ...[
                const SizedBox(height: 14),
                _reviewBadge('Standard size', standardSize),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _reviewValue('Chest', profile.chest),
                  _reviewValue('Waist', profile.waist),
                  _reviewValue('Shoulder', profile.shoulder),
                  _reviewValue('Sleeve Length', profile.sleeve),
                  _reviewValue('Shirt Length', profile.length),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                value: _saveProfile,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AbzioTheme.accentColor,
                activeTrackColor: AbzioTheme.accentColor.withValues(alpha: 0.35),
                title: Text('Save measurement profile', style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(
                  'Store it in Firebase so you can reuse it for later orders.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                onChanged: (value) => setState(() => _saveProfile = value),
              ),
              if (_saveProfile) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _profileNameController,
                  decoration: const InputDecoration(
                    labelText: 'Profile name',
                    hintText: 'My Size, Office Wear, Wedding Fit',
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _panelDecoration(),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FutureFeatureRow(
                icon: Icons.photo_camera_front_rounded,
                title: 'Camera-based measurement',
                subtitle: 'Future option for guided capture with tape-free onboarding.',
              ),
              SizedBox(height: 14),
              _FutureFeatureRow(
                icon: Icons.auto_graph_rounded,
                title: 'AI size recommendation',
                subtitle: 'Expandable recommendation logic for style-specific fit guidance.',
              ),
              SizedBox(height: 14),
              _FutureFeatureRow(
                icon: Icons.collections_bookmark_rounded,
                title: 'Multiple profiles',
                subtitle: 'Already supported through saved profiles for different outfits or fit preferences.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _methodCard({
    required MeasurementMethod method,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _selectedMethod == method;
    return InkWell(
      onTap: () => setState(() => _selectedMethod = method),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? AbzioTheme.accentColor.withValues(alpha: 0.12) : AbzioTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AbzioTheme.accentColor : AbzioTheme.grey100),
          boxShadow: isSelected ? AbzioTheme.eliteShadow : const [],
        ),
        child: Row(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: isSelected ? AbzioTheme.accentColor : AbzioTheme.grey100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: isSelected ? Colors.black : AbzioTheme.accentColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(description, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? AbzioTheme.accentColor : AbzioTheme.grey500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _measurementFieldCard(_MeasurementFieldDefinition field) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _measurementIllustration(field),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(field.label, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(field.helpText, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _manualControllers[field.key],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: field.label,
              suffixText: _manualUnits[field.key] == MeasurementUnit.cm ? 'cm' : 'inch',
            ),
            validator: (value) => _validateManualField(field, value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ToggleButtons(
                isSelected: [
                  _manualUnits[field.key] == MeasurementUnit.cm,
                  _manualUnits[field.key] == MeasurementUnit.inch,
                ],
                onPressed: (index) => _switchUnit(field.key, index == 0 ? MeasurementUnit.cm : MeasurementUnit.inch),
                borderRadius: BorderRadius.circular(12),
                constraints: const BoxConstraints(minHeight: 40, minWidth: 68),
                selectedColor: Colors.black,
                fillColor: AbzioTheme.accentColor,
                color: AbzioTheme.textPrimary,
                borderColor: AbzioTheme.grey300,
                selectedBorderColor: AbzioTheme.accentColor,
                children: const [Text('cm'), Text('inch')],
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showHowToMeasure(field),
                icon: const Icon(Icons.help_outline_rounded, size: 18),
                label: const Text('How to measure?'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _measurementIllustration(_MeasurementFieldDefinition field) {
    return Container(
      height: 68,
      width: 68,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AbzioTheme.accentColor.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AbzioTheme.grey100),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(field.icon, color: AbzioTheme.accentColor, size: 30),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Container(height: 2, color: Colors.white24),
          ),
        ],
      ),
    );
  }

  Widget _previousProfileCard(MeasurementProfile profile) {
    final isSelected = _selectedExistingProfile?.id == profile.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _selectedExistingProfile = profile),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isSelected ? AbzioTheme.accentColor.withValues(alpha: 0.12) : AbzioTheme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isSelected ? AbzioTheme.accentColor : AbzioTheme.grey100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(profile.label, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                    color: isSelected ? AbzioTheme.accentColor : AbzioTheme.grey500,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Chest ${profile.chest.toStringAsFixed(1)} cm  |  Waist ${profile.waist.toStringAsFixed(1)} cm  |  Sleeve ${profile.sleeve.toStringAsFixed(1)} cm',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewValue(String label, double value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AbzioTheme.grey50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AbzioTheme.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AbzioTheme.grey600)),
          const SizedBox(height: 8),
          Text(
            '${value.toStringAsFixed(1)} cm',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AbzioTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _reviewBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AbzioTheme.grey50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AbzioTheme.grey100),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AbzioTheme.textPrimary),
      ),
    );
  }

  Widget _heroNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF151515), Color(0xFF090909)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AbzioTheme.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trustworthy custom fit',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ABZOVA keeps the flow guided, validates each entry, and lets you save multiple profiles for different outfits.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isReview = _stepIndex == 2;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: const Color(0xFF080808),
        border: Border(top: BorderSide(color: AbzioTheme.grey100)),
      ),
      child: Row(
        children: [
          if (_stepIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving
                    ? null
                    : () => setState(() {
                          if (_stepIndex == 2) {
                            _stepIndex = 1;
                          } else {
                            _stepIndex = 0;
                          }
                        }),
                child: const Text('Back'),
              ),
            ),
          if (_stepIndex > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving ? null : (isReview ? _saveAndContinue : _goToNextStep),
              style: ElevatedButton.styleFrom(
                backgroundColor: AbzioTheme.accentColor,
                foregroundColor: Colors.black,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text(isReview ? 'Save and Continue' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _goToNextStep() async {
    if (_stepIndex == 0) {
      if (_selectedMethod == null) {
        _showSnackBar('Choose a measurement method to continue.');
        return;
      }
      setState(() => _stepIndex = 1);
      return;
    }

    final profile = _buildReviewProfile();
    if (profile == null) {
      return;
    }
    setState(() {
      _reviewProfile = profile;
      _stepIndex = 2;
      if (_selectedMethod == MeasurementMethod.previous && _selectedExistingProfile != null) {
        _profileNameController.text = _selectedExistingProfile!.label;
      }
      if (_selectedMethod == MeasurementMethod.standard) {
        _profileNameController.text = '$_selectedStandardSize Size';
      }
    });
  }

  MeasurementProfile? _buildReviewProfile() {
    switch (_selectedMethod) {
      case MeasurementMethod.manual:
        if (!_manualFormKey.currentState!.validate()) {
          return null;
        }
        final values = <String, double>{};
        for (final field in _fields) {
          final rawValue = double.tryParse(_manualControllers[field.key]!.text.trim());
          if (rawValue == null) {
            return null;
          }
          values[field.key] = _manualUnits[field.key] == MeasurementUnit.cm ? rawValue : _inchToCm(rawValue);
        }
        return MeasurementProfile(
          id: '',
          userId: context.read<AuthProvider>().user?.id ?? '',
          label: _profileNameController.text.trim().isEmpty ? 'My Size' : _profileNameController.text.trim(),
          method: 'manual',
          unit: 'cm',
          chest: values['chest']!,
          waist: values['waist']!,
          shoulder: values['shoulder']!,
          sleeve: values['sleeve']!,
          length: values['length']!,
          recommendedSize: _recommendSizeFromValues(values['chest']!, values['waist']!),
        );
      case MeasurementMethod.standard:
        final preset = _standardProfiles[_selectedStandardSize]!;
        return MeasurementProfile(
          id: '',
          userId: context.read<AuthProvider>().user?.id ?? '',
          label: '$_selectedStandardSize Size',
          method: 'standard',
          unit: 'cm',
          chest: preset['chest']!,
          waist: preset['waist']!,
          shoulder: preset['shoulder']!,
          sleeve: preset['sleeve']!,
          length: preset['length']!,
          standardSize: _selectedStandardSize,
          recommendedSize: _recommendedStandardSize ?? _selectedStandardSize,
        );
      case MeasurementMethod.previous:
        if (_selectedExistingProfile == null) {
          _showSnackBar('Choose a saved profile to continue.');
          return null;
        }
        return MeasurementProfile(
          id: _selectedExistingProfile!.id,
          userId: _selectedExistingProfile!.userId,
          label: _selectedExistingProfile!.label,
          method: 'previous',
          unit: _selectedExistingProfile!.unit,
          chest: _selectedExistingProfile!.chest,
          waist: _selectedExistingProfile!.waist,
          shoulder: _selectedExistingProfile!.shoulder,
          sleeve: _selectedExistingProfile!.sleeve,
          length: _selectedExistingProfile!.length,
          standardSize: _selectedExistingProfile!.standardSize,
          recommendedSize: _selectedExistingProfile!.recommendedSize,
          sourceProfileId: _selectedExistingProfile!.id,
        );
      case null:
        return null;
    }
  }

  Future<void> _saveAndContinue() async {
    final draft = _reviewProfile;
    if (draft == null) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final auth = context.read<AuthProvider>();
      final currentUser = auth.user;
      var profileToUse = draft;
      if (_saveProfile) {
        if (currentUser == null) {
          _showSnackBar('Sign in to save this profile to Firebase.');
        } else if (_profileNameController.text.trim().isEmpty) {
          _showSnackBar('Add a name for this profile before saving.');
          return;
        } else {
          final profile = MeasurementProfile(
            id: draft.id,
            userId: currentUser.id,
            label: _profileNameController.text.trim(),
            method: draft.method,
            unit: draft.unit,
            chest: draft.chest,
            waist: draft.waist,
            shoulder: draft.shoulder,
            sleeve: draft.sleeve,
            length: draft.length,
            standardSize: draft.standardSize,
            recommendedSize: draft.recommendedSize,
            sourceProfileId: draft.sourceProfileId,
          );
          await _database.saveMeasurementProfile(profile);
          profileToUse = profile;
          _profilesFuture = _loadProfiles();
        }
      }

      if (!mounted) {
        return;
      }

      if (widget.selectionOnly) {
        Navigator.of(context).pop(profileToUse);
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TailorBookingScreen(
            measurementProfile: profileToUse,
            measurementMethod: _methodLabel(_selectedMethod),
            standardSize: _selectedMethod == MeasurementMethod.standard ? _selectedStandardSize : profileToUse.standardSize,
          ),
        ),
      );
      return;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _recommendStandardSize() {
    if (!_standardRecommendationKey.currentState!.validate()) {
      return;
    }
    final chest = double.parse(_standardChestController.text.trim());
    final waist = double.parse(_standardWaistController.text.trim());
    final recommended = _recommendSizeFromValues(chest, waist);
    setState(() {
      _recommendedStandardSize = recommended;
      _selectedStandardSize = recommended;
    });
  }

  String _recommendSizeFromValues(double chest, double waist) {
    if (chest <= 95 && waist <= 82) {
      return 'S';
    }
    if (chest <= 103 && waist <= 90) {
      return 'M';
    }
    if (chest <= 111 && waist <= 98) {
      return 'L';
    }
    return 'XL';
  }

  void _switchUnit(String fieldKey, MeasurementUnit nextUnit) {
    final currentUnit = _manualUnits[fieldKey];
    if (currentUnit == nextUnit) {
      return;
    }
    final controller = _manualControllers[fieldKey]!;
    final value = double.tryParse(controller.text.trim());
    if (value != null) {
      final converted = nextUnit == MeasurementUnit.cm ? _inchToCm(value) : _cmToInch(value);
      controller.text = converted.toStringAsFixed(1);
    }
    setState(() => _manualUnits[fieldKey] = nextUnit);
  }

  String? _validateManualField(_MeasurementFieldDefinition field, String? value) {
    if (value == null || value.trim().isEmpty) {
      return '${field.label} is required.';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid number.';
    }
    final isCm = _manualUnits[field.key] == MeasurementUnit.cm;
    final min = isCm ? field.minCm : _cmToInch(field.minCm);
    final max = isCm ? field.maxCm : _cmToInch(field.maxCm);
    if (parsed < min || parsed > max) {
      final unitLabel = isCm ? 'cm' : 'inch';
      return 'Use a value between ${min.toStringAsFixed(0)} and ${max.toStringAsFixed(0)} $unitLabel.';
    }
    return null;
  }

  String? _validateStandardInput(String? value, {required double min, required double max, required String label}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required for recommendation.';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid number.';
    }
    if (parsed < min || parsed > max) {
      return '$label should stay between ${min.toStringAsFixed(0)} and ${max.toStringAsFixed(0)} cm.';
    }
    return null;
  }

  void _showHowToMeasure(_MeasurementFieldDefinition field) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AbzioTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(field.label, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(field.helpText, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              Text(
                'Tip: Keep the tape comfortably snug and stand naturally while measuring.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AbzioTheme.accentColor),
              ),
            ],
          ),
        );
      },
    );
  }

  String _methodLabel(MeasurementMethod? method) {
    switch (method) {
      case MeasurementMethod.manual:
        return 'Manual Entry';
      case MeasurementMethod.standard:
        return 'Standard Size';
      case MeasurementMethod.previous:
        return 'Previous Measurements';
      case null:
        return 'Manual Entry';
    }
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: AbzioTheme.cardColor,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AbzioTheme.grey100),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AbzioTheme.textPrimary,
      ),
    );
  }

  double _inchToCm(double value) => value * 2.54;

  double _cmToInch(double value) => value / 2.54;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _MeasurementFieldDefinition {
  final String key;
  final String label;
  final String helpText;
  final double minCm;
  final double maxCm;
  final IconData icon;

  const _MeasurementFieldDefinition({
    required this.key,
    required this.label,
    required this.helpText,
    required this.minCm,
    required this.maxCm,
    required this.icon,
  });
}

class _FutureFeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FutureFeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: AbzioTheme.grey50,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AbzioTheme.accentColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
