import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A mystical circular emblem: gradient fill, double ring, colored glow
/// and (optionally) a tiny gold star — the shared visual language for the
/// traditions & fortunes across the app.
class MysticBadge extends StatelessWidget {
  const MysticBadge({
    super.key,
    this.symbol,
    this.icon,
    this.asset,
    required this.colors,
    this.size = 46,
    this.showStar = true,
  });

  /// Emoji/glyph symbol — used as the fallback when no [asset] image
  /// exists. Rendered with the symbols fallback font so glyphs like ✦
  /// always resolve.
  final String? symbol;

  /// Generated emblem artwork (assets/emblems/<id>.png). When the file
  /// is missing at runtime the badge gracefully falls back to [symbol].
  final String? asset;

  /// Material icon fallback when no symbol fits.
  final IconData? icon;

  /// Exactly two colors: the gradient pair [primary, secondary].
  final List<Color> colors;

  final double size;

  /// Tiny gold ✦ accent at the top edge.
  final bool showStar;

  Widget _glyph(bool isDark, double size) {
    if (symbol != null) {
      return Text(
        symbol!,
        style: TextStyle(
          fontSize: size * 0.44,
          height: 1.15,
          color: isDark ? Colors.white : AppTheme.violetDeep,
          fontFamilyFallback: const ['NotoSansSymbols'],
        ),
      );
    }
    return Icon(icon, size: size * 0.44, color: colors.first);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = colors.first;
    final secondary = colors.length > 1 ? colors.last : primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            primary.withValues(alpha: 0.26),
            secondary.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: primary.withValues(alpha: 0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.26),
            blurRadius: size * 0.38,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Inner hairline ring — the "glass" depth.
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                margin: EdgeInsets.all(size * 0.07),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.18),
                    width: 0.8,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: asset != null
                ? ClipOval(
                    child: Image.asset(
                      asset!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _glyph(
                        isDark, size,
                      ),
                    ),
                  )
                : _glyph(isDark, size),
          ),
          if (showStar)
            Positioned(
              top: size * 0.02,
              right: size * 0.10,
              child: Icon(
                Icons.star_rounded,
                size: size * 0.20,
                color: AppTheme.gold,
              ),
            ),
        ],
      ),
    );
  }
}

/// Visual identity (symbol + gradient pair) for every tradition & fortune
/// module — one source of truth for the hub, the home strip and anywhere
/// else the modules appear.
class MysticSpec {
  const MysticSpec(this.id, this.symbol, this.a, this.b);

  final String id;
  final String symbol;
  final Color a;
  final Color b;

  /// Generated emblem artwork for this module (may not exist yet for a
  /// few modules — the badge falls back to the glyph automatically).
  String get asset => 'assets/emblems/$id.png';

  MysticBadge badge({double size = 46, bool showStar = true}) => MysticBadge(
        symbol: symbol,
        asset: asset,
        colors: [a, b],
        size: size,
        showStar: showStar,
      );
}

class MysticEmblems {
  MysticEmblems._();

  static const Color _emerald = Color(0xFF4CD97B);

  static const MysticSpec chinese =
      MysticSpec('chinese', '🐉', AppTheme.rose, AppTheme.violet);
  static const MysticSpec numerology =
      MysticSpec('numerology', '🔢', AppTheme.sky, AppTheme.violet);
  static const MysticSpec iranian =
      MysticSpec('iranian', '🌙', AppTheme.gold, AppTheme.rose);
  static const MysticSpec vedic =
      MysticSpec('vedic', '🧘', AppTheme.violet, AppTheme.sky);
  static const MysticSpec maya =
      MysticSpec('maya', '🏛', _emerald, AppTheme.sky);
  static const MysticSpec gem =
      MysticSpec('gem', '💎', AppTheme.sky, AppTheme.gold);
  static const MysticSpec abjad =
      MysticSpec('abjad', '✨', AppTheme.violet, AppTheme.gold);
  static const MysticSpec greek =
      MysticSpec('greek', 'Ψ', AppTheme.sky, AppTheme.gold);
  static const MysticSpec marriage =
      MysticSpec('marriage', '💍', AppTheme.rose, AppTheme.gold);
  static const MysticSpec months =
      MysticSpec('months', '📅', AppTheme.gold, AppTheme.sky);
  static const MysticSpec tarot =
      MysticSpec('tarot', '✦', AppTheme.violet, AppTheme.gold);
  static const MysticSpec animal =
      MysticSpec('animal', '🐾', _emerald, AppTheme.gold);

  /// Display order (hub sections + home strip).
  static const List<MysticSpec> all = [
    chinese, numerology, iranian, vedic, maya,
    gem, abjad, greek, marriage, months, tarot, animal,
  ];

  static MysticSpec byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => all.first);
}
