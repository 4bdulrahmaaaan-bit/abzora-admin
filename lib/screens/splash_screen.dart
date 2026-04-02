import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_shell.dart';
import '../widgets/brand_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({
    super.key,
    this.mode = AbzioAppMode.unified,
  });

  final AbzioAppMode mode;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final logoSize = (screenHeight * 0.20).clamp(148.0, 160.0);
    final title = mode == AbzioAppMode.operations ? 'ABZORA PARTNER' : 'ABZORA';
    final subtitle = mode == AbzioAppMode.operations
        ? 'Premium operations for vendors and riders'
        : 'Premium marketplace and custom clothing';
    final asset = mode == AbzioAppMode.operations
        ? 'assets/branding/abzora_partner_icon.png'
        : 'assets/branding/abzora_customer_icon.png';

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Align(
        alignment: const Alignment(0, -0.10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(
              size: logoSize,
              radius: 20,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              shadows: const [],
              gradient: null,
              assetPath: asset,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: const Color(0xFFFFFFFF),
                fontSize: mode == AbzioAppMode.operations ? 30 : 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFFAAAAAA),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
