import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/abzio_motion.dart';

enum AbzioSectionTheme { light, dark }

class AbzioTheme {
  static const Color accentColor = Color(0xFFD4AF37);
  static const Color primaryColor = lightBackground;
  static const Color backgroundColor = lightBackground;
  static const Color cardColor = lightCard;
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;
  static const Color grey50 = Color(0xFFFFFFFF);
  static const Color grey100 = Color(0xFFF8F8F8);
  static const Color grey200 = Color(0xFFF1F1F1);
  static const Color grey300 = lightBorder;
  static const Color grey400 = Color(0xFFD2D2D2);
  static const Color grey500 = Color(0xFF8B8B8B);
  static const Color grey600 = lightTextSecondary;

  static const Color lightBackground = Color(0xFFFFFCF7);
  static const Color lightCard = Color(0xFFFFFDF8);
  static const Color lightTextPrimary = Color(0xFF1B1812);
  static const Color lightTextSecondary = Color(0xFF6B655B);
  static const Color lightBorder = Color(0xFFF0E3C5);
  static const Color lightMuted = Color(0xFFF7F1E3);

  static const Color darkBackground = lightBackground;
  static const Color darkCard = lightCard;
  static const Color darkTextPrimary = lightTextPrimary;
  static const Color darkTextSecondary = lightTextSecondary;
  static const Color darkBorder = lightBorder;
  static const Color darkMuted = lightMuted;

  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing24 = 24;
  static const double baseRadius = 20;
  static const double sectionSpacing = spacing24;
  static const double internalSpacing = spacing16;

  static List<BoxShadow> shadowFor(Brightness brightness) => [
        BoxShadow(
          color: const Color(0xFFB8963F).withValues(
            alpha: brightness == Brightness.dark ? 0.18 : 0.08,
          ),
          blurRadius: brightness == Brightness.dark ? 24 : 18,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get eliteShadow => shadowFor(Brightness.light);

  static final PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      for (final platform in TargetPlatform.values)
        platform: const AbzioPageTransitionsBuilder(),
    },
  );

  static ThemeData get lightTheme => _buildTheme(brightness: Brightness.light);
  static ThemeData get darkTheme => _buildTheme(brightness: Brightness.light);

  static ThemeData themeFor(AbzioSectionTheme sectionTheme) {
    return lightTheme;
  }

  static ThemeData _buildTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? darkBackground : lightBackground;
    final card = isDark ? darkCard : lightCard;
    final textPrimary = isDark ? darkTextPrimary : lightTextPrimary;
    final textSecondary = isDark ? darkTextSecondary : lightTextSecondary;
    final border = isDark ? darkBorder : lightBorder;
    final muted = isDark ? darkMuted : lightMuted;

    final colorScheme = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: accentColor,
      primary: accentColor,
      secondary: accentColor,
      surface: card,
    ).copyWith(
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: textPrimary,
      error: const Color(0xFFD64C4C),
      onError: Colors.white,
    );

    final textTheme = TextTheme(
      displayLarge: GoogleFonts.outfit(
        color: textPrimary,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.1,
      ),
      displayMedium: GoogleFonts.outfit(
        color: textPrimary,
        fontSize: 26,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: GoogleFonts.outfit(
        color: textPrimary,
        fontSize: 21,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: GoogleFonts.outfit(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
      bodyLarge: GoogleFonts.outfit(
        color: textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.outfit(
        color: textSecondary,
        fontSize: 14,
        height: 1.5,
      ),
      labelMedium: GoogleFonts.outfit(
        color: accentColor,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
      labelSmall: GoogleFonts.outfit(
        color: textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.35,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: accentColor,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: card,
      dividerColor: border,
      fontFamily: GoogleFonts.outfit().fontFamily,
      pageTransitionsTheme: _pageTransitions,
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimary, size: 22),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      iconTheme: IconThemeData(color: textPrimary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.black,
          elevation: 0,
          animationDuration: AbzioMotion.medium,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(accentColor.withValues(alpha: 0.10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border, width: 1.1),
          animationDuration: AbzioMotion.medium,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(accentColor.withValues(alpha: 0.08)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          animationDuration: AbzioMotion.medium,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(accentColor.withValues(alpha: 0.08)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: accentColor, width: 1.3),
        ),
        hintStyle: GoogleFonts.outfit(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        labelStyle: GoogleFonts.outfit(color: textSecondary, fontSize: 13),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(baseRadius)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? darkMuted : lightTextPrimary,
        contentTextStyle: GoogleFonts.outfit(color: isDark ? darkTextPrimary : lightBackground),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? accentColor : textSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.outfit(
            color: selected ? textPrimary : textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
      ),
    );
  }
}

class AbzioThemedScreen extends StatelessWidget {
  const AbzioThemedScreen({
    super.key,
    required this.sectionTheme,
    required this.child,
  });

  final AbzioSectionTheme sectionTheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AbzioTheme.themeFor(sectionTheme),
      child: AnimatedTheme(
        data: AbzioTheme.themeFor(sectionTheme),
        duration: AbzioMotion.medium,
        curve: AbzioMotion.curve,
        child: child,
      ),
    );
  }
}

class AbzioThemeScope extends StatelessWidget {
  const AbzioThemeScope.light({
    super.key,
    required this.child,
  }) : sectionTheme = AbzioSectionTheme.light;

  const AbzioThemeScope.dark({
    super.key,
    required this.child,
  }) : sectionTheme = AbzioSectionTheme.dark;

  final AbzioSectionTheme sectionTheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AbzioThemedScreen(sectionTheme: sectionTheme, child: child);
  }
}

extension AbzioThemeContext on BuildContext {
  ColorScheme get abzioColors => Theme.of(this).colorScheme;
  TextTheme get abzioText => Theme.of(this).textTheme;
  bool get isDarkSection => Theme.of(this).brightness == Brightness.dark;
  Color get abzioBorder => isDarkSection ? AbzioTheme.darkBorder : AbzioTheme.lightBorder;
  Color get abzioMuted => isDarkSection ? AbzioTheme.darkMuted : AbzioTheme.lightMuted;
  Color get abzioSecondaryText => isDarkSection ? AbzioTheme.darkTextSecondary : AbzioTheme.lightTextSecondary;
  List<BoxShadow> get abzioShadow => AbzioTheme.shadowFor(Theme.of(this).brightness);
}
