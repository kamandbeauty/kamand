import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date/app_date.dart';
import '../../data/analytics/analytics_service.dart';
import '../../data/share/share_service.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/horoscope/horoscope_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/horoscope_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../premium/premium_screen.dart';

/// طالع کامل امروز — premium deep content with a rewarded-unlock path.
class DailyScreen extends ConsumerWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAsync = ref.watch(dailyHoroscopeProvider);
    final analytics = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('طالع امروز'),
        actions: [
          IconButton(
            tooltip: 'اشتراک‌گذاری طالع امروز',
            icon: const Icon(Icons.share_outlined, size: 20),
            onPressed: () {
              final d = dailyAsync.asData?.value;
              if (d == null) return;
              analytics.logEvent(AnalyticsEvent.dailyShared.id);
              ShareService.share(
                '✦ طالع من — ${AppDate.formatFull(AppDate.now())}\n\n'
                '${d.generalText}\n\n'
                'عشق ${d.scores.love}٪ · کار ${d.scores.career}٪ · '
                'مالی ${d.scores.finance}٪ · حال‌وهوا ${d.scores.mood}٪\n\n'
                'رنگ شانس: ${d.lucky.color} · عدد شانس: ${d.lucky.number} · '
                'ساعت شانس: ${d.lucky.time}',
              );
            },
          ),
        ],
      ),
      body: dailyAsync.when(
        data: (daily) {
          analytics.logEvent(AnalyticsEvent.dailyHoroscopeOpened.id);
          return _DailyBody(daily: daily);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ErrorState(
              message: 'در نمایش طالع امروز مشکلی پیش آمد.',
              onRetry: () => ref.invalidate(dailyHoroscopeProvider),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyBody extends ConsumerWidget {
  const _DailyBody({required this.daily});

  final DailyHoroscope daily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(primaryProfileProvider).profile;
    final sign = ref.watch(zodiacSignByIdProvider(profile?.zodiacId ?? ''));
    final entitlement = ref.watch(entitlementProvider);
    final unlocked = entitlement.unlocksDailyFor(daily.date);

    if (profile == null || sign == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: const [ErrorState(message: 'پروفایل یافت نشد.')],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // Hero
        GlassCard(
          highlight: true,
          accent: AppTheme.violet,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ZodiacSymbol(sign.symbol, fontSize: 42),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sign.nameFa,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                      Text(
                        AppDate.formatFull(AppDate.now()),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MiniScore(label: 'عشق', value: daily.scores.love, color: AppTheme.rose),
                  _MiniScore(label: 'کار', value: daily.scores.career, color: AppTheme.sky),
                  _MiniScore(label: 'مالی', value: daily.scores.finance, color: AppTheme.gold),
                  _MiniScore(label: 'روحیه', value: daily.scores.mood, color: AppTheme.violet),
                  _MiniScore(label: 'انرژی', value: daily.scores.energy, color: const Color(0xFF4CD97B)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        const SectionHeader('پیام امروز'),
        GlassCard(
          accent: AppTheme.gold,
          child: Text(
            daily.generalText,
            style: TextStyle(
              fontSize: 13.5,
              height: 2.1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
              fontFamily: 'Vazirmatn',
            ),
          ),
        ),
        const SizedBox(height: 18),

        // ── Premium deep sections ─────────────────────────────
        if (unlocked) ...[
          _DeepCard(
            icon: Icons.favorite,
            color: AppTheme.rose,
            title: 'عشق و رابطه',
            text: daily.loveText,
          ),
          const SizedBox(height: 12),
          _DeepCard(
            icon: Icons.work_outline,
            color: AppTheme.sky,
            title: 'کار و مسیر حرفه‌ای',
            text: daily.careerText,
          ),
          const SizedBox(height: 12),
          _DeepCard(
            icon: Icons.savings_outlined,
            color: AppTheme.gold,
            title: 'مالی',
            text: daily.financeText,
          ),
          const SizedBox(height: 12),
          _DeepCard(
            icon: Icons.psychology_outlined,
            color: AppTheme.violet,
            title: 'روحیه',
            text: daily.moodText,
          ),
          const SizedBox(height: 12),
          _DeepCard(
            icon: Icons.warning_amber_rounded,
            color: AppTheme.rose,
            title: 'هشدار امروز',
            text: daily.warningText,
          ),
          const SizedBox(height: 12),
          _DeepCard(
            icon: Icons.auto_awesome,
            color: const Color(0xFF4CD97B),
            title: 'فرصت امروز',
            text: daily.opportunityText,
          ),
        ] else ...[
          LockedSection(
            title: 'طالع کامل امروز',
            hint: 'تحلیل عمیق عشق، کار، مالی، روحیه + هشدار و فرصتِ امروز',
            onOpenPremium: () => _openPremium(context),
          ),
          const SizedBox(height: 12),
          _RewardedUnlockCard(daily: daily),
        ],
        const SizedBox(height: 10),
        Text(
          'این محتوا جنبهٔ سرگرمی و تفسیری دارد و پیش‌بینی قطعی نیست.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            fontFamily: 'Vazirmatn',
          ),
        ),
      ],
    );
  }

  void _openPremium(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PremiumScreen()),
    );
  }
}

class _MiniScore extends StatelessWidget {
  const _MiniScore({
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
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            fontFamily: 'Vazirmatn',
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${_fa(value)}٪',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
            fontFamily: 'Vazirmatn',
          ),
        ),
      ],
    );
  }
}

class _DeepCard extends StatelessWidget {
  const _DeepCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 2.05,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              fontFamily: 'Vazirmatn',
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardedUnlockCard extends ConsumerWidget {
  const _RewardedUnlockCard({required this.daily});

  final DailyHoroscope daily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final analytics = ref.watch(analyticsProvider);
    return GlassCard(
      accent: AppTheme.sky,
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle_outline, size: 22, color: AppTheme.sky),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'مشاهدهٔ تبلیغ و دریافت تحلیل کاملِ امروز',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'اختیاری است — با یک تبلیغ (نسخهٔ نمایشی)، طالع کامل همین روز باز می‌شود.',
            style: TextStyle(
              fontSize: 11,
              height: 1.8,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              fontFamily: 'Vazirmatn',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                analytics.logEvent(AnalyticsEvent.rewardedAdStarted.id);
                await ref
                    .read(entitlementProvider.notifier)
                    .earnRewardedUnlock(daily.date);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('طالع کامل امروز فعال شد'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.smart_display_outlined, size: 17),
              label: const Text('مشاهدهٔ تبلیغ'),
            ),
          ),
        ],
      ),
    );
  }
}

String _fa(int v) {
  const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  return v.toString().split('').map((c) => fa[int.parse(c)]).join();
}
