/// تم بصری اپ (تیره با لهجهٔ طلایی، فونت وزیرمتن).
library;

import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color gold = Color(0xFFE8C87A);
  static const Color goldDeep = Color(0xFFB9912F);
  static const Color ink = Color(0xFF17110D);
  static const Color panel = Color(0xFF221A14);
  static const Color panelLight = Color(0xFF2E231A);
  static const Color paper = Color(0xFFFFFCF4);
  static const Color cardRed = Color(0xFFC0252B);
  static const Color cardBlack = Color(0xFF16130F);
  static const Color teamUs = Color(0xFF3FBE86);
  static const Color teamThem = Color(0xFFE2705A);
}

ThemeData buildAppTheme() {
  const ColorScheme scheme = ColorScheme.dark(
    primary: AppColors.gold,
    onPrimary: Color(0xFF241B06),
    secondary: AppColors.goldDeep,
    surface: AppColors.panel,
    onSurface: Color(0xFFF3E9D2),
  );

  final ThemeData base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Vazirmatn',
    scaffoldBackgroundColor: AppColors.ink,
  );

  return base.copyWith(
    chipTheme: base.chipTheme.copyWith(
      labelStyle: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12),
      secondaryLabelStyle:
          const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: const Color(0xFFF3E9D2),
      displayColor: AppColors.gold,
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.goldDeep),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: const Color(0xFF241B06),
        textStyle: const TextStyle(
          fontFamily: 'Vazirmatn',
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFF3E9D2),
        side: const BorderSide(color: AppColors.goldDeep),
        textStyle: const TextStyle(
          fontFamily: 'Vazirmatn',
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.panelLight,
      contentTextStyle: TextStyle(
        fontFamily: 'Vazirmatn',
        color: Color(0xFFF3E9D2),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
