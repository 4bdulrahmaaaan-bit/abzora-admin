import 'package:flutter/material.dart';
import '../../../../core/vendor/theme/vendor_theme.dart';

class VendorOnboardingSuccessScreen extends StatelessWidget {
  const VendorOnboardingSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VendorTheme.onboardingBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: VendorTheme.onboardingSuccess.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: VendorTheme.onboardingSuccess,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Application Submitted',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: VendorTheme.onboardingPrimaryText,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'We are reviewing your details. You will be notified once the process is complete.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: VendorTheme.onboardingSecondaryText,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: VendorTheme.onboardingSurface,
                  borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
                  border: Border.all(color: VendorTheme.onboardingElevatedSurface),
                ),
                child: Column(
                  children: [
                    _buildTimelineRow('Application Submitted', true),
                    _buildTimelineRow('OCR Verification', true),
                    _buildTimelineRow('Risk & Compliance Review', false),
                    _buildTimelineRow('Store Approval', false),
                    _buildTimelineRow('Marketplace Activation', false, isLast: true),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VendorTheme.onboardingGold,
                    foregroundColor: VendorTheme.onboardingBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/ops', (route) => false),
                  child: const Text(
                    'Return to Dashboard',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineRow(String title, bool isCompleted, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? VendorTheme.onboardingSuccess : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? VendorTheme.onboardingSuccess : VendorTheme.onboardingElevatedSurface,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: VendorTheme.onboardingBackground)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isCompleted ? VendorTheme.onboardingSuccess : VendorTheme.onboardingElevatedSurface,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              title,
              style: TextStyle(
                color: isCompleted ? VendorTheme.onboardingPrimaryText : VendorTheme.onboardingSecondaryText,
                fontSize: 15,
                fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
