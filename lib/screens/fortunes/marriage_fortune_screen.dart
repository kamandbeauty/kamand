import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/content/app_content.dart';
import '../../data/content/fortunes_content.dart';
import '../../providers/fortune_providers.dart';
import '../../providers/horoscope_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/score_legend.dart';
import '../../widgets/glass_card.dart';
import '../traditions/tradition_widgets.dart';

/// طالع ازدواج — سبکِ برج در پیمان زندگی + امتیاز هم‌نوایی با شریک.
class MarriageFortuneScreen extends ConsumerWidget {
  const MarriageFortuneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sign = ref.watch(profileSignProvider);
    final marriage = ref.watch(marriageProfileProvider);
    final coupleAsync = ref.watch(coupleCompatibilityProvider);

    if (sign == null || marriage == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('طالع ازدواج')),
        body: const ErrorState(message: 'ابتدا تاریخ تولدت را در پروفایل وارد کن.'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('طالع ازدواج')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          GlassCard(
            highlight: true,
            accent: AppTheme.rose,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Text('تو در پیمانِ زندگی', style: _kLabel(theme)),
                const SizedBox(height: 8),
                TraditionEmblem(
                                    accent: AppTheme.rose,
                  child: Text(
                    sign.symbol,
                    style: TextStyle(
                      fontSize: 38,
                      color: theme.brightness == Brightness.dark
                          ? AppTheme.gold
                          : AppTheme.violetDeep,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${sign.nameFa} (${sign.nameEn})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 10),
                NatureChip(
                  'هم‌نواترین برج‌ها: ${marriage['bestFa']! as String}',
                  color: AppTheme.gold,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            accent: AppTheme.rose,
            child: BodyText(marriage['text']! as String),
          ),
          const SizedBox(height: 20),

          const SectionHeader('هم‌نوایی با شریک زندگی‌ات',
            icon: Icons.favorite, iconColor: AppTheme.rose),
          coupleAsync.when(
            data: (couple) {
              if (couple == null) {
                return GlassCard(
                  accent: AppTheme.gold,
                  child: BodyText(
                    'اگر تاریخ تولد شریک زندگی‌ات را در بخش «عشق» وارد کنی، '
                    'امتیاز هم‌نواییِ شما دو نفر هم این‌جا نمایش داده می‌شود.',
                  ),
                );
              }
              return GlassCard(
                highlight: true,
                accent: AppTheme.rose,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('امتیاز هم‌نوایی',
                            style: _kLabel(theme)),
                        const SizedBox(width: 10),
                        Text(
                          '${couple.scores.overall}٪',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.gold,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    BodyText(couple.aspectTitle),
                    const SizedBox(height: 10),
                    Text(
                      'برای تحلیلِ کامل، به سربرگ «عشق» برو.',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const LoadingState(),
            error: (e, _) => const ErrorState(message: 'خطا در محاسبهٔ هم‌نوایی.'),
          ),
          const SizedBox(height: 20),

          const SectionHeader('روایت سنت'),
          GlassCard(child: BodyText(FortunesContent.marriageIntro)),
          const SizedBox(height: 12),
          const MarriageScoreLegend(),
          const DisclaimerCard(),
        ],
      ),
    );
  }

  static TextStyle _kLabel(ThemeData theme) => TextStyle(
        fontSize: 12,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        fontFamily: 'Vazirmatn',
      );
}

/// «این درصدها یعنی چه؟» — the couple-compatibility legend shared with
/// the love tab, shown here under the marriage reading.
class MarriageScoreLegend extends StatelessWidget {
  const MarriageScoreLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final compat = AppContent.compatibility;
    final guide = compat['dimensionGuide']! as Map<String, Object?>;
    final bandsData =
        (compat['scoreBands']! as List<Object?>).whereType<Map>().toList();

    const labels = {
      'love': 'عشق',
      'communication': 'ارتباط',
      'attraction': 'کشش',
      'trust': 'اعتماد',
      'longTerm': 'پایداری',
    };
    const weights = {
      'love': 28,
      'communication': 20,
      'attraction': 20,
      'trust': 16,
      'longTerm': 16,
    };

    return ScoreLegend(
      intro: 'امتیازِ هم‌نوایی با شریک زندگی‌ات از پنج بعد سنجیده می‌شود.',
      accent: AppTheme.rose,
      dimensions: [
        for (final key in labels.keys)
          LegendDimension(
            labels[key]!,
            guide[key]! as String,
            weight: weights[key],
          ),
      ],
      bands: [
        for (final b in bandsData)
          LegendBand(
            b['min']! as int,
            b['label']! as String,
            b['meaning']! as String,
          ),
      ],
      methodNote: compat['methodNote']! as String,
    );
  }
}
