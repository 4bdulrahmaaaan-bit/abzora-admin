import 'package:flutter/material.dart';
import '../../../models/rider_signup_model.dart';
import '../../../../core/theme/rider_theme.dart';

class ProfileStep extends StatelessWidget {
  final RiderSignupModel model;
  final String? userPhone;
  final ValueChanged<RiderSignupModel> onUpdate;
  final VoidCallback onPickImage;
  final InputDecoration Function(String) inputDecorationBuilder;
  final Widget Function(String, String, String?, VoidCallback)
  visualCardBuilder;
  final Widget Function(List<Widget>) staggerColumnBuilder;

  const ProfileStep({
    super.key,
    required this.model,
    required this.userPhone,
    required this.onUpdate,
    required this.onPickImage,
    required this.inputDecorationBuilder,
    required this.visualCardBuilder,
    required this.staggerColumnBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[
      _buildReadOnlyField(
        label: 'Registered Phone Number',
        value: userPhone ?? model.phone,
        icon: Icons.verified_user_rounded,
        iconColor: RiderTheme.onboardingSuccess,
      ),
      const SizedBox(height: 16),
      TextFormField(
        initialValue: model.fullName,
        decoration: inputDecorationBuilder('Full Name (As per Govt ID)'),
        style: const TextStyle(color: RiderTheme.onboardingPrimaryText),
        onChanged: (v) => onUpdate(model.copyWith(fullName: v)),
      ),
      const SizedBox(height: 16),
      TextFormField(
        initialValue: model.email,
        decoration: inputDecorationBuilder('Email Address'),
        style: const TextStyle(color: RiderTheme.onboardingPrimaryText),
        keyboardType: TextInputType.emailAddress,
        onChanged: (v) => onUpdate(model.copyWith(email: v)),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: 'Chennai',
        hint: const Text(
          'Chennai only',
          style: TextStyle(color: RiderTheme.onboardingSecondaryText),
        ),
        dropdownColor: RiderTheme.onboardingElevatedSurface,
        style: const TextStyle(color: RiderTheme.onboardingPrimaryText),
        icon: const Icon(
          Icons.arrow_drop_down_rounded,
          color: RiderTheme.onboardingSecondaryText,
        ),
        items: const [
          DropdownMenuItem(value: 'Chennai', child: Text('Chennai')),
        ],
        onChanged: (_) => onUpdate(model.copyWith(city: 'Chennai')),
        decoration: inputDecorationBuilder('Operating City'),
      ),
      const SizedBox(height: 24),
      visualCardBuilder(
        'Profile Photo',
        'A clear photo of your face for your rider profile.',
        model.profilePhotoPath,
        onPickImage,
      ),
    ];

    return staggerColumnBuilder(content);
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: RiderTheme.onboardingBackground,
        borderRadius: BorderRadius.circular(RiderTheme.radiusSmall),
        border: Border.all(color: RiderTheme.onboardingElevatedSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: RiderTheme.onboardingSecondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 4),
              Text(
                'Verified',
                style: TextStyle(
                  color: iconColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: RiderTheme.onboardingPrimaryText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
