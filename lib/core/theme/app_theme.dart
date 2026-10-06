import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const ink = Color(0xFF253238);
  static const teal = Color(0xFF176B67);
  static const tealLight = Color(0xFFE2F2EF);
  static const sand = Color(0xFFF9F7F2);
  static const gold = Color(0xFFC08B3E);
  static const muted = Color(0xFF687478);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.light,
      surface: sand,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(primary: teal, secondary: gold, surface: sand),
      scaffoldBackgroundColor: sand,
      fontFamily: 'sans',
      appBarTheme: const AppBarTheme(
        backgroundColor: sand,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE4E7E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: teal, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: tealLight,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
