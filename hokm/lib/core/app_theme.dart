import 'package:flutter/material.dart';

/// تم کلی اپ — «ایرانیِ سنتیِ مدرن».
///
/// پالت از کاشیِ اصفهان می‌آید: لاجورد شب، فیروزهٔ لعابی، طلای تذهیب
/// و شنگرفِ نقش قالی؛ روی زمینهٔ جوهریِ عمیق.
abstract final class AppTheme {
  // --- توکن‌های پایه (نام‌های قدیمی حفظ شده‌اند) ---
  static const Color gold = Color(0xFFE8C46B);
  static const Color goldDeep = Color(0xFFB98A2F);
  static const Color goldLight = Color(0xFFFFF0BE);
  static const Color felt = Color(0xFF14403A);
  static const Color surfaceDark = Color(0xFF0C1526);
  static const Color surfaceCard = Color(0xFF15223A);

  // --- توکن‌های جدید ---
  static const Color lapis = Color(0xFF13294B);
  static const Color lapisDeep = Color(0xFF091326);
  static const Color turquoise = Color(0xFF2FA8A0);
  static const Color turquoiseLight = Color(0xFF5FD9CD);
  static const Color saffron = Color(0xFFE9A23B);
  static const Color crimson = Color(0xFFA62B3C);
  static const Color ivory = Color(0xFFF4EDE0);

  /// گرادیان زمینهٔ صفحات (شبِ لاجوردی).
  static const LinearGradient nightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF14284A), Color(0xFF0A1122)],
  );

  /// گرادیان طلا برای متن/قاب‌های شاخص.
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB98A2F), Color(0xFFFFF0BE), Color(0xFFD9AE55)],
  );

  static List<BoxShadow> glow(Color color, {double strength = 1}) => [
        BoxShadow(
          color: color.withOpacity(0.30 * strength),
          blurRadius: 26 * strength,
          spreadRadius: 1,
        ),
      ];

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: surfaceDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.dark,
        primary: gold,
        secondary: turquoiseLight,
        surface: surfaceDark,
      ),
      textTheme: base.textTheme.apply(fontFamily: 'VazirmatnFD'),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'VazirmatnFD'),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: const Color(0xFF241A05),
          shadowColor: goldDeep.withOpacity(0.6),
          textStyle: const TextStyle(
            fontFamily: 'VazirmatnFD',
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 6,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold,
          side: BorderSide(color: gold.withOpacity(0.55), width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'VazirmatnFD',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: gold.withOpacity(0.18)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceCard,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: gold.withOpacity(0.28)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(
        color: gold.withOpacity(0.16),
        thickness: 1,
      ),
    );
  }
}
