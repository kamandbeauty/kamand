import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date/app_date.dart';
import '../../core/theme/app_theme.dart';
import '../../data/content/fortunes_content.dart';
import '../../domain/fortunes/fortune_engines.dart';
import '../../providers/fortune_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../traditions/tradition_widgets.dart';

/// فال جم‌اوراکل — سنگِ ماهِ تولد + فال سه‌سنگیِ امروز.
class GemOracleScreen extends ConsumerStatefulWidget {
  const GemOracleScreen({super.key});

  @override
  ConsumerState<GemOracleScreen> createState() => _GemOracleScreenState();
}

class _GemOracleScreenState extends ConsumerState<GemOracleScreen> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final birthstone = ref.watch(gemBirthstoneProvider);
    final name = ref.watch(profileNameProvider);

    if (birthstone == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('فال جم‌اوراکل')),
        body: const ErrorState(message: 'ابتدا تاریخ تولدت را در پروفایل وارد کن.'),
      );
    }

    final month = (birthstone['month']! as int);
    final stones = GemOracle.dailyDraw(name, AppDate.dayKey(AppDate.now()));
    final fields = ['عشق', 'کار و پول', 'سلامتی'];
    final fieldColors = [
      AppTheme.rose,
      AppTheme.sky,
      const Color(0xFF4CD97B),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('فال جم‌اوراکل')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Birthstone ───────────────────────────────────────────
          GlassCard(
            highlight: true,
            accent: AppTheme.gold,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Text('سنگِ ماهِ تولد تو', style: _kLabel(theme)),
                const SizedBox(height: 8),
                TraditionEmblem(
                  accent: AppTheme.gold,
                  child: const Icon(Icons.diamond,
                      size: 36, color: AppTheme.gold),
                ),
                const SizedBox(height: 10),
                Text(
                  birthstone['nameFa']! as String,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ماه ${AppDate.monthNames[month - 1]}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            accent: AppTheme.gold,
            child: BodyText(birthstone['text']! as String),
          ),
          const SizedBox(height: 20),

          // ── Daily 3-stone draw ───────────────────────────────────
          SectionHeader(
            'فال سنگ‌های امروز',
            subtitle: 'سه سنگ برای ${fields.join('، ')}',
          ),
          if (!_revealed)
            GlassCard(
              accent: AppTheme.violet,
              child: Column(
                children: [
                  BodyText(
                    'نیت کن… حالا روی سنگ‌ها بزن تا سه سنگِ امروزت — برای عشق، '
                    'کار و سلامتی — باز شود.',
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _revealed = true),
                    icon: const Icon(Icons.diamond_outlined, size: 18),
                    label: const Text('باز کردنِ فالِ امروز'),
                  ),
                ],
              ),
            )
          else ...[
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  accent: fieldColors[i],
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.diamond,
                              size: 16, color: fieldColors[i]),
                          const SizedBox(width: 8),
                          NatureChip(fields[i], color: fieldColors[i]),
                          const Spacer(),
                          Text(
                            stones[i]['nameFa']! as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                              fontFamily: 'Vazirmatn',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      BodyText(stones[i]['text']! as String),
                    ],
                  ),
                ),
              ),
            Text(
              'انتخابِ امروز از روی نام و تاریخ، برای همین روز ثبت شده و فردا تازه می‌شود.',
              style: TextStyle(
                fontSize: 10.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                fontFamily: 'Vazirmatn',
              ),
            ),
          ],
          const SizedBox(height: 20),

          const SectionHeader('روایت سنت'),
          GlassCard(child: BodyText(FortunesContent.gemIntro)),
          const SizedBox(height: 16),
          Text(
            'دوازده سنگِ جم‌اوراکل: '
            '${FortunesContent.gemStones.map((s) => s['nameFa']! as String).join('، ')}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.9,
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
