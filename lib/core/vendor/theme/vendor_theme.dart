import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium Vendor App Operating System Theme
class VendorTheme {
  // Brand Colors
  static const Color primary = Color(0xFF13110F); // Deep luxury black
  static const Color secondary = Color(0xFFC2A15E); // Premium gold
  static const Color background = Color(0xFFFBF9F6); // Soft premium off-white
  static const Color card = Color(0xFFFFFFFF); // Pure white cards

  // Functional Colors
  static const Color success = Color(0xFF238E5A);
  static const Color warning = Color(0xFFD39A00);
  static const Color error = Color(0xFFD24B4B);
  static const Color info = Color(0xFF3366FF);

  // Grey Scale
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEAEAEA);
  static const Color grey300 = Color(0xFFD4D4D4);
  static const Color grey400 = Color(0xFFA3A3A3);
  static const Color grey500 = Color(0xFF737373);
  static const Color grey600 = Color(0xFF525252);
  static const Color grey700 = Color(0xFF404040);
  static const Color grey800 = Color(0xFF262626);
  static const Color grey900 = Color(0xFF171717);

  // Spacing (Strictly defined as per requirements)
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;

  // Shadows
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get hoverShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: secondary,
            primary: primary,
            secondary: secondary,
            surface: card,
            error: error,
          ).copyWith(
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: primary,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primary),
      ),
      textTheme: _buildTextTheme(),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: GoogleFonts.cormorantGaramond(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.1,
        letterSpacing: -1.0,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.25,
        letterSpacing: -0.3,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.3,
        letterSpacing: -0.2,
      ),
      bodyLarge: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: grey700,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: grey600,
        height: 1.5,
      ),
      labelLarge: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: grey500,
        letterSpacing: 0.5,
      ),
      labelMedium: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: grey500,
        letterSpacing: 0.5,
      ),
    );
  }
}
