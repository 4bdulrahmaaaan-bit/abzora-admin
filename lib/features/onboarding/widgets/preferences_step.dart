import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../models/rider_signup_model.dart';
import '../../../../core/theme/rider_theme.dart';

class PreferencesStep extends StatelessWidget {
  final RiderSignupModel model;
  final ValueChanged<RiderSignupModel> onUpdate;
  final InputDecoration Function(String) inputDecorationBuilder;

  const PreferencesStep({
    super.key,
    required this.model,
    required this.onUpdate,
    required this.inputDecorationBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Work Schedule',
          style: TextStyle(
            color: RiderTheme.onboardingPrimaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: WorkType.values.map((w) {
            final selected = model.workType == w;
            return ChoiceChip(
              label: Text(
                w == WorkType.fullTime ? 'Full-Time' : 'Part-Time',
                style: TextStyle(
                  color: selected ? RiderTheme.onboardingBackground : RiderTheme.onboardingPrimaryText,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              selected: selected,
              selectedColor: RiderTheme.onboardingGold,
              backgroundColor: RiderTheme.onboardingElevatedSurface,
              side: BorderSide(
                color: selected ? RiderTheme.onboardingGold : RiderTheme.onboardingElevatedSurface,
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RiderTheme.radiusSmall)),
              onSelected: (selected) => onUpdate(model.copyWith(workType: w)),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Preferred Shift',
          style: TextStyle(
            color: RiderTheme.onboardingPrimaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: ['Morning', 'Afternoon', 'Night'].map((shift) {
            final selected = model.shift == shift;
            return ChoiceChip(
              label: Text(
                shift,
                style: TextStyle(
                  color: selected ? RiderTheme.onboardingBackground : RiderTheme.onboardingPrimaryText,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              selected: selected,
              selectedColor: RiderTheme.onboardingGold,
              backgroundColor: RiderTheme.onboardingElevatedSurface,
              side: BorderSide(
                color: selected ? RiderTheme.onboardingGold : RiderTheme.onboardingElevatedSurface,
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RiderTheme.radiusSmall)),
              onSelected: (selected) => onUpdate(model.copyWith(shift: shift)),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        const Text(
          'Delivery Zone',
          style: TextStyle(
            color: RiderTheme.onboardingPrimaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RiderTheme.onboardingElevatedSurface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(RiderTheme.radiusSmall),
            border: Border.all(color: RiderTheme.onboardingElevatedSurface),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Zone Radius', style: TextStyle(color: RiderTheme.onboardingPrimaryText, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text(
                    '${model.zoneRadiusKm.toStringAsFixed(0)} km',
                    style: const TextStyle(color: RiderTheme.onboardingGold, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                value: model.zoneRadiusKm.clamp(1, 20),
                min: 1,
                max: 20,
                divisions: 19,
                activeColor: RiderTheme.onboardingGold,
                inactiveColor: RiderTheme.onboardingElevatedSurface,
                onChanged: (v) => onUpdate(model.copyWith(zoneRadiusKm: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(RiderTheme.radiusMedium),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: RiderTheme.onboardingElevatedSurface),
                borderRadius: BorderRadius.circular(RiderTheme.radiusMedium),
              ),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    model.zoneLat ?? 12.9716,
                    model.zoneLng ?? 77.5946,
                  ),
                  zoom: 11,
                ),
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                onTap: (point) {
                  onUpdate(
                    model.copyWith(
                      zoneLat: point.latitude,
                      zoneLng: point.longitude,
                    ),
                  );
                },
                markers: {
                  if (model.zoneLat != null && model.zoneLng != null)
                    Marker(
                      markerId: const MarkerId('zone'),
                      position: LatLng(model.zoneLat!, model.zoneLng!),
                    ),
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Referral',
          style: TextStyle(
            color: RiderTheme.onboardingPrimaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: model.referral,
          decoration: inputDecorationBuilder('Referral Code (Optional)'),
          style: const TextStyle(color: RiderTheme.onboardingPrimaryText),
          onChanged: (v) => onUpdate(model.copyWith(referral: v)),
        ),
      ],
    );
  }
}
