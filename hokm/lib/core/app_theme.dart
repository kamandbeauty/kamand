import 'package:flutter/material.dart';

/// تم کلی اپ — شیک، تاریک، با تأکید طلایی.
abstract final class AppTheme {
  static const Color gold = Color(0xFFE4BE6A);
  static const Color goldDeep = Color(0xFFB98A2F);
  static const Color felt = Color(0xFF1B4D33);
  static const Color surfaceDark = Color(0xFF14181F);
  static const Color surfaceCard = Color(0xFF1F2630);

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: surfaceDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.dark,
        primary: gold,
        secondary: const Color(0xFF7FC4A8),
        surface: surfaceDark,
      ),
      textTheme: base.textTheme
          .apply(fontFamily: 'VazirmatnFD', fontSizeFactor: 1.0),
      primaryTextTheme:
          base.primaryTextTheme.apply(fontFamily: 'VazirmatnFD'),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: const Color(0xFF241A05),
          textStyle: const TextStyle(
            fontFamily: 'VazirmatnFD',
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x22FFFFFF),
        thickness: 1,
      ),
    );
  }
}
