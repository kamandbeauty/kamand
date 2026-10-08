import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../core/date/app_date.dart';
import '../../data/analytics/analytics_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../domain/horoscope/horoscope_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/horoscope_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/score_legend.dart';
import 'sky_cards.dart';

/// طالع هفتگی — شنبه تا جمعه با امتیاز روزانه + خلاصهٔ هفته.
class WeeklyScreen extends ConsumerWidget {
  const WeeklyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyAsync = ref.watch(weeklyHoroscopeProvider);
    final analytics = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('طالع هفتگی')),
      body: weeklyAsync.when(
        data: (weekly) {
          analytics.logEvent(AnalyticsEvent.weeklyHoroscopeOpened.id);
          return _WeeklyBody(weekly: weekly);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ErrorState(
              message: 'در نمایش طالع هفته مشکلی پیش آمد.',
              onRetry: () => ref.invalidate(weeklyHoroscopeProvider),
            ),
          ],
        ),
      ),
    );
  }
}

DateTime _weekStartUtc(Jalali weekStart) {
  final g = weekStart.toDateTime();
  return DateTime.utc(g.year, g.month, g.day, 12);
}

class _WeeklyBody extends StatelessWidget {
  const _WeeklyBody({required this.weekly});

  final WeeklyHoroscope weekly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = AppDate.now();
    final todayKey = AppDate.dayKey(today);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        GlassCard(
          highlight: true,
          accent: AppTheme.violet,
          child: Column(
            children: [
              Text(
                'خلاصهٔ هفته',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontFamily: 'Vazirmatn',
                ),
              ),
              const SizedBox(height: 10),
              ScoreRing(score: weekly.average.overall, size: 96),
              const SizedBox(height: 12),
              Text(
                weekly.summaryText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 2.05,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ],
          ),
        ),
        SkyWeekCard(weekStartUtc: _weekStartUtc(weekly.weekStart)),
        const SizedBox(height: 18),
        for (final day in weekly.days)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DayRow(
              day: day,
              isToday: AppDate.dayKey(day.date) == todayKey,
            ),
          ),
        const SizedBox(height: 6),
        ScoreLegend(
          intro:
              'امتیازِ هر روز از همان پنج بعدِ طالعِ روزانه ساخته می‌شود و حلقهٔ هفته، میانگینِ آن‌هاست.',
          dimensions: ScoreLegendPresets.horoscopeDimensions,
          bands: ScoreLegendPresets.bands,
          methodNote: ScoreLegendPresets.horoscopeMethod,
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.isToday});

  final WeeklyDay day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = day.scores;

    return GlassCard(
      highlight: isToday,
      accent: isToday ? AppTheme.gold : null,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                AppDate.weekDayName(day.date),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  fontFamily: 'Vazirmatn',
                ),
              ),
              const SizedBox(width: 8),
              if (isToday)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    'امروز',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.gold,
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                AppDate.formatMedium(day.date),
                style: TextStyle(
                  fontSize: 10.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Bar(label: 'عشق', value: s.love, color: AppTheme.rose)),
              const SizedBox(width: 8),
              Expanded(child: _Bar(label: 'کار', value: s.career, color: AppTheme.sky)),
              const SizedBox(width: 8),
              Expanded(child: _Bar(label: 'مالی', value: s.finance, color: AppTheme.gold)),
              const SizedBox(width: 8),
              Expanded(child: _Bar(label: 'روحیه', value: s.mood, color: AppTheme.violet)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value / 100),
          duration: const Duration(milliseconds: 700),
          builder: (context, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 5,
              color: color,
              backgroundColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            fontFamily: 'Vazirmatn',
          ),
        ),
        Text(
          PersianNumbers.percent(value),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
            fontFamily: 'Vazirmatn',
          ),
        ),
      ],
    );
  }
}
