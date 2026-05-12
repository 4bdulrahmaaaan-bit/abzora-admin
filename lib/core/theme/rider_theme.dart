import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RiderTheme {
  static const riderPrimary = Color(0xFFD4AF37);
  static const riderAccent = Color(0xFFF5D76E);
  static const riderBackground = Color(0xFF050505);
  static const riderSurface = Color(0xFF101010);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: riderBackground,
      colorScheme: const ColorScheme.dark(
        primary: riderPrimary,
        secondary: riderAccent,
        surface: riderSurface,
      ),
      textTheme: GoogleFonts.interTextTheme(
        base.textTheme,
      ).apply(bodyColor: Colors.white, displayColor: Colors.white),
      cardTheme: CardThemeData(
        color: const Color.fromRGBO(20, 20, 20, 0.78),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: riderAccent, width: 1.3),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: riderAccent,
        thumbColor: riderPrimary,
        overlayColor: riderAccent.withValues(alpha: 0.18),
        inactiveTrackColor: Colors.white24,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: Colors.white.withValues(alpha: 0.07),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: riderAccent,
        linearTrackColor: Colors.white24,
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: riderAccent,
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
