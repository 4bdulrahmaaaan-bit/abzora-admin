import 'package:flutter/material.dart';

import '../theme.dart';
import 'tracking_step_widget.dart';

class TrackingTimeline extends StatelessWidget {
  const TrackingTimeline({
    super.key,
    required this.steps,
    required this.progressAnimation,
    required this.pulseAnimation,
  });

  final List<TrackingStepData> steps;
  final Animation<double> progressAnimation;
  final Animation<double> pulseAnimation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const markerHeight = 38.0;
        const rowGap = 34.0;
        final lineHeight = ((steps.length - 1) * (markerHeight + rowGap)).clamp(0, 10000).toDouble();

        return AnimatedBuilder(
          animation: progressAnimation,
          builder: (context, child) {
            return Stack(
              children: [
                Positioned(
                  left: 18,
                  top: markerHeight,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    height: lineHeight,
                    color: context.abzioBorder,
                  ),
                ),
                Positioned(
                  left: 18,
                  top: markerHeight,
                  child: Container(
                    width: 2,
                    height: lineHeight * progressAnimation.value,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Column(
                  children: List.generate(steps.length, (index) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == steps.length - 1 ? 0 : rowGap),
                      child: TrackingStepWidget(
                        step: steps[index],
                        pulseAnimation: pulseAnimation,
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
