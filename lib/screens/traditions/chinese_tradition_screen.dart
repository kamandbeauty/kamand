import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../data/content/traditions_content.dart';
import '../../domain/traditions/chinese_zodiac.dart';
import '../../providers/tradition_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import 'tradition_widgets.dart';

/// سنت چینی — animal, element, yin/yang + partner compatibility.
class ChineseTraditionScreen extends ConsumerWidget {
  const ChineseTraditionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sign = ref.watch(chineseSignProvider);
    final partnerSign = ref.watch(partnerChineseSignProvider);

    if (sign == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('طالع‌بینی چینی')),
        body: const ErrorState(message: 'ابتدا تاریخ تولدت را در پروفایل وارد کن.'),
      );
    }

    final animal = sign.animal;
    final element = sign.element;
    final lunarYear = ChineseZodiacCalculator.lunarYearFor(
        ref.watch(birthUtcProvider)!);
    final strengths = (animal['strengths']! as List).cast<String>();
    final weaknesses = (animal['weaknesses']! as List).cast<String>();

    return Scaffold(
      appBar: AppBar(title: const Text('طالع‌بینی چینی')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Hero ────────────────────────────────────────────────
          GlassCard(
            highlight: true,
            accent: AppTheme.rose,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                TraditionEmblem(
                  accent: AppTheme.rose,
                  child: Text(
                    animal['emoji']! as String,
                    style: const TextStyle(fontSize: 40),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'سال ${animal['nameFa']! as String}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    NatureChip(element['nameFa']! as String,
                        color: AppTheme.sky),
                    NatureChip(
                      sign.yang
                          ? TraditionsContent.chinesePolarity['yang']!
                          : TraditionsContent.chinesePolarity['yin']!,
                      color: AppTheme.violet,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'سال چینیِ تو: ${PersianNumbers.toPersianNum(lunarYear)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SectionHeader('روایت سنت', subtitle: 'شنگ‌شیائو 生肖',
            icon: Icons.public, iconColor: AppTheme.rose),
          GlassCard(
            accent: AppTheme.rose,
            child: BodyText(TraditionsContent.chineseIntro),
          ),
          const SizedBox(height: 20),

          // ── Personality ─────────────────────────────────────────
          const SectionHeader('خویِ سال تو'),
          GlassCard(child: BodyText(animal['personality']! as String)),
          const SizedBox(height: 14),
          _ChipRow(
            label: 'قوت‌ها',
            chips: strengths,
            color: const Color(0xFF4CD97B),
          ),
          const SizedBox(height: 10),
          _ChipRow(
            label: 'سایه‌ها',
            chips: weaknesses,
            color: AppTheme.rose,
          ),
          const SizedBox(height: 20),

          // ── Love & work ─────────────────────────────────────────
          const SectionHeader('عشق'),
          GlassCard(
            accent: AppTheme.rose,
            child: BodyText(animal['love']! as String),
          ),
          const SizedBox(height: 14),
          const SectionHeader('کار'),
          GlassCard(
            accent: AppTheme.sky,
            child: BodyText(animal['work']! as String),
          ),
          const SizedBox(height: 20),

          // ── Lucky ───────────────────────────────────────────────
          const SectionHeader('نشانه‌های شانس'),
          Row(
            children: [
              Expanded(
                child: _LuckyTile(
                  icon: Icons.palette_outlined,
                  label: 'رنگ شانس',
                  value: animal['luckyColor']! as String,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LuckyTile(
                  icon: Icons.pin_outlined,
                  label: 'عدد شانس',
                  value: PersianNumbers.toPersianNum(
                      animal['luckyNumber']! as int),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Element explainer ───────────────────────────────────
          SectionHeader('عنصر ${element['nameFa']! as String}'),
          GlassCard(
            accent: AppTheme.sky,
            child: BodyText(element['text']! as String),
          ),
          const SizedBox(height: 20),

          // ── Compatibility ───────────────────────────────────────
          const SectionHeader('هم‌نوازی با شریک زندگی‌ات'),
          if (partnerSign != null) ...[
            _PartnerCompatibility(sign: sign, partnerSign: partnerSign),
          ] else
            GlassCard(
              accent: AppTheme.gold,
              child: BodyText(
                'اگر تاریخ تولد شریک زندگی‌ات را در بخش «عشق» وارد کنی، '
                'هم‌نوازی حیوانِ سال شما دو نفر هم این‌جا نمایش داده می‌شود.',
              ),
            ),
          const DisclaimerCard(),
        ],
      ),
    );
  }
}

class _PartnerCompatibility extends StatelessWidget {
  const _PartnerCompatibility({required this.sign, required this.partnerSign});

  final ChineseSign sign;
  final ChineseSign partnerSign;

  @override
  Widget build(BuildContext context) {
    final level =
        ChineseZodiacCalculator.compatibility(sign.animalIndex, partnerSign.animalIndex);
    final text = TraditionsContent.chineseCompatText[level]!;
    final (color, label) = switch (level) {
      'high' => (const Color(0xFF4CD97B), 'هم‌نوازی بالا'),
      'low' => (AppTheme.rose, 'نیازمند صبر'),
      _ => (AppTheme.gold, 'هم‌نوازی میانه'),
    };
    return GlassCard(
      accent: color,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(sign.animal['emoji']! as String,
                  style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 10),
              Icon(Icons.favorite, size: 18, color: color),
              const SizedBox(width: 10),
              Text(partnerSign.animal['emoji']! as String,
                  style: const TextStyle(fontSize: 30)),
            ],
          ),
          const SizedBox(height: 10),
          NatureChip(label, color: color),
          const SizedBox(height: 10),
          BodyText(text),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.label, required this.chips, required this.color});

  final String label;
  final List<String> chips;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontFamily: 'Vazirmatn',
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in chips) NatureChip(c, color: color),
          ],
        ),
      ],
    );
  }
}

class _LuckyTile extends StatelessWidget {
  const _LuckyTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontFamily: 'Vazirmatn',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              fontFamily: 'Vazirmatn',
            ),
          ),
        ],
      ),
    );
  }
}
