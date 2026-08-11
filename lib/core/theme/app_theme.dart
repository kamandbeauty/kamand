import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static String? get _fontFamily {
    try {
      return GoogleFonts.vazirmatn().fontFamily;
    } catch (_) {
      return 'Vazirmatn';
    }
  }

  static TextTheme _textTheme(Brightness b) {
    final base = b == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    try {
      return GoogleFonts.vazirmatnTextTheme(base.textTheme).apply(
        bodyColor: b == Brightness.dark ? Colors.white : RubyTextPrimary,
        displayColor: b == Brightness.dark ? Colors.white : RubyTextPrimary,
      );
    } catch (_) {
      return base.textTheme;
    }
  }

  // ─────────────────────────────────────────
  // Ruby Brand — Theme Tokens (Spec §22)
  // ─────────────────────────────────────────
  static const Color RubyPrimary = Color(0xFFF97316); // Ruby Orange
  static const Color RubyPrimaryDark = Color(0xFFEA580C);
  static const Color RubyPrimaryContainer = Color(0xFFFFEDD5); // orange-100
  static const Color RubyBackground = Color(0xFFF7F8FC); // soft cool background
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
  static const Color bgLight = Color(0xFFF7F8FC);
  static const Color bgDark = Color(0xFF0F172A);
  static const Color cardDark = Color(0xFF1E293B);

  static const double cardRadius = 22.0;

  /// تم روشن با رنگ اصلی قابل‌سفارشی‌سازی
  static ThemeData lightThemeWith(Color accent) {
    final container = Color.lerp(accent, Colors.white, 0.85) ?? RubyPrimaryContainer;
    return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: accent,
    scaffoldBackgroundColor: bgLight,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      primary: accent,
      primaryContainer: container,
      secondary: const Color(0xFF0284C7),
      surface: Colors.white,
      brightness: Brightness.light,
    ),
    fontFamily: _fontFamily,
    textTheme: _textTheme(Brightness.light),
    appBarTheme: AppBarTheme(
      backgroundColor: accent,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        fontFamily: _fontFamily,
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
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: _fontFamily,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accent, width: 2),
      ),
    ),
  );
  }

  static ThemeData get lightTheme => lightThemeWith(RubyPrimary);

  /// تم تاریک با رنگ اصلی قابل‌سفارشی‌سازی
  static ThemeData darkThemeWith(Color accent) {
    return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: accent,
    scaffoldBackgroundColor: bgDark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      primary: accent,
      secondary: Color.lerp(accent, Colors.white, 0.25) ?? accent,
      surface: cardDark,
      brightness: Brightness.dark,
    ),
    fontFamily: _fontFamily,
    textTheme: _textTheme(Brightness.dark),
    appBarTheme: AppBarTheme(
      backgroundColor: cardDark,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: _fontFamily,
      ),
    ),
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: const BorderSide(color: Color(0xFF334155), width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: _fontFamily,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0F172A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accent, width: 2),
      ),
    ),
  );
  }

  static ThemeData get darkTheme => darkThemeWith(RubyPrimary);
}
