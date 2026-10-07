import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date/app_date.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../domain/horoscope/horoscope_models.dart';
import '../../domain/profile/profile.dart';
import '../../providers/app_providers.dart';
import '../../providers/horoscope_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../settings/settings_screen.dart';
import '../traditions/traditions_hub_screen.dart';
import 'daily_screen.dart';
import 'monthly_screen.dart';
import 'weekly_screen.dart';

/// خانه — the most important screen of the app (product spec §9).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(primaryProfileProvider);
    final profile = profileState.profile;

    if (!profileState.ready) {
      return const _HomeScaffold(child: LoadingState(height: 220));
    }
    if (profile == null) {
      return const _HomeScaffold(
        child: ErrorState(message: 'پروفایلی یافت نشد. یک بار دیگر وارد شو.'),
      );
    }

    final dailyAsync = ref.watch(dailyHoroscopeProvider);
    final sign = ref.watch(zodiacSignByIdProvider(profile.zodiacId));

    return _HomeScaffold(
      child: dailyAsync.when(
        data: (daily) => _HomeContent(profile: profile, daily: daily),
        loading: () => const LoadingState(height: 260, message: 'در حال چیدن طالع امروز…'),
        error: (e, _) => ErrorState(
          message: 'در نمایش طالع امروز مشکلی پیش آمد.',
          onRetry: () => ref.invalidate(dailyHoroscopeProvider),
        ),
      ),
      signName: sign?.nameFa,
    );
  }
}

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold({required this.child, this.signName});

  final Widget child;
  final String? signName;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          child,
          if (signName != null) const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.profile, required this.daily});

  final Profile profile;
  final DailyHoroscope daily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sign =
        ref.watch(zodiacSignByIdProvider(profile.zodiacId));
    final today = AppDate.now();
    final entitlement = ref.watch(entitlementProvider);
    final dayUnlocked = entitlement.unlocksDailyFor(daily.date);

    if (sign == null) {
      return const ErrorState(message: 'اطلاعات برج یافت نشد.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Greeting ──────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'سلام ${profile.name}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppDate.formatFull(today),
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                ],
              ),
            ),
            GlassCard(
              padding: const EdgeInsets.all(10),
              onTap: () => _openSettings(context),
              child: Icon(Icons.settings_outlined,
                  size: 20, color: theme.colorScheme.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // ── Hero card ─────────────────────────────────────────────
        GlassCard(
          highlight: true,
          accent: AppTheme.violet,
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          AppTheme.violet.withValues(alpha: 0.30),
                          AppTheme.gold.withValues(alpha: 0.22),
                        ],
                      ),
                      border: Border.all(
                        color: AppTheme.gold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Center(
                      child: ZodiacSymbol(sign.symbol, fontSize: 44),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'طالع امروز تو',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          sign.nameFa,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          AppDate.formatMedium(today),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                      ],
                    ),
                  ),
                  ScoreRing(score: daily.scores.overall, size: 84),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Four categories ───────────────────────────────────────
        // Auto-height rows (not a fixed-aspect grid) so the cards never
        // overflow on narrow screens or at large text scales.
        _ScoreCardRow(
          CategoryCard(
            icon: Icons.favorite,
            title: 'عشق',
            score: daily.scores.love,
            description: shortScorePhrase(daily.scores.love),
            color: AppTheme.rose,
          ),
          CategoryCard(
            icon: Icons.work_outline,
            title: 'کار',
            score: daily.scores.career,
            description: shortScorePhrase(daily.scores.career),
            color: AppTheme.sky,
          ),
        ),
        const SizedBox(height: 12),
        _ScoreCardRow(
          CategoryCard(
            icon: Icons.savings_outlined,
            title: 'مالی',
            score: daily.scores.finance,
            description: shortScorePhrase(daily.scores.finance),
            color: AppTheme.gold,
          ),
          CategoryCard(
            icon: Icons.psychology_outlined,
            title: 'روحیه',
            score: daily.scores.mood,
            description: shortScorePhrase(daily.scores.mood),
            color: AppTheme.violet,
          ),
        ),
        const SizedBox(height: 20),

        // ── پیام امروز ───────────────────────────────────────────
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
        const SizedBox(height: 20),

        // ── Lucky row ─────────────────────────────────────────────
        const SectionHeader('نشانه‌های شانس امروز'),
        Row(
          children: [
            Expanded(
              child: _LuckyTile(
                icon: Icons.palette_outlined,
                label: 'رنگ شانس',
                value: daily.lucky.color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LuckyTile(
                icon: Icons.pin_outlined,
                label: 'عدد شانس',
                value: PersianNumbers.toPersian(
                  daily.lucky.number.toString(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LuckyTile(
                icon: Icons.schedule,
                label: 'ساعت مناسب',
                value: daily.lucky.time,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── World traditions ──────────────────────────────────────
        SectionHeader(
          'طالع‌بینی در سنت‌های جهان',
          subtitle: '۱۲ سنت و فالِ جهان، همه آفلاین',
          action: TextButton(
            onPressed: () => _openTraditions(context),
            child: const Text('مشاهده'),
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.all(14),
          onTap: () => _openTraditions(context),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TraditionDot(icon: Icons.temple_buddhist, color: AppTheme.rose),
              _TraditionDot(icon: Icons.calculate_outlined, color: AppTheme.sky),
              _TraditionDot(icon: Icons.nightlight_round, color: AppTheme.gold),
              _TraditionDot(icon: Icons.self_improvement, color: AppTheme.violet),
              _TraditionDot(icon: Icons.account_balance, color: Color(0xFF4CD97B)),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Weekly preview ────────────────────────────────────────
        SectionHeader(
          'هفتهٔ من',
          subtitle: 'شنبه تا جمعه',
          action: TextButton(
            onPressed: () => _openWeekly(context),
            child: const Text('مشاهدهٔ هفته'),
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.all(14),
          onTap: () => _openWeekly(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                _WeekDot(label: AppDate.weekDayNames[i][0]),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── CTA ───────────────────────────────────────────────────
        FilledButton.icon(
          onPressed: () => _openDaily(context),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
          ),
          icon: Icon(
            dayUnlocked ? Icons.auto_awesome : Icons.lock_outline,
            size: 18,
          ),
          label: Text(dayUnlocked ? 'طالع کامل امروز' : 'طالع کامل امروز (پرمیوم)'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openWeekly(context),
                icon: const Icon(Icons.date_range, size: 17),
                label: const Text('طالع هفتگی'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openMonthly(context),
                icon: const Icon(Icons.calendar_month_outlined, size: 17),
                label: const Text('طالع ماهانه'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openDaily(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DailyScreen()),
    );
  }

  void _openWeekly(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WeeklyScreen()),
    );
  }

  void _openMonthly(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MonthlyScreen()),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openTraditions(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TraditionsHubScreen()),
    );
  }
}

/// Small circular icon badge for the traditions row on the home screen.
class _TraditionDot extends StatelessWidget {
  const _TraditionDot({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _LuckyTile extends StatelessWidget {
  const _LuckyTile({
    required this.icon,
    required this.label,
    required this.value,
  });

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
              fontSize: 11.5,
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

class _WeekDot extends StatelessWidget {
  const _WeekDot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontFamily: 'Vazirmatn',
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// Two score cards side by side, equal height, sized to their content.
class _ScoreCardRow extends StatelessWidget {
  const _ScoreCardRow(this.left, this.right);

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      ),
    );
  }
}
