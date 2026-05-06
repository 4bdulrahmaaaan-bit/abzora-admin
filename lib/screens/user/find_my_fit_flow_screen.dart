import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FindMyFitFlowScreen extends StatefulWidget {
  const FindMyFitFlowScreen({super.key});

  @override
  State<FindMyFitFlowScreen> createState() => _FindMyFitFlowScreenState();
}

class _FindMyFitFlowScreenState extends State<FindMyFitFlowScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  double _heightCm = 170;
  double _weightKg = 65;
  String _bodyType = 'Regular';
  String _fitPreference = 'Regular';
  bool _saveDone = false;

  late final AnimationController _resultController;
  late final Animation<double> _resultSizeOpacity;
  late final Animation<double> _resultSizeScale;
  late final Animation<double> _resultConfidenceOpacity;
  late final Animation<Offset> _resultConfidenceOffset;
  late final Animation<double> _resultCard1Opacity;
  late final Animation<double> _resultCard2Opacity;
  late final Animation<double> _resultCard3Opacity;

  static const _bodyTypes = ['Slim', 'Regular', 'Athletic', 'Broad'];
  static const _fitPrefs = ['Tight', 'Regular', 'Loose'];
  static const _flowCurve = Cubic(0.4, 0.0, 0.2, 1);

  @override
  void initState() {
    super.initState();
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _resultSizeOpacity = CurvedAnimation(
      parent: _resultController,
      curve: const Interval(0.00, 0.45, curve: _flowCurve),
    );
    _resultSizeScale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _resultController,
        curve: const Interval(0.00, 0.45, curve: _flowCurve),
      ),
    );
    _resultConfidenceOpacity = CurvedAnimation(
      parent: _resultController,
      curve: const Interval(0.18, 0.62, curve: _flowCurve),
    );
    _resultConfidenceOffset = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _resultController,
        curve: const Interval(0.18, 0.62, curve: _flowCurve),
      ),
    );
    _resultCard1Opacity = CurvedAnimation(
      parent: _resultController,
      curve: const Interval(0.40, 0.72, curve: _flowCurve),
    );
    _resultCard2Opacity = CurvedAnimation(
      parent: _resultController,
      curve: const Interval(0.50, 0.82, curve: _flowCurve),
    );
    _resultCard3Opacity = CurvedAnimation(
      parent: _resultController,
      curve: const Interval(0.60, 0.94, curve: _flowCurve),
    );
  }

  @override
  void dispose() {
    _resultController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF9),
      appBar: AppBar(
        title: const Text('Find My Fit'),
        backgroundColor: const Color(0xFFFFFDF9),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              _progressBar(),
              const SizedBox(height: 14),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 340),
                  switchInCurve: _flowCurve,
                  switchOutCurve: _flowCurve,
                  transitionBuilder: (child, animation) {
                    final inOffset = Tween<Offset>(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: _flowCurve));
                    final outOpacity = Tween<double>(begin: 1, end: 0.92).animate(animation);
                    return FadeTransition(
                      opacity: outOpacity,
                      child: SlideTransition(position: inOffset, child: child),
                    );
                  },
                  child: _buildStep(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressBar() {
    final progress = (_step + 1) / 6;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 4,
        color: const Color(0xFFEDE5D7),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: progress),
          duration: const Duration(milliseconds: 300),
          curve: _flowCurve,
          builder: (context, value, child) {
            return Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE8D2A7), Color(0xFFB8925A)],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _introStep();
      case 1:
        return _sliderStep(
          key: const ValueKey('height'),
          title: 'Your Height',
          unit: 'cm',
          value: _heightCm,
          min: 120,
          max: 210,
          onChanged: (v) => setState(() => _heightCm = v),
          buttonText: 'Continue',
          onPressed: _next,
        );
      case 2:
        return _sliderStep(
          key: const ValueKey('weight'),
          title: 'Your Weight',
          unit: 'kg',
          value: _weightKg,
          min: 30,
          max: 150,
          onChanged: (v) => setState(() => _weightKg = v),
          buttonText: 'Continue',
          onPressed: _next,
        );
      case 3:
        return _bodyTypeStep();
      case 4:
        return _fitPreferenceStep();
      default:
        return _resultStep();
    }
  }

  Widget _introStep() {
    return Container(
      key: const ValueKey('intro'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF6E9CE), Color(0xFFEAD7AF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.auto_awesome_outlined, color: Color(0xFF8D744A), size: 34),
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Find Your Perfect Fit',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Get accurate size in under 10 seconds',
            style: TextStyle(fontSize: 16, color: Color(0xFF6D6559), height: 1.5),
          ),
          const SizedBox(height: 14),
          const Text(
            'No measurements needed',
            style: TextStyle(fontSize: 14, color: Color(0xFF8D836F)),
          ),
          const Spacer(),
          _primaryButton(text: 'Start', onPressed: _next),
        ],
      ),
    );
  }

  Widget _sliderStep({
    required Key key,
    required String title,
    required String unit,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '${value.round()} $unit',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Color(0xFF8D744A)),
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: _flowCurve,
                  switchOutCurve: _flowCurve,
                  transitionBuilder: (child, animation) {
                    final y = Tween<Offset>(
                      begin: const Offset(0, 0.16),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: y, child: child),
                    );
                  },
                  child: Text(
                    'Fine tune: ${value.round()} $unit',
                    key: ValueKey<int>(value.round()),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF8D836F)),
                  ),
                ),
                Slider(
                  value: value,
                  min: min,
                  max: max,
                  activeColor: const Color(0xFFB8925A),
                  inactiveColor: const Color(0xFFEFE8DB),
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
          const Spacer(),
          _primaryButton(text: buttonText, onPressed: onPressed),
        ],
      ),
    );
  }

  Widget _bodyTypeStep() {
    return Container(
      key: const ValueKey('bodyType'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Body Type', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ..._bodyTypes.map((type) {
            final selected = _bodyType == type;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _bodyType = type);
                },
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFF6E9CE) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? const Color(0xFFC9A36A) : const Color(0x00FFFFFF),
                      width: selected ? 1.1 : 0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: selected ? const Color(0x26C9A36A) : const Color(0x12000000),
                        blurRadius: selected ? 16 : 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 1, end: selected ? 1.05 : 1),
                        duration: const Duration(milliseconds: 220),
                        curve: _flowCurve,
                        builder: (context, scale, iconChild) {
                          return Transform.scale(scale: scale, child: iconChild);
                        },
                        child: Icon(Icons.accessibility_new_outlined, color: selected ? const Color(0xFF8D744A) : const Color(0xFF7D776E)),
                      ),
                      const SizedBox(width: 12),
                      Text(type, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          _primaryButton(text: 'Continue', onPressed: _next),
        ],
      ),
    );
  }

  Widget _fitPreferenceStep() {
    return Container(
      key: const ValueKey('fitPref'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How do you like your fit?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _fitPrefs.map((pref) {
              final selected = _fitPreference == pref;
            return ChoiceChip(
              label: Text(pref),
              selected: selected,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _fitPreference = pref);
              },
              selectedColor: const Color(0xFFF1DFC0),
              backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFF7D633A) : const Color(0xFF6B6458),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              );
            }).toList(),
          ),
          const Spacer(),
          _primaryButton(text: 'Analyze Fit', onPressed: _next),
        ],
      ),
    );
  }

  Widget _resultStep() {
    final recommendation = _recommendSize();
    final confidence = _confidenceLabel();
    final note = _fitNote();
    return Container(
      key: const ValueKey('result'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Fit Recommendation', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF7EEDC), Color(0xFFEEE0C2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeTransition(
                  opacity: _resultSizeOpacity,
                  child: ScaleTransition(
                    scale: _resultSizeScale,
                    child: Text(recommendation, style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w700, height: 1)),
                  ),
                ),
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: _resultConfidenceOpacity,
                  child: SlideTransition(
                    position: _resultConfidenceOffset,
                    child: Text(confidence, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 4),
                FadeTransition(
                  opacity: _resultCard1Opacity,
                  child: Text(note, style: const TextStyle(color: Color(0xFF6D6559), height: 1.5)),
                ),
                const SizedBox(height: 6),
                FadeTransition(
                  opacity: _resultCard2Opacity,
                  child: const Text('Based on similar users', style: TextStyle(fontSize: 13, color: Color(0xFF8D836F))),
                ),
              ],
            ),
          ),
          const Spacer(),
          FadeTransition(
            opacity: _resultCard3Opacity,
            child: _primaryButton(
              text: _saveDone ? 'Saved' : 'Save Fit Profile',
              trailingCheck: _saveDone,
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() => _saveDone = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fit profile saved')),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('Adjust Inputs'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String text,
    required VoidCallback onPressed,
    bool trailingCheck = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1, end: 1),
        duration: const Duration(milliseconds: 120),
        builder: (context, value, child) {
          return _PressableButton(
            text: text,
            onPressed: onPressed,
            trailingCheck: trailingCheck,
          );
        },
      ),
    );
  }

  void _next() {
    if (_step < 5) {
      HapticFeedback.selectionClick();
      setState(() {
        _step += 1;
        if (_step == 5) {
          _resultController.forward(from: 0);
        }
      });
    }
  }

  String _recommendSize() {
    final score = _heightCm * 0.45 + _weightKg * 0.55;
    if (score < 95) return 'S';
    if (score < 120) return 'M';
    if (score < 145) return 'L';
    return 'XL';
  }

  String _confidenceLabel() {
    if (_bodyType == 'Regular' && _fitPreference == 'Regular') return 'High confidence';
    return 'Good confidence';
  }

  String _fitNote() {
    if (_fitPreference == 'Tight') return 'A close-cut fit is recommended for your profile.';
    if (_fitPreference == 'Loose') return 'A relaxed silhouette will feel best on you.';
    return 'Regular fit recommended';
  }
}

class _PressableButton extends StatefulWidget {
  const _PressableButton({
    required this.text,
    required this.onPressed,
    this.trailingCheck = false,
  });

  final String text;
  final VoidCallback onPressed;
  final bool trailingCheck;

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onPressed();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: const Cubic(0.4, 0.0, 0.2, 1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: const Cubic(0.4, 0.0, 0.2, 1),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    widget.text,
                    key: ValueKey<String>(widget.text),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
                if (widget.trailingCheck) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
