import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_shell.dart';
import 'user/home_screen.dart';
import '../utils/app_mode_routes.dart';
import '../widgets/splash/cinematic_timeline.dart';
import '../widgets/splash/gold_dust_particle_layer.dart';
import '../widgets/splash/logo_shimmer_sweep.dart';
import '../widgets/splash/pulsing_gold_glow.dart';

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

class _SplashProfile {
  const _SplashProfile({
    required this.particleDensity,
    required this.shimmerBoost,
    required this.glowBoost,
    required this.fogBoost,
    required this.floatBoost,
  });

  final int particleDensity;
  final double shimmerBoost;
  final double glowBoost;
  final double fogBoost;
  final double floatBoost;
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _totalDuration = Duration(milliseconds: 4700);

  late final AnimationController _controller;
  bool _didHaptic = false;
  bool _didSoundCue = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration)
      ..addListener(_phaseCallbacks)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed &&
            widget.autoNavigate &&
            mounted) {
          _navigateToHome();
        }
      })
      ..forward();
  }

  void _phaseCallbacks() {
    final t = _controller.value;

    if (!_didHaptic && t >= 0.30) {
      _didHaptic = true;
      if (widget.enableHaptics) {
        HapticFeedback.lightImpact();
      }
      if (widget.enableSoundCue && !_didSoundCue) {
        _didSoundCue = true;
        widget.onSoundCue?.call();
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 650),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          final lift =
              Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: lift, child: child),
          );
        },
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_phaseCallbacks)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final shortestSide = screen.shortestSide;
    final logoSize = (shortestSide * 0.34).clamp(160.0, 228.0);
    final title = splashTitleForMode(widget.mode);
    final subtitle =
        widget.mode == AbzioAppMode.customer ||
            widget.mode == AbzioAppMode.unified
        ? 'Premium marketplace and custom clothing'
        : splashSubtitleForMode(widget.mode);
    final asset = brandAssetForMode(widget.mode);

    return Scaffold(
      backgroundColor: const Color(0xFF020202),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final profile = switch (widget.intensity) {
            SplashIntensity.ultraSubtle => const _SplashProfile(
              particleDensity: 48,
              shimmerBoost: 0.88,
              glowBoost: 0.84,
              fogBoost: 0.82,
              floatBoost: 0.78,
            ),
            SplashIntensity.balanced => const _SplashProfile(
              particleDensity: 70,
              shimmerBoost: 1.0,
              glowBoost: 1.0,
              fogBoost: 1.0,
              floatBoost: 1.0,
            ),
            SplashIntensity.moreDramatic => const _SplashProfile(
              particleDensity: 94,
              shimmerBoost: 1.12,
              glowBoost: 1.16,
              fogBoost: 1.12,
              floatBoost: 1.1,
            ),
          };
          final t = _controller.value;

          // Phase map over 4.7s timeline.
          final darkReveal = SplashTimeline.value(
            _controller,
            0.0,
            0.22,
            curve: Curves.easeOutExpo,
          );
          final logoFormation = SplashTimeline.value(
            _controller,
            0.16,
            0.5,
            curve: Curves.easeOutCubic,
          );
          final metallicSweep = SplashTimeline.value(
            _controller,
            0.42,
            0.64,
            curve: Curves.easeInOutCubic,
          );
          final floatMotion = SplashTimeline.value(
            _controller,
            0.58,
            0.84,
            curve: Curves.easeInOutCubic,
          );
          final textReveal = SplashTimeline.value(
            _controller,
            0.68,
            0.9,
            curve: Curves.easeOutExpo,
          );
          final holdPulse = SplashTimeline.value(
            _controller,
            0.86,
            1.0,
            curve: Curves.easeInOutCubic,
          );

          final logoScale =
              0.88 +
              (logoFormation * 0.12) +
              (0.015 * profile.floatBoost * (1 - (floatMotion - 0.5).abs() * 2));
          final logoYFloat = (1 - floatMotion) * (6.0 * profile.floatBoost);
          final glowOpacity =
              (0.10 + (logoFormation * 0.46 * profile.glowBoost) + (holdPulse * 0.12 * profile.glowBoost)).clamp(
                0.0,
                0.72,
              );
          final fogOpacity = (0.14 + darkReveal * 0.24 * profile.fogBoost).clamp(0.0, 0.36);
          final textOffset = 16 * (1 - textReveal);
          final finalFade =
              1 -
              SplashTimeline.value(
                _controller,
                0.94,
                1.0,
                curve: Curves.easeInOutCubic,
              );

          return Opacity(
            opacity: finalFade,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFF030303)),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.08),
                        radius: 1.08,
                        colors: [
                          const Color(
                            0xFF16110A,
                          ).withValues(alpha: 0.08 + darkReveal * 0.18),
                          const Color(0xFF030303),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: fogOpacity,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(-0.2, -0.22),
                            radius: 0.82,
                            colors: [
                              const Color(0xFF70543A).withValues(alpha: 0.10),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: GoldDustParticleLayer(
                    progress: t,
                    density: profile.particleDensity,
                  ),
                ),
                const Positioned.fill(child: CinematicVignette(opacity: 0.58)),
                Align(
                  alignment: const Alignment(0, -0.07),
                  child: Transform.translate(
                    offset: Offset(0, logoYFloat),
                    child: Transform.scale(
                      scale: logoScale,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PulsingGoldGlow(
                            radius: logoSize * 0.78,
                            opacity: glowOpacity,
                            scale: 1 + (holdPulse * 0.04),
                          ),
                          Container(
                            width: logoSize,
                            height: logoSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD7A55E).withValues(
                                    alpha: (0.22 + holdPulse * 0.22) * profile.glowBoost,
                                  ),
                                  blurRadius: 42,
                                  spreadRadius: 1.0,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: ColorFiltered(
                                colorFilter: ColorFilter.mode(
                                  Colors.white.withValues(
                                    alpha: 0.74 + (logoFormation * 0.26),
                                  ),
                                  BlendMode.modulate,
                                ),
                                child: Image.asset(asset, fit: BoxFit.contain),
                              ),
                            ),
                          ),
                          if (metallicSweep > 0)
                            SizedBox(
                              width: logoSize,
                              height: logoSize,
                              child: LogoShimmerSweep(
                                progress: (metallicSweep * profile.shimmerBoost).clamp(0.0, 1.0),
                                size: logoSize,
                                borderRadius: 30,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, 0.46),
                  child: Opacity(
                    opacity: textReveal,
                    child: Transform.translate(
                      offset: Offset(0, textOffset),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.cinzel(
                              color: const Color(0xFFF8D58B),
                              fontSize: (shortestSide * 0.09).clamp(28.0, 44.0),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Opacity(
                            opacity: SplashTimeline.value(
                              _controller,
                              0.76,
                              0.93,
                              curve: Curves.easeOutCubic,
                            ),
                            child: Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: const Color(
                                  0xFFE2C78D,
                                ).withValues(alpha: 0.84),
                                fontSize: (shortestSide * 0.035).clamp(
                                  12.0,
                                  15.5,
                                ),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, -0.07),
                  child: Opacity(
                    opacity: darkReveal * 0.72,
                    child: PulsingGoldGlow(
                      radius: logoSize * 0.16,
                      opacity: 0.9,
                      scale: 0.84 + darkReveal * 0.2,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
