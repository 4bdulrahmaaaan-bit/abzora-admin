import 'package:flutter/material.dart';
import '../../../../core/vendor/theme/vendor_theme.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onStart;

  const WelcomeScreen({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(
            'Vendor Partner Setup',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: VendorTheme.onboardingPrimaryText,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Complete your business profile and start selling on Abzora.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: VendorTheme.onboardingSecondaryText,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          _buildBadgeItem(Icons.save_outlined, 'Draft Auto Saved'),
          const SizedBox(height: 20),
          _buildBadgeItem(Icons.verified_user_outlined, 'Secure Verification'),
          const SizedBox(height: 20),
          _buildBadgeItem(Icons.flash_on_rounded, 'Faster Approval'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: VendorTheme.onboardingSurface,
              borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
              border: Border.all(color: VendorTheme.onboardingElevatedSurface),
            ),
            child: Column(
              children: [
                Text(
                  'Estimated Setup',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: VendorTheme.onboardingSecondaryText),
                ),
                const SizedBox(height: 4),
                Text(
                  '5–7 Minutes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: VendorTheme.onboardingPrimaryText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Business • Expertise • Portfolio • Finance • KYC • Launch',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: VendorTheme.onboardingSecondaryText.withValues(alpha: 0.5)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: VendorTheme.onboardingGold,
                foregroundColor: VendorTheme.onboardingBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
                ),
                elevation: 0,
              ),
              onPressed: onStart,
              child: const Text(
                'Start Setup',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VendorTheme.onboardingSuccess.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: VendorTheme.onboardingSuccess, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: VendorTheme.onboardingPrimaryText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
