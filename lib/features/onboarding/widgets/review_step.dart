import 'package:flutter/material.dart';
import '../../../models/rider_signup_model.dart';
import '../../../../core/theme/rider_theme.dart';

class ReviewStep extends StatelessWidget {
  final RiderSignupModel model;

  const ReviewStep({
    super.key,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    final progress = [
      ('Personal Details', model.fullName.isNotEmpty && model.email.isNotEmpty),
      ('Vehicle Details', model.vehicleNumber.isNotEmpty),
      ('Identity KYC', model.aadhaar.isNotEmpty && model.pan.isNotEmpty),
      ('Bank Verification', model.accountNumber.isNotEmpty),
      ('Agreements', model.acceptedTerms && model.signature.isNotEmpty),
    ];

    final completedCount = progress.where((p) => p.$2).length;
    final totalCount = progress.length;
    final percent = completedCount / totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: RiderTheme.onboardingElevatedSurface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(RiderTheme.radiusMedium),
            border: Border.all(color: RiderTheme.onboardingElevatedSurface),
          ),
          child: Column(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: percent),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return CircularProgressIndicator(
                          value: value,
                          strokeWidth: 8,
                          backgroundColor: RiderTheme.onboardingElevatedSurface,
                          valueColor: AlwaysStoppedAnimation(
                            value == 1.0 ? RiderTheme.onboardingSuccess : RiderTheme.onboardingGold,
                          ),
                        );
                      },
                    ),
                    Center(
                      child: Text(
                        '${(percent * 100).toInt()}%',
                        style: const TextStyle(
                          color: RiderTheme.onboardingPrimaryText,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                percent == 1.0 ? 'Ready to Submit' : 'Application Incomplete',
                style: TextStyle(
                  color: percent == 1.0 ? RiderTheme.onboardingSuccess : RiderTheme.onboardingWarning,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                percent == 1.0 
                    ? 'All required details are verified.' 
                    : 'Complete pending sections to continue.',
                style: const TextStyle(
                  color: RiderTheme.onboardingSecondaryText,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Checklist',
          style: TextStyle(
            color: RiderTheme.onboardingPrimaryText,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...progress.map((e) {
          final isComplete = e.$2;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: RiderTheme.onboardingBackground,
              borderRadius: BorderRadius.circular(RiderTheme.radiusSmall),
              border: Border.all(
                color: isComplete 
                    ? RiderTheme.onboardingSuccess.withValues(alpha: 0.3)
                    : RiderTheme.onboardingElevatedSurface,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isComplete
                        ? RiderTheme.onboardingSuccess.withValues(alpha: 0.15)
                        : RiderTheme.onboardingElevatedSurface,
                  ),
                  child: Icon(
                    isComplete ? Icons.check_rounded : Icons.pending_outlined,
                    color: isComplete ? RiderTheme.onboardingSuccess : RiderTheme.onboardingSecondaryText,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    e.$1,
                    style: TextStyle(
                      color: RiderTheme.onboardingPrimaryText,
                      fontWeight: isComplete ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  isComplete ? 'Verified' : 'Pending',
                  style: TextStyle(
                    color: isComplete ? RiderTheme.onboardingSuccess : RiderTheme.onboardingWarning,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
