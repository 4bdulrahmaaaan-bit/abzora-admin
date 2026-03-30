import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_shell.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.mode = AbzioAppMode.unified,
  });

  final AbzioAppMode mode;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _glowOpacity;
  late Animation<double> _brandOpacity;
  late Animation<double> _brandTranslate;
  late Animation<double> _taglineOpacity;
  late Animation<double> _taglineTranslate;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.28, curve: Curves.easeOutCubic),
      ),
    );
    _logoScale = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.32, curve: Curves.easeOutCubic),
      ),
    );
    _glowOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.16, 0.42, curve: Curves.easeOutCubic),
      ),
    );
    _brandOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.38, curve: Curves.easeOutCubic),
      ),
    );
    _brandTranslate = Tween<double>(begin: 10, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.38, curve: Curves.easeOutCubic),
      ),
    );
    _taglineOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.44, curve: Curves.easeOutCubic),
      ),
    );
    _taglineTranslate = Tween<double>(begin: 10, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.44, curve: Curves.easeOutCubic),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroLogoSize = (screenHeight * 0.235).clamp(170.0, 228.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: heroLogoSize + 44,
              height: heroLogoSize + 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FadeTransition(
                    opacity: _glowOpacity,
                    child: Container(
                      width: heroLogoSize + 22,
                      height: heroLogoSize + 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AbzioTheme.accentColor.withValues(alpha: 0.16),
                            blurRadius: 54,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: _logoOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: BrandLogo.hero(
                        size: heroLogoSize,
                        radius: heroLogoSize * 0.24,
                        padding: EdgeInsets.all(heroLogoSize * 0.03),
                        assetPath: widget.mode == AbzioAppMode.operations
                            ? 'assets/branding/abzora_partner_icon.png'
                            : 'assets/branding/abzora_customer_icon.png',
                        shadows: [
                          BoxShadow(
                            color: AbzioTheme.accentColor.withValues(alpha: 0.22),
                            blurRadius: 32,
                            spreadRadius: 1,
                            offset: const Offset(0, 14),
                          ),
                          const BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Opacity(
                opacity: _brandOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _brandTranslate.value),
                  child: child,
                ),
              ),
              child: Text(
                widget.mode == AbzioAppMode.operations ? 'ABZORA PARTNER' : 'ABZORA',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: widget.mode == AbzioAppMode.operations ? 30 : 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: widget.mode == AbzioAppMode.operations ? 3.2 : 5.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Opacity(
                opacity: _taglineOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _taglineTranslate.value),
                  child: child,
                ),
              ),
              child: Text(
                widget.mode == AbzioAppMode.operations
                    ? 'Premium operations for vendors and riders'
                    : 'Premium marketplace and custom clothing',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
