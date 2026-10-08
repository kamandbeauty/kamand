import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/horoscope/sky_transits.dart';
import '../../providers/app_providers.dart';
import '../../providers/horoscope_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';

/// «آسمانِ امروز» — the astronomy-driven layer of the daily horoscope:
/// real Moon sign, Moon phase, the Moon's aspect to the natal Sun and
/// the Chaldean weekday ruler (classical sun-column technique).
class SkyTodayCard extends ConsumerWidget {
  const SkyTodayCard({super.key});

  static const List<String> _signIds = [
    'aries', 'taurus', 'gemini', 'cancer', 'leo', 'virgo',
    'libra', 'scorpio', 'sagittarius', 'capricorn', 'aquarius', 'pisces',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(primaryProfileProvider).profile;
    final sign = ref.watch(zodiacSignByIdProvider(profile?.zodiacId ?? ''));
    final now = DateTime.now().toUtc();

    final moonIdx = SkyTransits.moonSignIndex(now);
    final phaseIdx = SkyTransits.moonPhase(now);
    final rulerIdx = SkyTransits.weekdayRulerIndex(now);
    final moon = SkyTransits.moonInSign(moonIdx);
    final phase = SkyTransits.moonPhaseInfo(phaseIdx);
    final ruler = SkyTransits.weekdayRuler(rulerIdx);

    final natalIdx = sign == null ? null : _signIds.indexOf(sign.id);
    final aspect = natalIdx == null
        ? null
        : SkyTransits.aspect(SkyTransits.aspectToSun(moonIdx, natalIdx));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          'آسمانِ امروز',
          subtitle: 'از موقعیتِ واقعیِ ماه و خورشید، همین لحظه',
          icon: Icons.wb_twilight,
          iconColor: AppTheme.violet,
        ),
        GlassCard(
          accent: AppTheme.violet,
          child: Column(
            children: [
              _SkyRow(
                icon: Icons.nightlight_round,
                color: AppTheme.gold,
                label: 'قمر در ${moon['signFa']! as String} (${moon['signEn']! as String})',
                text: moon['text']! as String,
              ),
              if (aspect != null) ...[
                const SizedBox(height: 14),
                _SkyRow(
                  icon: Icons.auto_awesome,
                  color: AppTheme.rose,
                  label: aspect['titleFa']! as String,
                  text: aspect['text']! as String,
                  advice: aspect['advice']! as String,
                ),
              ],
              const SizedBox(height: 14),
              _SkyRow(
                icon: Icons.contrast,
                color: AppTheme.sky,
                label: 'گامِ ماه: ${phase['nameFa']! as String}',
                text: phase['text']! as String,
              ),
              const SizedBox(height: 14),
              _SkyRow(
                icon: Icons.public,
                color: const Color(0xFF4CD97B),
                label:
                    'روزِ ${ruler['dayFa']! as String} — فرمانروا: ${ruler['rulerFa']! as String}',
                text: ruler['text']! as String,
              ),
              const SizedBox(height: 12),
              Text(
                'روشِ کلاسیکِ ستون‌های طالع: ترانزیتِ قمر بر خورشیدِ تولد — '
                'تفسیرِ سنتی است، نه پیش‌بینیِ قطعی.',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.8,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Weekly sky theme card — the Moon's element at the week's start.
class SkyWeekCard extends StatelessWidget {
  const SkyWeekCard({super.key, required this.weekStartUtc});

  /// Saturday of the current week, UTC noon.
  final DateTime weekStartUtc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = SkyTransits.weeklyTheme(weekStartUtc);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          'آسمانِ هفته',
          subtitle: 'تمِ قمر در آغازِ هفته',
          icon: Icons.wb_sunny,
          iconColor: AppTheme.sky,
        ),
        GlassCard(
          accent: AppTheme.sky,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 2.05,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
              fontFamily: 'Vazirmatn',
            ),
          ),
        ),
      ],
    );
  }
}

/// Monthly sky map card — where the Sun actually is this Solar-Hijri
/// month (the Persian calendar is astronomically tied to the zodiac).
class SkyMonthCard extends StatelessWidget {
  const SkyMonthCard({super.key, required this.jalaliMonth});

  final int jalaliMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final season = SkyTransits.monthSeason(jalaliMonth);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'نقشهٔ آسمانِ ماه',
          subtitle: 'خورشید در برجِ ${season['sunSign']! as String} (${season['sunSignEn']! as String})',
          icon: Icons.explore,
          iconColor: AppTheme.gold,
        ),
        GlassCard(
          accent: AppTheme.gold,
          child: Text(
            season['text']! as String,
            style: TextStyle(
              fontSize: 13,
              height: 2.05,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
              fontFamily: 'Vazirmatn',
            ),
          ),
        ),
      ],
    );
  }
}

class _SkyRow extends StatelessWidget {
  const _SkyRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.text,
    this.advice,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String text;
  final String? advice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.14),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  fontFamily: 'Vazirmatn',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.95,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  fontFamily: 'Vazirmatn',
                ),
              ),
              if (advice != null) ...[
                const SizedBox(height: 5),
                Text(
                  '• $advice',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
