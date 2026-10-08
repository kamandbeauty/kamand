import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../data/content/fortunes_content.dart';
import '../../providers/fortune_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../traditions/tradition_widgets.dart';

/// طالع‌بینی یونانی — عنصر، کیفیت، مزاج و اسطورهٔ برج.
class GreekFortuneScreen extends ConsumerWidget {
  const GreekFortuneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sign = ref.watch(profileSignProvider);
    final greek = ref.watch(greekProfileProvider);

    if (sign == null || greek == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('طالع‌بینی یونانی')),
        body: const ErrorState(message: 'ابتدا تاریخ تولدت را در پروفایل وارد کن.'),
      );
    }

    final humorId = greek['humor']! as String;
    final qualityId = greek['quality']! as String;

    return Scaffold(
      appBar: AppBar(title: const Text('طالع‌بینی یونانی')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          GlassCard(
            highlight: true,
            accent: AppTheme.sky,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Text('برج تو در آسمانِ یونان', style: _kLabel(theme)),
                const SizedBox(height: 8),
                TraditionEmblem(
                                    accent: AppTheme.sky,
                  child: Text(
                    sign.symbol,
                    style: TextStyle(
                      fontSize: 38,
                      fontFamilyFallback: const ['NotoSansSymbols'],
                      color: theme.brightness == Brightness.dark
                          ? AppTheme.gold
                          : AppTheme.violetDeep,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  greek['greek']! as String,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    NatureChip('عنصر ${sign.element}', color: AppTheme.rose),
                    NatureChip(FortunesContent.greekQualities[qualityId]!
                        .split(' — ')[0]),
                    NatureChip(
                      'مزاج ${FortunesContent.greekHumors[humorId]!.split(' — ')[0]}',
                      color: AppTheme.violet,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const SectionHeader('اسطورهٔ برج تو'),
          GlassCard(
            accent: AppTheme.sky,
            child: BodyText(greek['myth']! as String),
          ),
          const SizedBox(height: 20),

          const SectionHeader('سه لایهٔ برج در نگاه هلنی'),
          _LayerTile(
            title: 'عنصر',
            value: sign.element,
            text: 'آتش شور، خاک استواری، هوا ذهن، آب احساس — سوختِ اصلیِ برج تو.',
            color: AppTheme.rose,
          ),
          const SizedBox(height: 10),
          _LayerTile(
            title: 'کیفیت',
            value: FortunesContent.greekQualities[qualityId]!,
            color: AppTheme.gold,
          ),
          const SizedBox(height: 10),
          _LayerTile(
            title: 'مزاج (اخلاط چهارگانه)',
            value: FortunesContent.greekHumors[humorId]!,
            color: AppTheme.violet,
          ),
          const SizedBox(height: 20),

          const SectionHeader('روایت سنت'),
          GlassCard(child: BodyText(FortunesContent.greekIntro)),
          const SizedBox(height: 16),
          Text(
            'سیارهٔ راهبرِ برج تو در سنت کهن: ${sign.rulingPlanet}'
            ' · عدد شانس: ${PersianNumbers.toPersianNum(sign.luckyNumbers.first)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontFamily: 'Vazirmatn',
            ),
          ),
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

class _LayerTile extends StatelessWidget {
  const _LayerTile({
    required this.title,
    required this.value,
    required this.color,
    this.text,
  });

  final String title;
  final String value;
  final Color color;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      accent: color,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontFamily: 'Vazirmatn',
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              fontFamily: 'Vazirmatn',
            ),
          ),
          if (text != null) ...[
            const SizedBox(height: 6),
            Text(
              text!,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.9,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                fontFamily: 'Vazirmatn',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
