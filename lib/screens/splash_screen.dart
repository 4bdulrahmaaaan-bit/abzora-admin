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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _totalDuration = Duration(milliseconds: 1500);
  static const _logoAsset = 'assets/branding/abzora_partner_icon.png';
  Timer? _timer;
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration);
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(curve);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(curve);
    _controller.forward();
    if (widget.autoNavigate) {
      _timer = Timer(_totalDuration, _navigateToHome);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
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
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: const Image(
              image: AssetImage(_logoAsset),
              width: 168,
              height: 168,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
        ),
      ),
    );
  }
}
