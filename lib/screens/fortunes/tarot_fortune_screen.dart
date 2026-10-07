import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date/app_date.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../data/content/fortunes_content.dart';
import '../../domain/fortunes/fortune_engines.dart';
import '../../providers/fortune_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../traditions/tradition_widgets.dart';

/// طالع بینی تاروت — کارت تولد + کارت امروز.
class TarotFortuneScreen extends ConsumerWidget {
  const TarotFortuneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sign = ref.watch(profileSignProvider);
    final birthCard = ref.watch(tarotBirthCardProvider);

    if (sign == null || birthCard == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('طالع بینی تاروت')),
        body: const ErrorState(message: 'ابتدا تاریخ تولدت را در پروفایل وارد کن.'),
      );
    }

    final todayCard = Tarot.dailyCard(sign.id, AppDate.dayKey(AppDate.now()));

    return Scaffold(
      appBar: AppBar(title: const Text('طالع بینی تاروت')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Birth card ───────────────────────────────────────────
          GlassCard(
            highlight: true,
            accent: AppTheme.violet,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Text('کارتِ تولد تو', style: _kLabel(theme)),
                const SizedBox(height: 10),
                _CardFrame(
                  child: Column(
                    children: [
                      Text(
                        PersianNumbers.toPersianNum(
                            birthCard['index']! as int),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        birthCard['nameFa']! as String,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        birthCard['nameEn']! as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                BodyText(birthCard['text']! as String),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Card of the day ──────────────────────────────────────
          const SectionHeader('کارتِ امروز تو', subtitle: 'هر روز تازه',
            icon: Icons.style, iconColor: AppTheme.gold),
          GlassCard(
            accent: AppTheme.gold,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CardFrame(
                      size: 64,
                      child: Text(
                        PersianNumbers.toPersianNum(todayCard['index']! as int),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            todayCard['nameFa']! as String,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                              fontFamily: 'Vazirmatn',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            todayCard['nameEn']! as String,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                              fontFamily: 'Vazirmatn',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                BodyText(todayCard['text']! as String),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const SectionHeader('روایت سنت'),
          GlassCard(child: BodyText(FortunesContent.tarotIntro)),
          const SizedBox(height: 20),

          const SectionHeader('۲۲ کارتِ بزرگِ آرکانا'),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in FortunesContent.tarotCards)
                  NatureChip(c['nameFa']! as String,
                      color: AppTheme.violet),
              ],
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

/// Decorative tarot-card frame.
class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.child, this.size = 110});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 30,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.violet.withValues(alpha: 0.16),
            AppTheme.gold.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Center(child: child),
    );
  }
}
