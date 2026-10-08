import 'package:flutter/material.dart';

/// "Premium Mystical Glass" design system for طالع بین.
///
/// Dark skins are palette variants of the same midnight-glass language:
///  * آسمانِ شب (midnight)  — deep navy, the classic look (default)
///  * شبِ ارغوانی (violet)  — deep violet night
///  * شفقِ قطبی (aurora)    — teal-green aurora
///  * اقیانوسِ عمیق (ocean) — deep-sea blue
/// Light = «پرتوِ سپیده», airy lavender-white.
///
/// Each skin also carries a [SkyPalette] theme extension consumed by the
/// ambient sky background (stars, soft nebula tints) so the atmosphere
/// changes with the theme — cheaply (no blur, one painter).
class AppTheme {
  AppTheme._();

  // ── Brand accents (used across the app, skin-independent) ────────
  static const Color violet = Color(0xFF8B7CF6);
  static const Color violetDeep = Color(0xFF6C5CE7);
  static const Color gold = Color(0xFFE8C77B);
  static const Color sky = Color(0xFF64D2FF);
  static const Color rose = Color(0xFFFF7D9C);

  static const double cardRadius = 22.0;

  // ── Dark skin palette (midnight) ─────────────────────────────────
  static const Color darkBackground = Color(0xFF0B1026);
  static const Color darkBackgroundAlt = Color(0xFF0E1430);
  static const Color darkCard = Color(0xFF151C3F);
  static const Color darkCardHigh = Color(0xFF1B234C);
  static const Color darkBorder = Color(0x33C7D2FE);
  static const Color darkText = Color(0xFFEDF0FF);
  static const Color darkTextMuted = Color(0xFF9AA3C7);

  // ── Light palette (dawn) ─────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF3F2FC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0x221B1F4B);
  static const Color lightText = Color(0xFF1D2140);
  static const Color lightTextMuted = Color(0xFF5A608A);

  /// Selectable dark skins («تمِ آسمان»).
  static ThemeData themeFor(AppThemeSkin skin) =>
      _build(_skinData[skin] ?? _skinData[AppThemeSkin.midnight]!);

  static ThemeData get darkTheme => themeFor(AppThemeSkin.midnight);

  static ThemeData get lightTheme {
    final theme = _base(Brightness.light);
    return theme.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        const SkyPalette(
          star: Color(0x334756D7),
          starGold: Color(0x66C9A24B),
          nebulaA: Color(0x142F6BFF),
          nebulaB: Color(0x0FFF7D9C),
        ),
      ],
    );
  }
}

/// The four dark skins of «تمِ آسمان».
enum AppThemeSkin { midnight, violet, aurora, ocean }

extension AppThemeSkinX on AppThemeSkin {
  String get labelFa => switch (this) {
        AppThemeSkin.midnight => 'آسمانِ شب',
        AppThemeSkin.violet => 'شبِ ارغوانی',
        AppThemeSkin.aurora => 'شفقِ قطبی',
        AppThemeSkin.ocean => 'اقیانوسِ عمیق',
      };

  /// Short description shown under the skin name in the picker.
  String get descriptionFa => switch (this) {
        AppThemeSkin.midnight => 'سرمه‌ایِ آرام، همان چهرهٔ همیشگی',
        AppThemeSkin.violet => 'بنفشِ عمیق با نورِ مهتابی',
        AppThemeSkin.aurora => 'سبزِ فیروزه‌ایِ قطبی',
        AppThemeSkin.ocean => 'آبیِ ژرف و خنک',
      };

  /// Preview swatch (background → nebula tint → accent).
  List<Color> get swatch => switch (this) {
        AppThemeSkin.midnight => const [
            Color(0xFF0B1026),
            Color(0xFF1B234C),
            Color(0xFF8B7CF6),
          ],
        AppThemeSkin.violet => const [
            Color(0xFF140B26),
            Color(0xFF2A1D4F),
            Color(0xFFB388FF),
          ],
        AppThemeSkin.aurora => const [
            Color(0xFF071B18),
            Color(0xFF163B34),
            Color(0xFF4CD97B),
          ],
        AppThemeSkin.ocean => const [
            Color(0xFF061423),
            Color(0xFF132C44),
            Color(0xFF5AB8FF),
          ],
      };
}

class _SkinData {
  const _SkinData({
    required this.background,
    required this.backgroundAlt,
    required this.card,
    required this.cardHigh,
    required this.border,
    required this.text,
    required this.muted,
    required this.primary,
    required this.secondary,
    required this.palette,
  });

  final Color background;
  final Color backgroundAlt;
  final Color card;
  final Color cardHigh;
  final Color border;
  final Color text;
  final Color muted;
  final Color primary;
  final Color secondary;
  final SkyPalette palette;
}

