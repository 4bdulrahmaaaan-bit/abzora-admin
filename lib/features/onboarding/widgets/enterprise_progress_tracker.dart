import 'package:flutter/material.dart';
import '../../../../core/vendor/theme/vendor_theme.dart';

class EnterpriseProgressTracker extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const EnterpriseProgressTracker({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  static const List<String> _stepLabels = [
    'Business',
    'Expertise',
    'Portfolio',
    'Finance',
    'KYC',
    'Launch',
  ];

  @override
  Widget build(BuildContext context) {
    if (currentStep < 0) return const SizedBox.shrink();

    final percentComplete = ((currentStep) / totalSteps * 100).clamp(0, 100).toInt();
    final minsRemaining = ((totalSteps - currentStep) * 1.2).ceil();

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VendorTheme.onboardingSurface,
        borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
        border: Border.all(color: VendorTheme.onboardingElevatedSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Completion $percentComplete%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: VendorTheme.onboardingPrimaryText,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Step ${currentStep + 1} of $totalSteps',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: VendorTheme.onboardingSecondaryText,
                        ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '~$minsRemaining Minutes Remaining',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: VendorTheme.onboardingSecondaryText,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0,
                end: currentStep / totalSteps,
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: VendorTheme.onboardingElevatedSurface,
                  valueColor: const AlwaysStoppedAnimation(VendorTheme.onboardingGold),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(totalSteps, (index) {
                final isCompleted = index < currentStep;
                final isCurrent = index == currentStep;
                
                Color bgColor = Colors.transparent;
                Color borderColor = Colors.transparent;
                Color textColor = VendorTheme.onboardingSecondaryText.withValues(alpha: 0.5);
                IconData icon = Icons.circle_outlined;
                Color iconColor = textColor;
                
                if (isCompleted) {
                  bgColor = VendorTheme.onboardingGold.withValues(alpha: 0.1);
                  borderColor = VendorTheme.onboardingGold.withValues(alpha: 0.3);
                  textColor = VendorTheme.onboardingGold;
                  icon = Icons.check_circle_rounded;
                  iconColor = VendorTheme.onboardingGold;
                } else if (isCurrent) {
                  bgColor = VendorTheme.onboardingSurface;
                  borderColor = VendorTheme.onboardingGold;
                  textColor = VendorTheme.onboardingPrimaryText;
                  icon = Icons.radio_button_checked;
                  iconColor = VendorTheme.onboardingGold;
                }

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 14, color: iconColor),
                      const SizedBox(width: 6),
                      Text(
                        _stepLabels[index],
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: textColor,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
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
