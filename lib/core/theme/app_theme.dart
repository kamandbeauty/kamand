import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const ink = Color(0xFF253238);
  static const teal = Color(0xFF176B67);
  static const tealDark = Color(0xFF123F42);
  static const tealLight = Color(0xFFE2F2EF);
  static const sand = Color(0xFFF9F7F2);
  static const gold = Color(0xFFC08B3E);
  static const muted = Color(0xFF687478);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.light,
      surface: sand,
    ).copyWith(
      primary: teal,
      onPrimary: Colors.white,
      secondary: gold,
      onSecondary: Colors.white,
      surface: sand,
      onSurface: ink,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'sans');
    return base.copyWith(
      scaffoldBackgroundColor: sand,
      appBarTheme: const AppBarTheme(
        backgroundColor: sand,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w900),
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: const TextStyle(color: ink, fontSize: 25, fontWeight: FontWeight.w900),
        titleLarge: const TextStyle(color: ink, fontSize: 19, fontWeight: FontWeight.w900),
        titleMedium: const TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800),
        bodyLarge: const TextStyle(color: ink, fontSize: 15, height: 1.55),
        bodyMedium: const TextStyle(color: ink, fontSize: 14, height: 1.5),
        bodySmall: const TextStyle(color: muted, fontSize: 12, height: 1.45),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: Color(0xFF98A2A2), fontSize: 13),
        labelStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600),
        prefixIconColor: teal,
        suffixIconColor: muted,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE4E7E5))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: teal, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.redAccent)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: tealLight,
        side: const BorderSide(color: Color(0xFFE3E8E5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: teal,
          side: const BorderSide(color: Color(0xFFB9D5D0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 75,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: tealLight,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE8ECE9), thickness: 1),
    );
  }
}