const _skinData = <AppThemeSkin, _SkinData>{
  AppThemeSkin.midnight: _SkinData(
    background: Color(0xFF0B1026),
    backgroundAlt: Color(0xFF0E1430),
    card: Color(0xFF151C3F),
    cardHigh: Color(0xFF1B234C),
    border: Color(0x33C7D2FE),
    text: Color(0xFFEDF0FF),
    muted: Color(0xFF9AA3C7),
    primary: Color(0xFF8B7CF6),
    secondary: Color(0xFFE8C77B),
    palette: SkyPalette(
      star: Color(0x66FFFFFF),
      starGold: Color(0x99E8C77B),
      nebulaA: Color(0x148B7CF6),
      nebulaB: Color(0x0F64D2FF),
    ),
  ),
  AppThemeSkin.violet: _SkinData(
    background: Color(0xFF140B26),
    backgroundAlt: Color(0xFF191031),
    card: Color(0xFF221741),
    cardHigh: Color(0xFF2A1D4F),
    border: Color(0x33D8B4FE),
    text: Color(0xFFF3EDFF),
    muted: Color(0xFFA99BC7),
    primary: Color(0xFFB388FF),
    secondary: Color(0xFFF0C987),
    palette: SkyPalette(
      star: Color(0x66F3EDFF),
      starGold: Color(0x99F0C987),
      nebulaA: Color(0x14B388FF),
      nebulaB: Color(0x0FFF7D9C),
    ),
  ),
  AppThemeSkin.aurora: _SkinData(
    background: Color(0xFF071B18),
    backgroundAlt: Color(0xFF0A231F),
    card: Color(0xFF10302B),
    cardHigh: Color(0xFF163B34),
    border: Color(0x3394F0C8),
    text: Color(0xFFEAFFF7),
    muted: Color(0xFF8FB8AC),
    primary: Color(0xFF4CD97B),
    secondary: Color(0xFF64D2FF),
    palette: SkyPalette(
      star: Color(0x66EAFFF7),
      starGold: Color(0x9964D2FF),
      nebulaA: Color(0x144CD97B),
      nebulaB: Color(0x0F64D2FF),
    ),
  ),
  AppThemeSkin.ocean: _SkinData(
    background: Color(0xFF061423),
    backgroundAlt: Color(0xFF081B2E),
    card: Color(0xFF0E2438),
    cardHigh: Color(0xFF132C44),
    border: Color(0x3364D2FF),
    text: Color(0xFFEAF6FF),
    muted: Color(0xFF8FA9C7),
    primary: Color(0xFF5AB8FF),
    secondary: Color(0xFFE8C77B),
    palette: SkyPalette(
      star: Color(0x66EAF6FF),
      starGold: Color(0x99E8C77B),
      nebulaA: Color(0x145AB8FF),
      nebulaB: Color(0x0F8B7CF6),
    ),
  ),
};

/// Per-skin colors for the ambient sky background (stars and two soft
/// nebula tints) — attached to every [ThemeData] this system builds.
@immutable
class SkyPalette extends ThemeExtension<SkyPalette> {
  const SkyPalette({
    required this.star,
    required this.starGold,
    required this.nebulaA,
    required this.nebulaB,
  });

  final Color star;
  final Color starGold;
  final Color nebulaA;
  final Color nebulaB;

  @override
  SkyPalette copyWith({
    Color? star,
    Color? starGold,
    Color? nebulaA,
    Color? nebulaB,
  }) =>
      SkyPalette(
        star: star ?? this.star,
        starGold: starGold ?? this.starGold,
        nebulaA: nebulaA ?? this.nebulaA,
        nebulaB: nebulaB ?? this.nebulaB,
      );

  @override
  SkyPalette lerp(SkyPalette? other, double t) {
    if (other == null) return this;
    return SkyPalette(
      star: Color.lerp(star, other.star, t)!,
      starGold: Color.lerp(starGold, other.starGold, t)!,
      nebulaA: Color.lerp(nebulaA, other.nebulaA, t)!,
      nebulaB: Color.lerp(nebulaB, other.nebulaB, t)!,
    );
  }
}

ThemeData _build(_SkinData d) {
  final scheme = ColorScheme.fromSeed(
    seedColor: d.primary,
    brightness: Brightness.dark,
    primary: d.primary,
    secondary: d.secondary,
    surface: d.card,
    onPrimary: Colors.white,
    onSurface: d.text,
  );
  return _base(
    Brightness.dark,
    background: d.background,
    card: d.card,
    cardHigh: d.cardHigh,
    border: d.border,
    text: d.text,
    muted: d.muted,
    navBar: d.backgroundAlt.withValues(alpha: 0.92),
    primary: d.primary,
    scheme: scheme,
    extension: d.palette,
  );
}

ThemeData _base(
  Brightness brightness, {
  Color? background,
  Color? card,
  Color? cardHigh,
  Color? border,
  Color? text,
  Color? muted,
  Color? navBar,
  Color? primary,
  ColorScheme? scheme,
  SkyPalette? extension,
}) {
  final isDark = brightness == Brightness.dark;
  background ??= isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
  card ??= isDark ? AppTheme.darkCard : AppTheme.lightCard;
  cardHigh ??= isDark ? AppTheme.darkCardHigh : const Color(0xFFEEEDF9);
  border ??= isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
  text ??= isDark ? AppTheme.darkText : AppTheme.lightText;
  muted ??= isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
  navBar ??= isDark ? const Color(0xE60E1430) : const Color(0xF2FFFFFF);
  primary ??= AppTheme.violet;
  scheme ??= ColorScheme.fromSeed(
    seedColor: AppTheme.violetDeep,
    brightness: brightness,
    primary: primary,
    secondary: AppTheme.gold,
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
    extensions: <ThemeExtension<dynamic>>[
      extension ??
          const SkyPalette(
            star: Color(0x66FFFFFF),
            starGold: Color(0x99E8C77B),
            nebulaA: Color(0x148B7CF6),
            nebulaB: Color(0x0F64D2FF),
          ),
    ],
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
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(color: border, width: 1),
      ),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: navBar,
      indicatorColor: primary.withValues(alpha: 0.22),
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
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
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
        foregroundColor: primary,
        side: BorderSide(color: primary, width: 1.4),
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
        foregroundColor: primary,
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'Vazirmatn',
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      hintStyle: TextStyle(color: muted, fontFamily: 'Vazirmatn'),
      labelStyle: TextStyle(color: muted, fontFamily: 'Vazirmatn'),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(card),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      textStyle: TextStyle(color: text, fontFamily: 'Vazirmatn'),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? cardHigh : const Color(0xFF2A2F55),
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
            ? primary
            : (isDark ? const Color(0xFF2A3158) : const Color(0xFFD9D8EA)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
