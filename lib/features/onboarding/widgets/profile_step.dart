import 'package:flutter/material.dart';
import '../../../models/rider_signup_model.dart';

class ProfileStep extends StatelessWidget {
  final RiderSignupModel model;
  final String? userPhone;
  final ValueChanged<RiderSignupModel> onUpdate;
  final VoidCallback onPickImage;
  final InputDecoration Function(String) inputDecorationBuilder;
  final Widget Function(bool) statusPillBuilder;
  final Widget Function(List<Widget>) staggerColumnBuilder;

  const ProfileStep({
    super.key,
    required this.model,
    required this.userPhone,
    required this.onUpdate,
    required this.onPickImage,
    required this.inputDecorationBuilder,
    required this.statusPillBuilder,
    required this.staggerColumnBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[
      TextFormField(
        initialValue: userPhone ?? model.phone,
        readOnly: true,
        decoration: inputDecorationBuilder(
          'Phone Number',
        ).copyWith(fillColor: const Color(0xFF1A1A1A), filled: true),
      ),
      const SizedBox(height: 10),
      TextFormField(
        initialValue: model.fullName,
        decoration: inputDecorationBuilder('Full Name'),
        onChanged: (v) => onUpdate(model.copyWith(fullName: v)),
      ),
      const SizedBox(height: 10),
      TextFormField(
        initialValue: model.email,
        decoration: inputDecorationBuilder('Email Address'),
        onChanged: (v) => onUpdate(model.copyWith(email: v)),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: model.city.isEmpty ? null : model.city,
        hint: const Text('Select City'),
        items: const [
          'Bengaluru',
          'Mumbai',
          'Delhi',
          'Hyderabad',
        ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => onUpdate(model.copyWith(city: v ?? '')),
        decoration: inputDecorationBuilder(''),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: statusPillBuilder(model.profilePhotoPath != null)),
          TextButton(onPressed: onPickImage, child: const Text('Upload')),
        ],
      ),
    ];
    
    return staggerColumnBuilder(content);
  }
}
