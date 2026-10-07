import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/content/fortunes_content.dart';
import '../../providers/fortune_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../traditions/tradition_widgets.dart';

/// خصوصیات متولدین ماه‌های سال (تقویم خورشیدی).
class MonthTraitsScreen extends ConsumerWidget {
  const MonthTraitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trait = ref.watch(monthTraitProvider);

    if (trait == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('متولدین ماه‌های سال')),
        body: const ErrorState(message: 'ابتدا تاریخ تولدت را در پروفایل وارد کن.'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('متولدین ماه‌های سال')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          GlassCard(
            highlight: true,
            accent: AppTheme.gold,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Text('ماهِ تولد تو', style: _kLabel(theme)),
                const SizedBox(height: 8),
                TraditionEmblem(
                  accent: AppTheme.gold,
                  child: const Icon(Icons.calendar_month,
                      size: 36, color: AppTheme.gold),
                ),
                const SizedBox(height: 10),
                Text(
                  trait['title']! as String,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            accent: AppTheme.gold,
            child: BodyText(trait['text']! as String),
          ),
          const SizedBox(height: 20),

          const SectionHeader('۱۲ ماهِ سال، ۱۲ خو'),
          for (final m in FortunesContent.monthTraits)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m['title']! as String,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m['text']! as String,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.95,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          const SectionHeader('روایت سنت'),
          GlassCard(child: BodyText(FortunesContent.monthIntro)),
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
