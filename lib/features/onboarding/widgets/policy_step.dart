import 'package:flutter/material.dart';
import '../../../models/rider_signup_model.dart';

class PolicyStep extends StatelessWidget {
  final RiderSignupModel model;
  final ValueChanged<RiderSignupModel> onUpdate;
  final InputDecoration Function(String) inputDecorationBuilder;

  const PolicyStep({
    super.key,
    required this.model,
    required this.onUpdate,
    required this.inputDecorationBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          height: 150,
          child: SingleChildScrollView(
            child: Text(
              'By joining Abianzo Rider, you agree to service standards, customer safety policies, payout terms, and data processing clauses for verification and operations.',
            ),
          ),
        ),
        CheckboxListTile(
          value: model.acceptedTerms,
          onChanged: (v) => onUpdate(model.copyWith(acceptedTerms: v ?? false)),
          title: const Text('I agree to all terms and policies'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        TextFormField(
          initialValue: model.signature,
          decoration: inputDecorationBuilder(
            'Digital Signature (type full name)',
          ),
          onChanged: (v) => onUpdate(model.copyWith(signature: v)),
        ),
      ],
    );
  }
}
