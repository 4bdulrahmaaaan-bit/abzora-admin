import 'package:flutter/material.dart';
import '../../../models/rider_signup_model.dart';

class ReviewStep extends StatelessWidget {
  final RiderSignupModel model;

  const ReviewStep({
    super.key,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    final progress = [
      ('Personal Details', model.fullName.isNotEmpty),
      ('Vehicle Details', model.vehicleNumber.isNotEmpty),
      ('KYC', model.aadhaar.isNotEmpty && model.pan.isNotEmpty),
      ('Bank Verification', model.accountNumber.isNotEmpty),
    ];

    return Column(
      children: [
        ...progress.map((e) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: e.$2
                        ? Colors.green.withValues(alpha: 0.18)
                        : const Color(0xFFD4AF37).withValues(alpha: 0.16),
                  ),
                  child: Icon(
                    e.$2 ? Icons.check_rounded : Icons.pending_outlined,
                    color: e.$2
                        ? const Color(0xFF30D158)
                        : const Color(0xFFF5D76E),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(e.$1)),
                Text(
                  e.$2 ? 'Completed' : 'Pending',
                  style: TextStyle(
                    color: e.$2
                        ? const Color(0xFF30D158)
                        : const Color(0xFFF5D76E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: progress.where((p) => p.$2).length / progress.length,
          color: const Color(0xFFD4AF37),
        ),
      ],
    );
  }
}
