import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../models/rider_signup_model.dart';

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
      children: [
        TextFormField(
          initialValue: model.referral,
          decoration: inputDecorationBuilder('Referral Code (optional)'),
          onChanged: (v) => onUpdate(model.copyWith(referral: v)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: WorkType.values.map((w) {
            return ChoiceChip(
              label: Text(w == WorkType.fullTime ? 'Full-time' : 'Part-time'),
              selected: model.workType == w,
              selectedColor: const Color(0xFFD4AF37),
              onSelected: (selected) => onUpdate(model.copyWith(workType: w)),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: ['Morning', 'Afternoon', 'Night'].map((shift) {
            return ChoiceChip(
              label: Text(shift),
              selected: model.shift == shift,
              selectedColor: const Color(0xFFD4AF37),
              onSelected: (selected) => onUpdate(model.copyWith(shift: shift)),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Zone Radius'),
            Expanded(
              child: Slider(
                value: model.zoneRadiusKm.clamp(1, 20),
                min: 1,
                max: 20,
                divisions: 19,
                label: '${model.zoneRadiusKm.toStringAsFixed(0)} km',
                onChanged: (v) => onUpdate(model.copyWith(zoneRadiusKm: v)),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(24),
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
      ],
    );
  }
}
