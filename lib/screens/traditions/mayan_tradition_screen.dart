import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../data/content/traditions_content.dart';
import '../../providers/tradition_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import 'tradition_widgets.dart';

/// تقویم مقدس مایا — تزولکین ۲۶۰روزه و امضای کیهانی تولد.
class MayanTraditionScreen extends ConsumerWidget {
  const MayanTraditionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tzolkin = ref.watch(tzolkinProvider);

    if (tzolkin == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تقویم مقدس مایا')),
        body: const ErrorState(message: 'ابتدا تاریخ تولدت را در پروفایل وارد کن.'),
      );
    }

    final toneText =
        TraditionsContent.mayanTones[tzolkin.tone.toString()]! as String;

    return Scaffold(
      appBar: AppBar(title: const Text('تقویم مقدس مایا')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Hero: cosmic signature ──────────────────────────────
          GlassCard(
            highlight: true,
            accent: const Color(0xFF4CD97B),
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Text('امضای کیهانیِ تولد تو', style: _kLabelStyle(theme)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    TraditionEmblem(
                      accent: const Color(0xFF4CD97B),
                      size: 66,
                      child: Text(
                        PersianNumbers.toPersianNum(tzolkin.tone),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: theme.brightness == Brightness.dark
                              ? AppTheme.gold
                              : AppTheme.violetDeep,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tzolkin.nawal['nameFa']! as String,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                              fontFamily: 'Vazirmatn',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${tzolkin.nawal['name']! as String}'
                            ' · عدد ${PersianNumbers.toPersianNum(tzolkin.tone)} از ۱۳',
                            style: TextStyle(
                              fontSize: 11.5,
                              color:
                                  theme.colorScheme.onSurface.withValues(alpha: 0.55),
                              fontFamily: 'Vazirmatn',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                BodyText(tzolkin.nawal['text']! as String),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Tone ────────────────────────────────────────────────
          SectionHeader(
            'عدد مقدسِ روز تولد',
            subtitle: 'تُن ${PersianNumbers.toPersianNum(tzolkin.tone)}',
          ),
          GlassCard(
            accent: AppTheme.sky,
            child: BodyText(toneText),
          ),
          const SizedBox(height: 20),

          // ── Tradition intro ─────────────────────────────────────
          const SectionHeader('روایت سنت'),
          GlassCard(child: BodyText(TraditionsContent.mayanIntro)),
          const SizedBox(height: 20),

          // ── All 20 nawals ───────────────────────────────────────
          const SectionHeader('بیست نَوالِ روز'),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in TraditionsContent.mayanNawals)
                  NatureChip(n['nameFa']! as String,
                      color: const Color(0xFF4CD97B)),
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
