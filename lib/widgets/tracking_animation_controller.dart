import 'package:flutter/material.dart';

class TrackingAnimationController {
  TrackingAnimationController({
    required TickerProvider vsync,
    required this.totalSteps,
  })  : progressController = AnimationController(
          vsync: vsync,
          duration: const Duration(milliseconds: 900),
        ),
        pulseController = AnimationController(
          vsync: vsync,
          duration: const Duration(milliseconds: 1100),
        ) {
    progress = CurvedAnimation(
      parent: progressController,
      curve: Curves.easeOutCubic,
    );
    pulse = Tween<double>(begin: 0.94, end: 1.08).animate(
      CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
    );
  }

  final int totalSteps;
  final AnimationController progressController;
  final AnimationController pulseController;
  late Animation<double> progress;
  late Animation<double> pulse;
  double _targetProgress = 0;

  double get targetProgress => _targetProgress;

  void animateToStep(int currentStep) {
    final normalized = totalSteps <= 1 ? 1.0 : (currentStep / (totalSteps - 1)).clamp(0.0, 1.0);
    _targetProgress = normalized;
    progress = Tween<double>(
      begin: 0,
      end: normalized,
    ).animate(
      CurvedAnimation(parent: progressController, curve: Curves.easeOutCubic),
    );
    progressController.forward(from: 0);

    if (currentStep >= totalSteps - 1) {
      pulseController.stop();
      pulseController.value = 1;
    } else {
      pulseController.repeat(reverse: true);
    }
  }

  void dispose() {
    progressController.dispose();
    pulseController.dispose();
  }
}
