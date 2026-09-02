import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dark, moody, and high-contrast — a workshop tool built around the
/// Mulyankan logo's own dark-red mood rather than a bright consumer
/// palette. Brand red for action, burnt-orange for urgency (kept a
/// distinct hue from the brand red on purpose), green for confirmed
/// money.
class AppColors {
  static const background = Color(0xFF171210);
  static const surface = Color(0xFF241C19);
  /// The deepest tone in the app — reserved for the one focal panel per
  /// screen that must outrank everything else (the live countdown).
  static const spotlight = Color(0xFF0D0908);
  static const ink = Color(0xFFF1EAE0); // primary text/chrome, light-on-dark
  static const accent = Color(0xFFA7383C); // muddy brand red, from the logo
  static const money = Color(0xFF2E9E52); // confirmed money
  static const urgent = Color(0xFFC1521A); // expiring time — distinct from brand red
  static const muted = Color(0xFF9C8F84);
  static const divider = Color(0xFF362C27);
}

class AppTheme {
  static ThemeData get theme {
    final textTheme = GoogleFonts.ibmPlexSansTextTheme(ThemeData(brightness: Brightness.dark).textTheme)
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink)
        .copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, color: AppColors.ink),
      displayMedium: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, color: AppColors.ink),
      headlineLarge: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, color: AppColors.ink),
      headlineMedium: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: AppColors.ink),
      titleLarge: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: AppColors.ink),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
        surface: AppColors.surface,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: AppColors.ink,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.divider),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: const TextStyle(color: AppColors.muted),
        hintStyle: const TextStyle(color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerColor: AppColors.divider,
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.ink),
    );
  }

  /// Tabular figures, largest weight on screen — for money and countdowns.
  static TextStyle moneyStyle({double size = 28, Color? color}) => GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
