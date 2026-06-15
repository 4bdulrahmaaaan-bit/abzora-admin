import 'package:flutter/material.dart';
import '../../../../core/theme/rider_theme.dart';

class RiderProgressTracker extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const RiderProgressTracker({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  static const List<String> _stepLabels = [
    'Profile',
    'Vehicle',
    'KYC',
    'Payouts',
    'Preferences',
    'Policies',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    if (currentStep < 0) return const SizedBox.shrink();

    final totalTrackedSteps = 7;
    
    final percentComplete = ((currentStep) / totalTrackedSteps * 100).clamp(0, 100).toInt();
    final minsRemaining = ((totalTrackedSteps - currentStep) * 1.5).ceil();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RiderTheme.onboardingSurface,
        borderRadius: BorderRadius.circular(RiderTheme.radiusMedium),
        border: Border.all(color: RiderTheme.onboardingElevatedSurface),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: RiderTheme.onboardingGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.speed_rounded, color: RiderTheme.onboardingGold, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile Completion',
                      style: TextStyle(
                        color: RiderTheme.onboardingSecondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$percentComplete%',
                          style: const TextStyle(
                            color: RiderTheme.onboardingPrimaryText,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: RiderTheme.onboardingElevatedSurface,
                            borderRadius: BorderRadius.circular(RiderTheme.radiusSmall),
                          ),
                          child: Text(
                            '~$minsRemaining min left',
                            style: const TextStyle(
                              color: RiderTheme.onboardingSecondaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0,
                end: currentStep / totalTrackedSteps,
              ),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: RiderTheme.onboardingElevatedSurface,
                  valueColor: const AlwaysStoppedAnimation(RiderTheme.onboardingGold),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(totalTrackedSteps, (index) {
                final isCompleted = index < currentStep;
                final isCurrent = index == currentStep;
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    children: [
                      Icon(
                        isCompleted
                            ? Icons.check_circle_rounded
                            : (isCurrent
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked),
                        size: 16,
                        color: isCompleted || isCurrent
                            ? RiderTheme.onboardingGold
                            : RiderTheme.onboardingSecondaryText.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _stepLabels[index],
                        style: TextStyle(
                          color: isCompleted || isCurrent
                              ? RiderTheme.onboardingPrimaryText
                              : RiderTheme.onboardingSecondaryText.withValues(alpha: 0.7),
                          fontWeight: isCurrent
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
