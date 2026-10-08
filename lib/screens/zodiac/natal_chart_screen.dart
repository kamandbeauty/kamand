import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/astrology/natal_chart.dart';
import '../../domain/astrology/natal_engine.dart';
import '../../domain/astrology/natal_transits.dart';
import '../../data/content/natal_content.dart';
import '../../data/share/share_service.dart';
import '../../providers/app_providers.dart';
import '../../providers/horoscope_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/natal_wheel.dart';
import '../premium/premium_screen.dart';
import '../traditions/tradition_widgets.dart';

/// نقشهٔ تولد — real birth-chart reading (premium).
///
/// Free preview: Sun & Moon placements. Premium: the full chart —
/// planets, retrogrades, ascendant, equal houses, Ptolemaic aspects and
/// the dominant element. Everything is computed offline on the device.
class NatalChartScreen extends ConsumerWidget {
  const NatalChartScreen({super.key});

  static const Map<String, String> _aspectTitlesFa = {
    'conjunction': 'هم‌مقری',
    'sextile': 'تسدید',
    'square': 'تربیع',
    'trine': 'تثلیث',
    'opposition': 'مقابله',
  };

  static const Map<String, Color> _aspectColors = {
    'conjunction': AppTheme.violet,
    'sextile': AppTheme.sky,
    'square': AppTheme.rose,
    'trine': Color(0xFF4CD97B),
    'opposition': AppTheme.gold,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(primaryProfileProvider).profile;
    final entitlement = ref.watch(entitlementProvider);

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('نقشهٔ تولد')),
        body: const ErrorState(message: 'ابتدا تاریخ تولدت را در پروفایل وارد کن.'),
      );
    }

    final parsed = parseJalaliDateKey(profile.birthDate);
    if (parsed == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('نقشهٔ تولد')),
        body: const ErrorState(
            message: 'تاریخ تولدِ پروفایل معتبر نیست؛ از تنظیمات اصلاحش کن.'),
      );
    }

    final coords = NatalEngine.coordsForCity(profile.birthCity);
    final hasTime = profile.birthTimeKnown && profile.birthTime != null;
    final utc = NatalEngine.jalaliBirthToUtc(
      parsed.year, parsed.month, parsed.day, hasTime ? profile.birthTime : null,
    );
    final chart = NatalEngine.compute(
      utc,
      latitude: coords?.first,
      longitude: coords?.last,
      withHouses: hasTime && coords != null,
    );

    final sun = chart.planetPositions.firstWhere((p) => p.body == 'sun');
    final moon = chart.planetPositions.firstWhere((p) => p.body == 'moon');
    final sunSign = ref.watch(zodiacSignByIdProvider(sun.signId));
    final moonSign = ref.watch(zodiacSignByIdProvider(moon.signId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('نقشهٔ تولد'),
        actions: [
          IconButton(
            tooltip: 'اشتراک‌گذاری',
            icon: const Icon(Icons.share_rounded, size: 20),
            onPressed: () {
              final asc = chart.ascendant;
              ShareService.share(
                '✨ نقشهٔ تولدِ من\n'
                'خورشید در ${sunSign?.nameFa ?? ''} · ماه در '
                '${moonSign?.nameFa ?? ''}'
                '${asc != null ? ' · طالعِ دقیق: ${ref.read(zodiacSignByIdProvider(asc.signId))?.nameFa ?? ''}' : ''}\n\n'
                'با اپِ «طالع بین» نقشهٔ تولدت را ببین — کاملاً آفلاین',
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          GlassCard(
            highlight: true,
            accent: AppTheme.violet,
            child: Text(
              NatalContent.chartIntro,
              style: TextStyle(
                fontSize: 13,
                height: 2.1,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                fontFamily: 'Vazirmatn',
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Free preview: Sun & Moon ─────────────────────────────
          const SectionHeader('خورشید و ماهِ تو',
              icon: Icons.wb_sunny, iconColor: AppTheme.gold),
          GlassCard(
            accent: AppTheme.gold,
            child: Column(
              children: [
                _BodyRow(
                  symbol: sunSign?.symbol ?? '',
                  title:
                      'خورشید در ${sunSign?.nameFa ?? ''} — جوهرهٔ وجودِ تو',
                  text: sunSign?.personality ?? '',
                ),
                const SizedBox(height: 14),
                _BodyRow(
                  symbol: moonSign?.symbol ?? '',
                  title:
                      'ماه در ${moonSign?.nameFa ?? ''} — دنیای احساسِ تو',
                  text: NatalContent.natalMoonInSign[moon.signId] ?? '',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (!hasTime)
            GlassCard(
              accent: AppTheme.sky,
              child: BodyText(NatalContent.noTimeNote),
            )
          else if (coords == null)
            GlassCard(
              accent: AppTheme.sky,
              child: BodyText(NatalContent.cityUnknownNote),
            ),
          if (!hasTime || coords == null) const SizedBox(height: 16),

          // ── Premium: the full chart ─────────────────────────────
          if (!entitlement.hasPremium)
            LockedSection(
              title: 'نقشهٔ کاملِ تولد',
              hint:
                  'سه‌گانهٔ بزرگ، جایگاهِ همهٔ سیاره‌ها تا نپتون، پس‌روی‌ها، طالعِ دقیق، خانه‌ها، زاویه‌ها، عنصرِ غالب و ترانزیت‌های امروز — ویژهٔ پرمیوم',
              onOpenPremium: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              ),
            )
          else ...[
            const SectionHeader('چرخِ فلکیِ تولد',
                icon: Icons.donut_large_rounded, iconColor: AppTheme.gold),
            GlassCard(
              highlight: true,
              accent: AppTheme.gold,
              child: Column(
                children: [
                  Center(
                    child: NatalWheel(chart: chart),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    chart.ascendant != null
                        ? 'نمای آسمانِ لحظهٔ تولدت — طالعِ دقیق در سمتِ چپ (پیکانِ طلایی) و سیاره‌ها در جایگاهِ واقعی‌شان'
                        : 'نمای آسمانِ لحظهٔ تولدت — سیاره‌ها در جایگاهِ واقعی‌شان (برای چرخشِ چرخ بر پایهٔ طالعِ دقیق، ساعتِ تولد لازم است)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.9,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── سه‌گانهٔ بزرگ (مثل طرح مرجع: خورشید/ماه/طالع) ─────────
            const SectionHeader('سه‌گانهٔ بزرگ',
                icon: Icons.auto_awesome, iconColor: AppTheme.gold),
            GlassCard(
              highlight: true,
              accent: AppTheme.gold,
              child: Column(
                children: [
                  _BigThreeRow(
                    symbol: sunSign?.symbol ?? '',
                    label: 'خورشید در ${sunSign?.nameFa ?? ''}',
                    degree: sun.longitudeDegrees,
                    role: 'جوهرهٔ وجودِ تو',
                    color: AppTheme.gold,
                  ),
                  const SizedBox(height: 12),
                  _BigThreeRow(
                    symbol: moonSign?.symbol ?? '',
                    label: 'ماه در ${moonSign?.nameFa ?? ''}',
                    degree: moon.longitudeDegrees,
                    role: 'دنیای احساسِ تو',
                    color: AppTheme.sky,
                  ),
                  if (chart.ascendant != null) ...[
                    const SizedBox(height: 12),
                    _BigThreeRow(
                      symbol:
                          ref.watch(zodiacSignByIdProvider(chart.ascendant!.signId))?.symbol ?? '',
                      label:
                          'طالعِ دقیق در ${ref.watch(zodiacSignByIdProvider(chart.ascendant!.signId))?.nameFa ?? ''}',
                      degree: chart.ascendant!.longitudeDegrees,
                      role: 'نقابِ روبه‌بیرونِ تو',
                      color: AppTheme.rose,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── موقعیت سیاره‌ها — گریدِ فشرده مثل طرح مرجع ──────────
            const SectionHeader('موقعیتِ سیاره‌ها',
                icon: Icons.grid_view_rounded, iconColor: AppTheme.violet),
            GlassCard(
              accent: AppTheme.violet,
              child: Column(
                children: [
                  for (var r = 0;
                      r < (chart.planetPositions.length - 2 + 1) ~/ 2;
                      r++)
                    Padding(
                      padding: EdgeInsets.only(bottom: r == 0 ? 0 : 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _PlanetGridCell(
                                position: chart.planetPositions[2 + r * 2]),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: 2 + r * 2 + 1 < chart.planetPositions.length
                                ? _PlanetGridCell(
                                    position:
                                        chart.planetPositions[2 + r * 2 + 1])
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'خورشید و ماه بالاتر در «سه‌گانهٔ بزرگ» آمده‌اند؛ این جدول با موتورِ واقعیِ آسمان برای لحظهٔ تولدِ تو محاسبه شده است.',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.9,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const SectionHeader('تعبیرِ کاملِ سیاره‌ها',
                icon: Icons.blur_circular, iconColor: AppTheme.violet),
            GlassCard(
              accent: AppTheme.violet,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < chart.planetPositions.length; i++) ...[
                    if (i > 0) ...[
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.06),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _PositionBlock(position: chart.planetPositions[i]),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    NatalContent.retrogradeNote,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.9,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (chart.ascendant != null) ...[
              const SectionHeader('طالعِ دقیق و خانه‌ها',
                  icon: Icons.explore, iconColor: AppTheme.rose),
              GlassCard(
                highlight: true,
                accent: AppTheme.rose,
                child: Column(
                  children: [
                    Text(
                      'طالعِ دقیق: ${ref.watch(zodiacSignByIdProvider(chart.ascendant!.signId))?.nameFa ?? ''} '
                      '(${_faDeg(chart.ascendant!.degreeInSign)}°)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                    const SizedBox(height: 10),
                    BodyText(
                      NatalContent.ascendantInSign[chart.ascendant!.signId] ??
                          '',
                    ),
                    const SizedBox(height: 14),
                    for (var k = 0; k < 12; k++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 26,
                              child: Text(
                                'خانهٔ ${PersianNumbers.toPersianNum(k + 1)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.rose,
                                  fontFamily: 'Vazirmatn',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${NatalContent.houseTitles[k]} · برجِ ${ref.watch(zodiacSignByIdProvider(chart.houses[k].signId))?.nameFa ?? ''}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.8,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.75),
                                  fontFamily: 'Vazirmatn',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (chart.aspects.isNotEmpty) ...[
              const SectionHeader('زاویه‌های مهمِ نقشه',
                  icon: Icons.auto_awesome, iconColor: AppTheme.sky),
              for (final a in chart.aspects.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    accent: _aspectColors[a.kind] ?? AppTheme.violet,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.link_rounded,
                                size: 14,
                                color: _aspectColors[a.kind] ??
                                    AppTheme.violet),
                            const SizedBox(width: 6),
                            Text(
                              '${NatalEngine.bodyNamesFa[a.bodyA]} و '
                              '${NatalEngine.bodyNamesFa[a.bodyB]} · '
                              '${_aspectTitlesFa[a.kind] ?? ''} '
                              '(${_faDeg(a.orbDegrees)}°)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                                fontFamily: 'Vazirmatn',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        BodyText(
                          (NatalContent.aspectTexts[a.kind] ?? '')
                              .replaceAll('{a}',
                                  NatalEngine.bodyNamesFa[a.bodyA] ?? '')
                              .replaceAll('{b}',
                                  NatalEngine.bodyNamesFa[a.bodyB] ?? ''),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
            ],

            _DominantElementCard(chart: chart),
            const SizedBox(height: 16),

            // ── ترانزیت‌های امروز — آسمانِ حالا روی نقشهٔ تو ──────────
            const SectionHeader('ترانزیت‌های امروز',
                icon: Icons.today, iconColor: AppTheme.gold),
            GlassCard(
              highlight: true,
              accent: AppTheme.gold,
              child: _TransitsCard(chart: chart),
            ),
            const SizedBox(height: 14),
            GlassCard(
              child: Text(
                NatalContent.methodNote,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.95,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const DisclaimerCard(),
        ],
      ),
    );
  }

  static String _faDeg(double deg) =>
      PersianNumbers.toPersianNum(deg.round());
}

class _PositionBlock extends ConsumerWidget {
  const _PositionBlock({required this.position});

  final PlanetPosition position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sign = ref.watch(zodiacSignByIdProvider(position.signId));
    final text =
        NatalContent.planetInSign[position.body]?[position.signId] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              NatalEngine.bodyNamesFa[position.body] ?? position.body,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
                fontFamily: 'Vazirmatn',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${sign?.nameFa ?? ''} ${sign?.symbol ?? ''} · '
                '${PersianNumbers.toPersianNum((position.longitudeDegrees % 30).round())}°'
                '${position.isRetrograde ? ' · پس‌روی' : ''}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ),
          ],
        ),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              height: 2,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              fontFamily: 'Vazirmatn',
            ),
          ),
        ],
      ],
    );
  }
}

class _DominantElementCard extends StatelessWidget {
  const _DominantElementCard({required this.chart});

  final NatalChart chart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <String, int>{};
    for (final p in chart.planetPositions) {
      final idx = _signIndex(p.signId);
      if (idx < 0) continue;
      final element = const ['fire', 'earth', 'air', 'water'][idx % 4];
      counts[element] = (counts[element] ?? 0) + 1;
    }
    String? dominant;
    var max = 0;
    for (final e in counts.entries) {
      if (e.value > max) {
        max = e.value;
        dominant = e.key;
      }
    }
    if (dominant == null) return const SizedBox.shrink();

    const elementFa = {
      'fire': 'آتش',
      'earth': 'خاک',
      'air': 'هوا',
      'water': 'آب',
    };
    const elementColors = {
      'fire': Color(0xFFFF9E6E),
      'earth': Color(0xFF4CD97B),
      'air': AppTheme.sky,
      'water': AppTheme.violet,
    };

    return GlassCard(
      highlight: true,
      accent: elementColors[dominant],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.whatshot_outlined,
                  size: 16, color: elementColors[dominant]),
              const SizedBox(width: 8),
              Text(
                'عنصرِ غالب: ${elementFa[dominant]}',
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
          BodyText(NatalContent.dominantElement[dominant] ?? ''),
        ],
      ),
    );
  }

  static int _signIndex(String id) {
    const order = [
      'aries', 'taurus', 'gemini', 'cancer', 'leo', 'virgo',
      'libra', 'scorpio', 'sagittarius', 'capricorn', 'aquarius', 'pisces',
    ];
    return order.indexOf(id);
  }
}

class _BodyRow extends StatelessWidget {
  const _BodyRow({
    required this.symbol,
    required this.title,
    required this.text,
  });

  final String symbol;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZodiacSymbol(symbol, fontSize: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  fontFamily: 'Vazirmatn',
                ),
              ),
              const SizedBox(height: 5),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 2,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
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

/// One row of the "big three" summary (Sun / Moon / Rising), mirroring the
/// reference mockup's BIG THREE block.
class _BigThreeRow extends StatelessWidget {
  const _BigThreeRow({
    required this.symbol,
    required this.label,
    required this.degree,
    required this.role,
    required this.color,
  });

  final String symbol;
  final String label;
  final double degree;
  final String role;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Center(child: ZodiacSymbol(symbol, fontSize: 19)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  fontFamily: 'Vazirmatn',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                role,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: color.withValues(alpha: 0.10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Text(
            '${PersianNumbers.toPersianNum((degree % 30).round())}°',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'Vazirmatn',
            ),
          ),
        ),
      ],
    );
  }
}

/// A single cell of the compact planetary-positions grid.
class _PlanetGridCell extends ConsumerWidget {
  const _PlanetGridCell({required this.position});

  final PlanetPosition position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sign = ref.watch(zodiacSignByIdProvider(position.signId));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        // Borderless white glass — matches the card surface above it.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.11),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Row(
        children: [
          ZodiacSymbol(sign?.symbol ?? '', fontSize: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  NatalEngine.bodyNamesFa[position.body] ?? position.body,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${PersianNumbers.toPersianNum((position.longitudeDegrees % 30).round())}° '
                  '${sign?.nameFa ?? ''}'
                  '${position.isRetrograde ? ' · پس‌روی' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: position.isRetrograde
                        ? AppTheme.rose
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Transits of today" section — live sky vs. the birth chart.
class _TransitsCard extends ConsumerWidget {
  const _TransitsCard({required this.chart});

  final NatalChart chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transits =
        NatalTransits.compute(chart, DateTime.now().toUtc());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BodyText(NatalContent.transitsIntro),
        const SizedBox(height: 14),
        for (var i = 0; i < transits.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(height: 11),
            Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 11),
          ],
          _TransitRow(transit: transits[i]),
        ],
        const SizedBox(height: 14),
        Text(
          NatalContent.transitsMethodNote,
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

class _TransitRow extends ConsumerWidget {
  const _TransitRow({required this.transit});

  final TransitInfo transit;

  static const Map<String, String> _linkLabels = {
    'sun-sign': 'در برجِ خورشیدِ تو',
  };

  String get _linkText {
    if (transit.natalLink.startsWith('conjunct:')) {
      final body = transit.natalLink.substring(9);
      return 'هم‌مقر با ${NatalEngine.bodyNamesFa[body] ?? body}ِ تولدت';
    }
    if (transit.natalLink.startsWith('house:')) {
      final n = transit.natalLink.substring(6);
      return 'در خانهٔ ${PersianNumbers.toPersianNum(int.parse(n))}ِ تو';
    }
    return _linkLabels[transit.natalLink] ?? '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sign = ref.watch(zodiacSignByIdProvider(transit.signId));
    final link = _linkText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ZodiacSymbol(sign?.symbol ?? '', fontSize: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    '${NatalEngine.bodyNamesFa[transit.body] ?? transit.body} در '
                    '${sign?.nameFa ?? ''} '
                    '${PersianNumbers.toPersianNum(transit.degreeInSign.round())}°',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                  if (transit.isRetrograde)
                    Text(
                      'پس‌روی',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.rose,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${NatalContent.transitThemes[transit.body] ?? ''}'
                '${link.isNotEmpty ? ' · $link' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.7,
                  color: link.isNotEmpty
                      ? AppTheme.gold.withValues(alpha: 0.95)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.55),
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
