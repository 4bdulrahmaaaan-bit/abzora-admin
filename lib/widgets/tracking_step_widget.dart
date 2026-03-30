import 'package:flutter/material.dart';

import '../theme.dart';

class TrackingStepData {
  const TrackingStepData({
    required this.title,
    required this.timestampLabel,
    required this.icon,
    required this.state,
  });

  final String title;
  final String timestampLabel;
  final IconData icon;
  final TrackingStepState state;
}

enum TrackingStepState { completed, current, upcoming }

class TrackingStepWidget extends StatelessWidget {
  const TrackingStepWidget({
    super.key,
    required this.step,
    required this.pulseAnimation,
  });

  final TrackingStepData step;
  final Animation<double> pulseAnimation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = step.state == TrackingStepState.completed;
    final isCurrent = step.state == TrackingStepState.current;
    final color = isCompleted
        ? const Color(0xFF2E7D32)
        : isCurrent
            ? AbzioTheme.accentColor
            : context.abzioSecondaryText.withValues(alpha: 0.55);

    final marker = Container(
      height: 38,
      width: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted || isCurrent ? color.withValues(alpha: isCompleted ? 1 : 0.14) : context.abzioMuted,
        border: Border.all(
          color: isCompleted || isCurrent ? color : context.abzioBorder,
          width: 1.4,
        ),
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : Icon(
                step.icon,
                color: isCurrent ? color : context.abzioSecondaryText,
                size: 18,
              ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isCurrent
            ? ScaleTransition(scale: pulseAnimation, child: marker)
            : marker,
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isCurrent || isCompleted ? AbzioTheme.textPrimary : context.abzioSecondaryText,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.timestampLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isCurrent ? color : context.abzioSecondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
