import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../data/content/traditions_content.dart';
import '../../domain/traditions/manazil.dart';
import '../../providers/tradition_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import 'tradition_widgets.dart';

/// سنت ایرانی-اسلامی — احکام نجوم و منازل ۲۸گانهٔ قمر.
class IranianTraditionScreen extends ConsumerWidget {
  const IranianTraditionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final birthManzil = ref.watch(birthManzilProvider);
    final todayManzil = ref.watch(todayManzilProvider);

    if (birthManzil == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('سنت ایرانی-اسلامی')),
        body: const ErrorState(message: 'ابتدا تاریخ تولدت را در پروفایل وارد کن.'),
      );
    }

    final birth = ManazilCalculator.at(birthManzil);
    final today = ManazilCalculator.at(todayManzil);
    final introParts =
        (TraditionsContent.iranianIntro).split('\n\n');

    return Scaffold(
      appBar: AppBar(title: const Text('سنت ایرانی-اسلامی')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Hero: birth mansion ─────────────────────────────────
          GlassCard(
            highlight: true,
            accent: AppTheme.gold,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                TraditionEmblem(
                  accent: AppTheme.gold,
                  child: const Icon(Icons.nightlight_round,
                      size: 38, color: AppTheme.gold),
                ),
                const SizedBox(height: 14),
                Text('منزل ماه در هنگام تولد تو', style: _kLabelStyle(theme)),
                const SizedBox(height: 6),
                Text(
                  birth['name']! as String,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 10),
                NatureChip(
                  'طبیعت: ${birth['nature']! as String}',
                  color: _natureColor(birth['nature']! as String),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            accent: AppTheme.gold,
            child: BodyText(birth['text']! as String),
          ),
          const SizedBox(height: 20),

          // ── Today's mansion ─────────────────────────────────────
          SectionHeader(
            'منزل ماه امروز',
            subtitle:
                'محاسبهٔ زنده — مانزل ${PersianNumbers.toPersianNum(todayManzil + 1)} از ۲۸',
          ),
          GlassCard(
            accent: AppTheme.sky,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      today['name']! as String,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                    NatureChip(
                      today['nature']! as String,
                      color: _natureColor(today['nature']! as String),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                BodyText(today['text']! as String),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── The 28 mansions ─────────────────────────────────────
          const SectionHeader('چرخهٔ ۲۸ منزل قمر',
            icon: Icons.nightlight_round, iconColor: AppTheme.gold),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < 28; i++)
                  NatureChip(
                    ManazilCalculator.at(i)['name']! as String,
                    color: _natureColor(
                        ManazilCalculator.at(i)['nature']! as String),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Tradition intro ─────────────────────────────────────
          const SectionHeader('روایت سنت'),
          GlassCard(
            accent: AppTheme.violet,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final part in introParts) ...[
                  BodyText(part),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const DisclaimerCard(),
        ],
      ),
    );
  }

  static Color _natureColor(String nature) {
    switch (nature) {
      case 'سعد':
        return const Color(0xFF4CD97B);
      case 'نحس':
        return AppTheme.rose;
      default:
        return AppTheme.gold;
    }
  }

  static TextStyle _kLabelStyle(ThemeData theme) => TextStyle(
        fontSize: 12,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        fontFamily: 'Vazirmatn',
      );
}
