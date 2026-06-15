import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RiderTheme {
  static const riderPrimary = Color(0xFFC8A86B);
  static const riderAccent = Color(0xFF8D6A2E);
  static const riderBackground = Color(0xFFF8F5EF);
  static const riderSurface = Colors.white;
  static const riderBorder = Color(0xFFE7E0D3);
  static const riderText = Color(0xFF111111);
  static const riderMuted = Color(0xFF666666);

  // Onboarding Dark Theme Tokens (Premium V4)
  static const onboardingBackground = Color(0xFF0A0A0A);
  static const onboardingSurface = Color(0xFF141414);
  static const onboardingElevatedSurface = Color(0xFF1F1F1F);
  static const onboardingGold = Color(0xFFC8A86B);
  static const onboardingSuccess = Color(0xFF22C55E);
  static const onboardingWarning = Color(0xFFF59E0B);
  static const onboardingError = Color(0xFFEF4444);
  static const onboardingPrimaryText = Colors.white;
  static const onboardingSecondaryText = Colors.white70;
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: riderBackground,
      colorScheme: const ColorScheme.light(
        primary: riderPrimary,
        secondary: riderAccent,
        surface: riderSurface,
        onPrimary: Colors.white,
        onSurface: riderText,
      ),
      textTheme: GoogleFonts.interTextTheme(
        base.textTheme,
      ).apply(bodyColor: riderText, displayColor: riderText),
      cardTheme: CardThemeData(
        color: riderSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFCFBF7),
        labelStyle: const TextStyle(color: riderMuted),
        hintStyle: const TextStyle(color: riderMuted),
        helperStyle: const TextStyle(color: riderMuted),
        errorStyle: const TextStyle(color: Color(0xFFB42318)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: riderBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: riderBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: riderPrimary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFB42318)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFB42318), width: 1.4),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: riderText,
        centerTitle: false,
      ),
      dividerColor: riderBorder,
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFFF6F1E6),
        selectedColor: riderPrimary,
        side: const BorderSide(color: riderBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelStyle: const TextStyle(color: riderText),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1A1A),
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: riderPrimary,
        linearTrackColor: Color(0xFFEAE3D5),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: riderPrimary,
        thumbColor: riderAccent,
        overlayColor: riderPrimary.withValues(alpha: 0.16),
        inactiveTrackColor: const Color(0xFFE6DED0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: riderText,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: riderAccent),
      ),
      iconTheme: const IconThemeData(color: riderText),
    );
  }

  static ThemeData dark() => light();
}
