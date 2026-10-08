import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../data/content/traditions_content.dart';
import '../../domain/traditions/numerology.dart';
import '../../providers/tradition_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mystic_badge.dart';
import 'tradition_widgets.dart';

/// فراشماره (عدد مسیر زندگی + سال شخصی) و حساب ابجد نام.
class NumerologyTraditionScreen extends ConsumerWidget {
  const NumerologyTraditionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lifePath = ref.watch(lifePathProvider);
    final personalYear = ref.watch(personalYearProvider);
    final abjad = ref.watch(abjadValueProvider);

    if (lifePath == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('فراشماره و ابجد')),
        body: const ErrorState(message: 'ابتدا تاریخ تولدت را در پروفایل وارد کن.'),
      );
    }

    final number = TraditionsContent
        .numerologyNumbers[lifePath.toString()]! as Map<String, Object?>;
    final yearText = personalYear == null
        ? null
        : TraditionsContent.numerologyPersonalYear[personalYear.toString()];

    return Scaffold(
      appBar: AppBar(title: const Text('فراشماره و ابجد')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Hero: life path ─────────────────────────────────────
          GlassCard(
            highlight: true,
            accent: AppTheme.sky,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                const Text('عدد مسیر زندگی', style: _kLabelStyle),
                const SizedBox(height: 6),
                TraditionEmblem(
                  asset: MysticEmblems.numerology.asset,
                  accent: AppTheme.sky,
                  child: Text(
                    PersianNumbers.toPersianNum(lifePath),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: theme.brightness == Brightness.dark
                          ? AppTheme.gold
                          : AppTheme.violetDeep,
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  number['title']! as String,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(accent: AppTheme.sky, child: BodyText(number['text']! as String)),
          const SizedBox(height: 20),

          // ── Personal year ───────────────────────────────────────
          if (personalYear != null && yearText != null) ...[
            SectionHeader(
              'سال شخصی',
              subtitle:
                  'عدد ${PersianNumbers.toPersianNum(personalYear)} از چرخهٔ ۹تایی',
            ),
            GlassCard(
              accent: AppTheme.gold,
              child: BodyText(yearText),
            ),
            const SizedBox(height: 20),
          ],

          // ── Abjad ───────────────────────────────────────────────
          const SectionHeader('حساب ابجدِ نام تو'),
          GlassCard(
            accent: AppTheme.violet,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BodyText(TraditionsContent.abjadIntro),
                if (abjad != null) ...[
                  const SizedBox(height: 14),
                  Builder(builder: (context) {
                    final reduced =
                        NumerologyCalculator.abjadReduced(abjad);
                    final meaning = TraditionsContent
                        .numerologyNumbers[reduced.toString()]!
                        as Map<String, Object?>;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            NatureChip(
                              'جمع ابجد نام: ${PersianNumbers.format(abjad)}',
                              color: AppTheme.violet,
                            ),
                            NatureChip(
                              'عدد تفسیری: ${PersianNumbers.toPersianNum(reduced)}',
                              color: AppTheme.sky,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        BodyText(meaning['text']! as String),
                      ],
                    );
                  }),
                ] else
                  const SizedBox(height: 4),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Tradition intro ─────────────────────────────────────
          const SectionHeader('روایت سنت'),
          GlassCard(child: BodyText(TraditionsContent.numerologyIntro)),
          const DisclaimerCard(),
        ],
      ),
    );
  }
}

const _kLabelStyle = TextStyle(
  fontSize: 12,
  fontFamily: 'Vazirmatn',
);
