import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/persian_numbers.dart';
import 'glass_card.dart';

/// One explained dimension (label + what it measures + optional weight).
class LegendDimension {
  const LegendDimension(this.label, this.text, {this.weight});

  final String label;
  final String text;
  final int? weight; // percent contribution, e.g. 28
}

/// One score band (threshold + label + meaning).
class LegendBand {
  const LegendBand(this.min, this.label, this.meaning);

  final int min;
  final String label;
  final String meaning;
}

/// «راهنمای امتیازها» — the expandable explanation card shown wherever
/// percentage scores appear (daily/weekly/monthly horoscopes, couple
/// compatibility, marriage). Explains what each dimension measures, how
/// the bands read and (optionally) how the number is computed —
/// transparency without fake-precision claims.
class ScoreLegend extends StatelessWidget {
  const ScoreLegend({
    super.key,
    required this.intro,
    required this.dimensions,
    required this.bands,
    this.methodNote,
    this.accent,
  });

  /// Opening line: what these particular percentages are about.
  final String intro;

  /// The dimensions shown next to the percentages.
  final List<LegendDimension> dimensions;

  /// How to read the scale (colored bands).
  final List<LegendBand> bands;

  /// Optional closing note on how the score is computed.
  final String? methodNote;

  final Color? accent;

  static Color bandColor(int min) {
    if (min >= 85) return const Color(0xFF4CD97B);
    if (min >= 72) return AppTheme.sky;
    if (min >= 60) return AppTheme.gold;
    if (min >= 48) return const Color(0xFFFF9E6E);
    return AppTheme.rose;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.primary;
    return GlassCard(
      accent: color,
      child: Theme(
        // Neutral splash inside the card.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: false,
          dense: true,
          iconColor: color,
          collapsedIconColor: color,
          title: Row(
            children: [
              Icon(Icons.help_outline_rounded, size: 17, color: color),
              const SizedBox(width: 8),
              Text(
                'این درصدها یعنی چه؟',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4, left: 25),
            child: Text(
              intro,
              style: TextStyle(
                fontSize: 11,
                height: 1.9,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontFamily: 'Vazirmatn',
              ),
            ),
          ),
          children: [
            const SizedBox(height: 6),
            for (final d in dimensions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        d.weight == null
                            ? d.label
                            : '${d.label} · ${PersianNumbers.toPersianNum(d.weight!)}٪',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: color,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        d.text,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.9,
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.75),
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'خواندنِ مقیاس:',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontFamily: 'Vazirmatn',
              ),
            ),
            const SizedBox(height: 6),
            for (final b in bands)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bandColor(b.min),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  '${b.label} (${_bandRange(b, bands)}): ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(text: b.meaning),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.9,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.75),
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (methodNote != null) ...[
              const SizedBox(height: 4),
              Text(
                methodNote!,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.95,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  static String _bandRange(LegendBand b, List<LegendBand> bands) {
    final sorted = [...bands]..sort((x, y) => y.min.compareTo(x.min));
    final i = sorted.indexOf(b);
    final lower = b.min;
    final upper = i == 0 ? 100 : sorted[i - 1].min - 1;
    if (lower <= 0) return 'زیرِ ${PersianNumbers.toPersianNum(upper + 1)}';
    return '${PersianNumbers.toPersianNum(lower)}–${PersianNumbers.toPersianNum(upper)}';
  }
}

/// Shared band + dimension presets (authored interface text).
class ScoreLegendPresets {
  ScoreLegendPresets._();

  /// Bands used by every legend (colors mapped in [ScoreLegend.bandColor]).
  static const List<LegendBand> bands = [
    LegendBand(85, 'بسیار بالا', 'روز یا بعدِ بسیار مساعد — موج را بگیر.'),
    LegendBand(72, 'بالا', 'پشتوانهٔ خوب؛ برای اقدام‌های مهم کافی است.'),
    LegendBand(60, 'متعادل', 'روزی معمولی با گشایش‌های جزئی.'),
    LegendBand(48, 'نیازمند صبر', 'انرژیِ پایین؛ کارِ امروز، دفاعِ آرام است.'),
    LegendBand(0, 'پایین', 'روزِ استراحت و بازگشت به خود — نه روزِ نبرد.'),
  ];

  static const List<LegendDimension> horoscopeDimensions = [
    LegendDimension('عشق', 'گرمای رابطه‌ها، ابراز احساس و نزدیکیِ عاطفیِ امروزِ تو.'),
    LegendDimension('کار', 'پشتوانه، دیده‌شدن و پیشرفتِ امورِ شغلی و درسی.'),
    LegendDimension('مالی', 'جریانِ پول، فرصت‌های خرج و درآمدِ امروز.'),
    LegendDimension('روحیه', 'حالِ درونی: خواب، حوصله و نشاطِ ذهنیِ امروز.'),
    LegendDimension('انرژی', 'سوختِ فیزیکیِ بدن: قدرتِ حرکت و اقدام‌کردن.'),
  ];

  static const String horoscopeMethod =
      'امتیازهای روزانه از سه لایه ساخته می‌شوند: موقعیتِ واقعیِ قمر و خورشید در آسمانِ امروز (لایهٔ نجومی)، جایگاهِ برجِ تو در چرخهٔ سال، و بانکِ معناییِ ویژهٔ برجت. عدد، ترجمهٔ سادهٔ همان تحلیل است — تفسیر سرگرم‌کننده، نه پیش‌بینیِ قطعی.';
}
