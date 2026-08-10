import 'package:flutter/material.dart';

class AppTheme {
  // ─────────────────────────────────────────
  // Ruby Brand — Theme Tokens (Spec §22)
  // ─────────────────────────────────────────
  static const Color RubyPrimary = Color(0xFFF97316); // Ruby Orange
  static const Color RubyPrimaryDark = Color(0xFFEA580C);
  static const Color RubyPrimaryContainer = Color(0xFFFFEDD5); // orange-100
  static const Color RubyBackground = Color(0xFFFFFBEB); // warm light bg
  static const Color RubySurface = Colors.white;
  static const Color RubyTextPrimary = Color(0xFF1E293B); // slate-800
  static const Color RubyTextSecondary = Color(0xFF64748B); // slate-500
  static const Color RubySuccess = Color(0xFF059669); // emerald-600
  static const Color RubyWarning = Color(0xFFD97706); // amber-600
  static const Color RubyError = Color(0xFFE11D48); // rose-600

  // Legacy aliases — keep for backward compat (other screens use them)
  static const Color primaryBlue = RubyPrimary;
  static const Color primaryBlueDark = RubyPrimaryDark;
  static const Color lightBlueBg = RubyPrimaryContainer;
  static const Color bgLight = Color(0xFFFFFBEB);
  static const Color bgDark = Color(0xFF0F172A);
  static const Color cardDark = Color(0xFF1E293B);

  static const double cardRadius = 22.0;

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: RubyPrimary,
    scaffoldBackgroundColor: bgLight,
    colorScheme: ColorScheme.fromSeed(
      seedColor: RubyPrimary,
      primary: RubyPrimary,
      primaryContainer: RubyPrimaryContainer,
      secondary: const Color(0xFF0284C7),
      surface: Colors.white,
      brightness: Brightness.light,
    ),
    fontFamily: 'Vazirmatn',
    appBarTheme: const AppBarTheme(
      backgroundColor: RubyPrimary,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        fontFamily: 'Vazirmatn',
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: RubyPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'Vazirmatn',
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFF1F5F9),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: RubyPrimary, width: 2),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: RubyPrimary,
    scaffoldBackgroundColor: bgDark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: RubyPrimary,
      primary: RubyPrimary,
      secondary: Color(0xFFFB923C),
      surface: cardDark,
      brightness: Brightness.dark,
    ),
    fontFamily: 'Vazirmatn',
    appBarTheme: const AppBarTheme(
      backgroundColor: cardDark,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'Vazirmatn',
      ),
    ),
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(color: Color(0xFF334155), width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: RubyPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'Vazirmatn',
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF0F172A),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: RubyPrimary, width: 2),
      ),
    ),
  );
}
