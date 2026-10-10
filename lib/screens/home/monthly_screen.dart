import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date/app_date.dart';
import '../../data/analytics/analytics_service.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/horoscope/horoscope_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/horoscope_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/ad_banner.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/premium_badge.dart';
import '../../widgets/rewarded_ad_overlay.dart';
import '../../widgets/score_legend.dart';
import '../premium/premium_screen.dart';
import 'sky_cards.dart';

/// طالع ماهانه — موضوع اصلی ماه + عشق/کار/مالی/انرژی/فرصت/هشدار.
/// Advanced monthly report is premium (product spec §31).
class MonthlyScreen extends ConsumerWidget {
  const MonthlyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlyAsync = ref.watch(monthlyHoroscopeProvider);
    final analytics = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('طالع ماهانه')),
      body: monthlyAsync.when(
        data: (monthly) {
          analytics.logEvent(AnalyticsEvent.monthlyHoroscopeOpened.id);
          return _MonthlyBody(monthly: monthly);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ErrorState(
              message: 'در نمایش طالع ماه مشکلی پیش آمد.',
              onRetry: () => ref.invalidate(monthlyHoroscopeProvider),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyBody extends ConsumerWidget {
  const _MonthlyBody({required this.monthly});

  final MonthlyHoroscope monthly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entitlement = ref.watch(entitlementProvider);
    final monthKey =
        '${monthly.year}-${monthly.month.toString().padLeft(2, '0')}';
    final unlocked = entitlement.unlocksMonthFor(monthKey);

    final monthTitle =
        '${AppDate.monthNames[monthly.month - 1]} ${monthly.year}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        GlassCard(
          highlight: true,
          accent: AppTheme.gold,
          child: Column(
            children: [
              Text(
                'موضوع اصلی ماه',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontFamily: 'Vazirmatn',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                monthTitle,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  fontFamily: 'Vazirmatn',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MonthScore(label: 'عشق', value: monthly.scores.love, color: AppTheme.rose),
                  _MonthScore(label: 'کار', value: monthly.scores.career, color: AppTheme.sky),
                  _MonthScore(label: 'مالی', value: monthly.scores.finance, color: AppTheme.gold),
                  _MonthScore(label: 'انرژی', value: monthly.scores.energy, color: const Color(0xFF4CD97B)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          accent: AppTheme.violet,
          child: Text(
            monthly.focusText,
            style: TextStyle(
              fontSize: 13.5,
              height: 2.05,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
              fontFamily: 'Vazirmatn',
            ),
          ),
        ),
        SkyMonthCard(jalaliMonth: monthly.month),
        const SizedBox(height: 18),
        if (unlocked) ...[
          PremiumSectionTitle('گزارش پیشرفتهٔ ماه',
              active: entitlement.hasPremium),
          const SizedBox(height: 12),
          _MonthCard(
            icon: Icons.favorite,
            color: AppTheme.rose,
            title: 'عشق در این ماه',
            text: monthly.loveText,
          ),
          const SizedBox(height: 12),
          _MonthCard(
            icon: Icons.work_outline,
            color: AppTheme.sky,
            title: 'کار در این ماه',
            text: monthly.careerText,
          ),
          const SizedBox(height: 12),
          _MonthCard(
            icon: Icons.savings_outlined,
            color: AppTheme.gold,
            title: 'مالی در این ماه',
            text: monthly.financeText,
          ),
          const SizedBox(height: 12),
          _MonthCard(
            icon: Icons.bolt_outlined,
            color: const Color(0xFF4CD97B),
            title: 'انرژی در این ماه',
            text: monthly.energyText,
          ),
          const SizedBox(height: 12),
          _MonthCard(
            icon: Icons.auto_awesome,
            color: AppTheme.violet,
            title: 'فرصت‌های ماه',
            text: monthly.opportunityText,
          ),
          const SizedBox(height: 12),
          _MonthCard(
            icon: Icons.warning_amber_rounded,
            color: AppTheme.rose,
            title: 'هشدارهای ماه',
            text: monthly.warningText,
          ),
        ] else ...[
          LockedSection(
            title: 'گزارش پیشرفتهٔ ماه',
            hint: 'عشق، کار، مالی، انرژی، فرصت‌ها و هشدارهای این ماه — ویژهٔ پرمیوم',
            onOpenPremium: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PremiumScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _RewardedMonthUnlockCard(monthKey: monthKey),
        ],
        const SizedBox(height: 12),
        ScoreLegend(
          intro:
              'چهار بعدِ امتیازِ ماهانه — نمایِ بلندمدتِ همان مقیاسی که در طالعِ روزانه می‌بینی.',
          dimensions: [
            LegendDimension('عشق', 'روندِ گرمای عاطفی و رابطه‌ها در طولِ این ماه.'),
            LegendDimension('کار', 'پشتوانه، فرصت‌های حرفه‌ای و مسیرِ پیشرفت در این ماه.'),
            LegendDimension('مالی', 'جریانِ پول، خرج‌ها و دریافتی‌های این ماه.'),
            LegendDimension('انرژی', 'خستگی و نشاطِ کلیِ بدن و ذهن در این ماه.'),
          ],
          bands: ScoreLegendPresets.bands,
          methodNote: ScoreLegendPresets.horoscopeMethod,
        ),
        const SizedBox(height: 14),
        const AdBanner(slot: 3),
      ],
    );
  }
}

/// کارتِ بازکردنِ گزارشِ پیشرفتهٔ ماه با تبلیغِ جایزه‌ای — بدونِ خرید.
class _RewardedMonthUnlockCard extends ConsumerWidget {
  const _RewardedMonthUnlockCard({required this.monthKey});

  final String monthKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // پرمیوم = هیچ تبلیغ و هیچ ریواردی؛ حتی اگر این کارت اشتباهاً در
    // شاخهٔ دیداری قرار بگیرد، رندر نمی‌شود.
    if (ref.watch(entitlementProvider).hasPremium) {
      return const SizedBox.shrink();
    }
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
                  'مشاهدهٔ تبلیغ و دریافت گزارشِ کاملِ این ماه',
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
            'اختیاری است — با تماشای یک تبلیغِ کامل، گزارشِ پیشرفتهٔ همین ماه باز می‌شود.',
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
            child: FilledButton.tonalIcon(
              onPressed: () async {
                analytics.logEvent(AnalyticsEvent.rewardedAdStarted.id);
                final earned = await showRewardedAdOverlay(context);
                if (!earned) return;
                analytics.logEvent(AnalyticsEvent.rewardedAdCompleted.id);
                await ref
                    .read(entitlementProvider.notifier)
                    .earnRewardedMonthlyUnlock(monthKey);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('گزارش پیشرفتهٔ این ماه فعال شد'),
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

class _MonthScore extends StatelessWidget {
  const _MonthScore({
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
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
            fontFamily: 'Vazirmatn',
          ),
        ),
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
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

String _fa(int v) {
  const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  return v.toString().split('').map((c) => fa[int.parse(c)]).join();
}
