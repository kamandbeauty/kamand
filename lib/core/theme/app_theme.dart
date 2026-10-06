import 'package:flutter/material.dart';

/// "Premium Mystical Glass" design system for طالع من.
///
/// Dark = midnight-navy sky with glass cards, soft violet/gold accents.
/// Light = airy lavender-white with the same celestial accents.
class AppTheme {
  AppTheme._();

  // ── Brand palette ────────────────────────────────────────────────
  static const Color violet = Color(0xFF8B7CF6);
  static const Color violetDeep = Color(0xFF6C5CE7);
  static const Color gold = Color(0xFFE8C77B);
  static const Color sky = Color(0xFF64D2FF);
  static const Color rose = Color(0xFFFF7D9C);

  // Dark (default) — "آسمان شب"
  static const Color darkBackground = Color(0xFF0B1026);
  static const Color darkBackgroundAlt = Color(0xFF0E1430);
  static const Color darkCard = Color(0xFF151C3F);
  static const Color darkCardHigh = Color(0xFF1B234C);
  static const Color darkBorder = Color(0x33C7D2FE);
  static const Color darkText = Color(0xFFEDF0FF);
  static const Color darkTextMuted = Color(0xFF9AA3C7);

  // Light — "پرتوِ سپیده"
  static const Color lightBackground = Color(0xFFF3F2FC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0x221B1F4B);
  static const Color lightText = Color(0xFF1D2140);
  static const Color lightTextMuted = Color(0xFF5A608A);

  static const double cardRadius = 22.0;

  static ThemeData get darkTheme => _base(Brightness.dark);

  static ThemeData get lightTheme => _base(Brightness.light);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? darkBackground : lightBackground;
    final card = isDark ? darkCard : lightCard;
    final border = isDark ? darkBorder : lightBorder;
    final text = isDark ? darkText : lightText;
    final muted = isDark ? darkTextMuted : lightTextMuted;
    final scheme = ColorScheme.fromSeed(
      seedColor: violetDeep,
      brightness: brightness,
      primary: violet,
      secondary: gold,
      surface: card,
      onPrimary: Colors.white,
      onSurface: text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      fontFamily: 'Vazirmatn',
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: text),
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          fontFamily: 'Vazirmatn',
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xE60E1430) : const Color(0xF2FFFFFF),
        indicatorColor: violet.withValues(alpha: 0.22),
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'Vazirmatn',
            color: text,
          ),
        ),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: muted)),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        border: Border(top: BorderSide(color: border, width: 1)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: violet,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'Vazirmatn',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: violet,
          side: const BorderSide(color: violet, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Vazirmatn',
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: violet,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Vazirmatn',
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkCardHigh : const Color(0xFFEEEDF9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: violet, width: 2),
        ),
        hintStyle: TextStyle(color: muted, fontFamily: 'Vazirmatn'),
        labelStyle: TextStyle(color: muted, fontFamily: 'Vazirmatn'),
        style: TextStyle(color: text, fontFamily: 'Vazirmatn'),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(card),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        textStyle: TextStyle(color: text, fontFamily: 'Vazirmatn'),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? darkCardHigh : const Color(0xFF2A2F55),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: 'Vazirmatn',
          fontSize: 13,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border, width: 1),
        ),
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: 'Vazirmatn',
        ),
        contentTextStyle: TextStyle(
          color: muted,
          fontSize: 13.5,
          height: 1.8,
          fontFamily: 'Vazirmatn',
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? violet
              : (isDark ? const Color(0xFF2A3158) : const Color(0xFFD9D8EA)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: violet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
