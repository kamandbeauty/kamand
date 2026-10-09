import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date/app_date.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../domain/horoscope/horoscope_models.dart';
import '../../domain/horoscope/sky_transits.dart';
import '../../domain/traditions/sky_math.dart';
import '../../domain/profile/profile.dart';
import '../../domain/zodiac/sign_window.dart';
import '../../domain/zodiac/zodiac_sign.dart';
import '../../providers/app_providers.dart';
import '../../providers/horoscope_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/ad_banner.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mystic_badge.dart';
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
                        const SizedBox(height: 7),
                        Text(
                          _skyLine(ref, today),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.gold.withValues(alpha: 0.9),
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                        if (_signRangeFa(sign, today).isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            _signRangeFa(sign, today),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                              fontFamily: 'Vazirmatn',
                            ),
                          ),
                        ],
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
            description: poeticCategoryPhrase('love', daily.scores.love),
            color: AppTheme.rose,
          ),
          CategoryCard(
            icon: Icons.work_outline,
            title: 'کار',
            score: daily.scores.career,
            description: poeticCategoryPhrase('career', daily.scores.career),
            color: AppTheme.sky,
          ),
        ),
        const SizedBox(height: 12),
        _ScoreCardRow(
          CategoryCard(
            icon: Icons.savings_outlined,
            title: 'مالی',
            score: daily.scores.finance,
            description: poeticCategoryPhrase('finance', daily.scores.finance),
            color: AppTheme.gold,
          ),
          CategoryCard(
            icon: Icons.psychology_outlined,
            title: 'روحیه',
            score: daily.scores.mood,
            description: poeticCategoryPhrase('mood', daily.scores.mood),
            color: AppTheme.violet,
          ),
        ),
        const SizedBox(height: 20),

        // ── پیام امروز ───────────────────────────────────────────
        const SectionHeader(
          'پیام امروز',
          icon: Icons.auto_awesome_outlined,
          iconColor: AppTheme.gold,
        ),
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

        // ── روزهای پیشِ رو (مثل طرح مرجع: Braver Days Ahead) ────────
        const _UpcomingDaysStrip(),

        const SizedBox(height: 20),

        // ── Lucky row ─────────────────────────────────────────────
        const SectionHeader(
          'نشانه‌های شانس امروز',
          icon: Icons.diamond_outlined,
          iconColor: AppTheme.sky,
        ),
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

        // ── آسمانِ امروزِ برج‌ها (نوارِ ۱۲ برج، مثل طرح مرجع) ─────────
        const _ZodiacTodayStrip(),

        const SizedBox(height: 20),

        // ── تبلیغ — با پرمیوم حذف می‌شود ────────────────────────────
        const AdBanner(slot: 0),

        const SizedBox(height: 20),

        // ── World traditions — one clean, beautiful entry ──────────
        GlassCard(
          highlight: true,
          accent: AppTheme.violet,
          padding: const EdgeInsets.all(14),
          onTap: () => _openTraditions(context),
          child: Row(
            children: [
              MysticEmblems.maya.badge(size: 50, showStar: false),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طالع‌بینی در سنت‌های جهان',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '۱۲ سنت و فالِ جهان، همه آفلاین',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55),
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_back_ios_new,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── My week — one clean, beautiful entry ──────────────────
        GlassCard(
          highlight: true,
          accent: AppTheme.rose,
          padding: const EdgeInsets.all(14),
          onTap: () => _openWeekly(context),
          child: Row(
            children: [
              MysticEmblems.months.badge(size: 50, showStar: false),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'فالِ هفتهٔ من',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'طالع هفتگی — شنبه تا جمعه',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55),
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_back_ios_new,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
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
              child: FilledButton.tonalIcon(
                onPressed: () => _openWeekly(context),
                icon: const Icon(Icons.date_range, size: 17),
                label: const Text('طالع هفتگی'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonalIcon(
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

  /// «خورشید در اسد ۱۴° · ماه در دلو» — today's real sky (offline).
  static String _skyLine(WidgetRef ref, Jalali today) {
    final g = AppDate.toGregorian(today);
    final noonUtc = DateTime.utc(g.year, g.month, g.day, 12);
    final jd = SkyMath.julianDay(noonUtc);
    final signs = ref.read(zodiacRepositoryProvider).allSigns();
    final sun = signs[SkyTransits.sunSignIndex(noonUtc)];
    final moon = signs[SkyTransits.moonSignIndex(noonUtc)];
    final sunDeg = (SkyMath.sunLongitude(jd) % 30).round();
    final phase = SkyTransits.moonPhaseInfo(SkyTransits.moonPhase(noonUtc));
    return 'خورشید در ${sun.nameFa} ${PersianNumbers.toPersianNum(sunDeg)}°'
        ' · ماه در ${moon.nameFa} · ${phase['nameFa']! as String}';
  }

  /// Persian-calendar date range of the sign, e.g. «۱ مرداد تا ۳۱ مرداد».
  ///
  /// Shows the window that *contains* today, or the next upcoming one —
  /// wrapping signs (Capricorn) need last-year's window in January, and
  /// past windows roll to next year.
  static String _signRangeFa(ZodiacSign sign, Jalali today) {
    final g = AppDate.toGregorian(today);
    final (start, end) = signWindow(
      startMonth: sign.startMonth,
      startDay: sign.startDay,
      endMonth: sign.endMonth,
      endDay: sign.endDay,
      today: g,
    );

    final js = AppDate.fromGregorian(start);
    final je = AppDate.fromGregorian(end);
    String fa(int v) => PersianNumbers.toPersian(v.toString());
    return '${fa(js.day)} ${AppDate.monthNames[js.month - 1]}'
        ' تا ${fa(je.day)} ${AppDate.monthNames[je.month - 1]}';
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

Jalali _parseDayKey(String key) {
  final p = key.split('-');
  return AppDate.fromYMD(
    int.parse(p[0]),
    int.parse(p[1]),
    int.parse(p[2]),
  );
}

/// One-word theme for a day, from its strongest category.
String _dayThemeWord(DailyHoroscope d) {
  final scores = {
    'عشق': d.scores.love,
    'کار': d.scores.career,
    'فرصتِ مالی': d.scores.finance,
    'آرامشِ روح': d.scores.mood,
  };
  var best = 'آرامشِ روح';
  var bestScore = -1;
  scores.forEach((k, v) {
    if (v > bestScore) {
      best = k;
      bestScore = v;
    }
  });
  return 'روزِ $best';
}

/// «روزهای پیشِ رو» — the next three days as compact cards.
class _UpcomingDaysStrip extends ConsumerWidget {
  const _UpcomingDaysStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(upcomingDaysProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          'روزهای پیشِ رو',
          icon: Icons.calendar_today,
          iconColor: AppTheme.rose,
        ),
        async.when(
          data: (days) => IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WeeklyScreen()),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppDate.weekDayName(_parseDayKey(days[i].date)),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _dayThemeWord(days[i]),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            height: 1.6,
                            color: AppTheme.rose,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${PersianNumbers.toPersianNum(days[i].scores.overall)}٪',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                ],
              ],
            ),
          ),
          loading: () => const LoadingState(height: 90),
          error: (e, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        Text(
          'درصدِ هر روز، امتیازِ کلیِ همان روز است؛ روی کارت بزن تا طالعِ هفته را ببینی.',
          style: TextStyle(
            fontSize: 10.5,
            height: 1.9,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontFamily: 'Vazirmatn',
          ),
        ),
      ],
    );
  }
}

/// «آسمانِ امروزِ برج‌ها» — the twelve-sign strip with each sign's
/// overall percentage for today (mockup: the scrollable zodiac row).
class _ZodiacTodayStrip extends ConsumerWidget {
  const _ZodiacTodayStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(primaryProfileProvider).profile;
    final async = ref.watch(allSignsTodayProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          'آسمانِ امروزِ برج‌ها',
          icon: Icons.auto_awesome_outlined,
          iconColor: AppTheme.gold,
        ),
        async.when(
          data: (days) => SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final d = days[i];
                final sign =
                    ref.watch(zodiacSignByIdProvider(d.zodiacId));
                final mine = profile?.zodiacId == d.zodiacId;
                return GlassCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  onTap: () =>
                      _openSignToday(context, sign, d, mine),
                  accent: mine ? AppTheme.gold : null,
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ZodiacSymbol(sign?.symbol ?? '', fontSize: 20),
                        const SizedBox(height: 5),
                        Text(
                          sign?.nameFa ?? '',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight:
                                mine ? FontWeight.w800 : FontWeight.w600,
                            color: mine
                                ? AppTheme.gold
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.8),
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${PersianNumbers.toPersianNum(d.scores.overall)}٪',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          loading: () => const LoadingState(height: 100),
          error: (e, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        Text(
          'درصدِ هر برج، امتیازِ کلیِ امروزِ همان برج است؛ روی هر برج بزن تا جزئیاتش را ببینی. برجِ خودت با رنگِ طلایی مشخص است.',
          style: TextStyle(
            fontSize: 10.5,
            height: 1.9,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontFamily: 'Vazirmatn',
          ),
        ),
      ],
    );
  }

  void _openSignToday(
      BuildContext context, ZodiacSign? sign, DailyHoroscope d, bool mine) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.gold.withValues(alpha: 0.12),
                      ),
                      child: Center(
                        child: ZodiacSymbol(sign?.symbol ?? '', fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'امروزِ ${sign?.nameFa ?? ''}'
                        '${mine ? ' — برجِ تو' : ''}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                    ),
                    ScoreRing(score: d.scores.overall, size: 52),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  d.generalText,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 2,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.85),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'امتیازها — عشق ${PersianNumbers.toPersianNum(d.scores.love)}'
                  ' · کار ${PersianNumbers.toPersianNum(d.scores.career)}'
                  ' · مالی ${PersianNumbers.toPersianNum(d.scores.finance)}'
                  ' · روحیه ${PersianNumbers.toPersianNum(d.scores.mood)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.55),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
