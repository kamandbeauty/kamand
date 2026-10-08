import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../data/content/traditions_content.dart';
import '../../providers/tradition_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mystic_badge.dart';
import 'tradition_widgets.dart';

/// سنت ودیک — برج قمری (راشی) و تولدستاره (ناکشاترا).
class VedicTraditionScreen extends ConsumerWidget {
  const VedicTraditionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chart = ref.watch(vedicChartProvider);
    final knowsTime = ref.watch(birthTimeKnownProvider);

    if (chart == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('طالع‌بینی ودیک')),
        body: const ErrorState(message: 'ابتدا تاریخ تولدت را در پروفایل وارد کن.'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('طالع‌بینی ودیک (جیوتیشا)')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Hero: Moon rashi ────────────────────────────────────
          GlassCard(
            highlight: true,
            accent: AppTheme.violet,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Text('برج قمریِ تولد (چاندرا راشی)',
                    style: _kLabelStyle(theme)),
                const SizedBox(height: 8),
                TraditionEmblem(
                  asset: MysticEmblems.vedic.asset,
                  accent: AppTheme.violet,
                  child: Text(
                    chart.rashi['symbol']! as String,
                    style: TextStyle(
                      fontSize: 40,
                      color: theme.brightness == Brightness.dark
                          ? AppTheme.gold
                          : AppTheme.violetDeep,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  chart.rashi['nameFa']! as String,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 8),
                BodyText(chart.rashi['text']! as String),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Nakshatra ───────────────────────────────────────────
          SectionHeader(
            'تولدستارهٔ تو (جانما ناکشاترا)',
            subtitle:
                'پادا ${PersianNumbers.toPersianNum(chart.pada)} از ۴',
          ),
          GlassCard(
            accent: AppTheme.gold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      chart.nakshatra['name']! as String,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                BodyText(chart.nakshatra['text']! as String),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  knowsTime
                      ? 'با ساعت تولد ثبت‌شده‌ات محاسبه شده است.'
                      : 'ساعت تولدت ثبت نشده؛ محاسبه بر مبنای ظهرِ روز تولد است '
                        '(ماه ~۱۳ درجه در روز جابه‌جا می‌شود).',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.8,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Tradition intro ─────────────────────────────────────
          const SectionHeader('روایت سنت'),
          GlassCard(child: BodyText(TraditionsContent.vedicIntro)),
          const SizedBox(height: 20),

          // ── All 27 nakshatras ───────────────────────────────────
          const SectionHeader('۲۷ ناکشاترا'),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in TraditionsContent.vedicNakshatras)
                  NatureChip(n['name']! as String, color: AppTheme.violet),
              ],
            ),
          ),
          const DisclaimerCard(),
        ],
      ),
    );
  }

  static TextStyle _kLabelStyle(ThemeData theme) => TextStyle(
        fontSize: 12,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        fontFamily: 'Vazirmatn',
      );
}
