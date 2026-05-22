import 'dart:async';

import 'package:flutter/material.dart';

import '../app_shell.dart';
import 'user/home_screen.dart';

enum SplashIntensity { ultraSubtle, balanced, moreDramatic }

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.mode = AbzioAppMode.unified,
    this.autoNavigate = true,
    this.enableHaptics = true,
    this.enableSoundCue = false,
    this.onSoundCue,
    this.intensity = SplashIntensity.balanced,
  });

  final AbzioAppMode mode;
  final bool autoNavigate;
  final bool enableHaptics;
  final bool enableSoundCue;
  final VoidCallback? onSoundCue;
  final SplashIntensity intensity;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _totalDuration = Duration(milliseconds: 2500);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoNavigate) {
      _timer = Timer(_totalDuration, _navigateToHome);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _splashAsset {
    switch (widget.mode) {
      case AbzioAppMode.vendor:
      case AbzioAppMode.operations:
        return 'assets/branding/abianzo_vendor_splash_1080x1920.png';
      case AbzioAppMode.rider:
        return 'assets/branding/abianzo_rider_splash_1080x1920.png';
      case AbzioAppMode.customer:
      case AbzioAppMode.unified:
        return 'assets/branding/abianzo_customer_splash_1080x1920.png';
    }
  }

  void _navigateToHome() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Center(
        child: SizedBox.expand(
          child: Image(
            image: AssetImage(_splashAsset),
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}
