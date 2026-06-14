import 'package:flutter/material.dart';

class RiderProgressTracker extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const RiderProgressTracker({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  static const List<String> _stepLabels = [
    'Profile',
    'Vehicle',
    'KYC',
    'Payouts',
    'Preferences',
    'Policies',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    if (currentStep < 0) return const SizedBox.shrink();

    final totalTrackedSteps = 7;
    
    final percentComplete = ((currentStep) / totalTrackedSteps * 100).clamp(0, 100).toInt();
    final minsRemaining = ((totalTrackedSteps - currentStep) * 1.5).ceil();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: const Color(0xFF121212),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$percentComplete% Complete',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              Text(
                '~$minsRemaining Min Remaining',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0,
                end: currentStep / totalTrackedSteps,
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFD4AF37)),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(totalTrackedSteps, (index) {
                final isCompleted = index < currentStep;
                final isCurrent = index == currentStep;
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    children: [
                      Icon(
                        isCompleted
                            ? Icons.check_circle_rounded
                            : (isCurrent
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked),
                        size: 16,
                        color: isCompleted || isCurrent
                            ? const Color(0xFFD4AF37)
                            : Colors.white38,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _stepLabels[index],
                        style: TextStyle(
                          color: isCompleted || isCurrent
                              ? Colors.white
                              : Colors.white38,
                          fontWeight: isCurrent
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13,
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
