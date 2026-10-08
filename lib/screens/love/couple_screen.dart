import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/content/app_content.dart';
import '../../data/analytics/analytics_service.dart';
import '../../core/utils/persian_numbers.dart';
import '../../domain/compatibility/compatibility_engine.dart';
import '../../providers/app_providers.dart';
import '../../providers/horoscope_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/score_legend.dart';
import '../premium/premium_screen.dart';

/// من و [نام] — couple compatibility (product spec §20).
class CoupleScreen extends ConsumerWidget {
  const CoupleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnerState = ref.watch(partnerProvider);
    final coupleAsync = ref.watch(coupleCompatibilityProvider);
    final partner = partnerState.partner;
    final analytics = ref.watch(analyticsProvider);

    if (partner == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('سازگاری زوج')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            EmptyState(
              emoji: '🌙',
              title: 'هنوز شریکی اضافه نکرده‌ای',
              message: 'از تب عشق، اطلاعات شریک عاطفی‌ات را اضافه کن.',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('من و ${partner.name}')),
      body: coupleAsync.when(
        data: (couple) {
          if (couple == null) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: const [ErrorState(message: 'پروفایل اصلی یافت نشد.')],
            );
          }
          analytics.logEvent(AnalyticsEvent.coupleOpened.id);
          return _CoupleBody(couple: couple);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ErrorState(
              message: 'در محاسبهٔ سازگاری مشکلی پیش آمد.',
              onRetry: () => ref.invalidate(coupleCompatibilityProvider),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoupleBody extends ConsumerWidget {
  const _CoupleBody({required this.couple});

  final CompatibilityResult couple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = couple.scores;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        GlassCard(
          highlight: true,
          accent: AppTheme.rose,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BigSign(symbol: couple.signA.symbol, name: couple.signA.nameFa),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Icon(
                      Icons.favorite,
                      size: 30,
                      color: AppTheme.rose.withValues(alpha: 0.9),
                    ),
                  ),
                  _BigSign(symbol: couple.signB.symbol, name: couple.signB.nameFa),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'امتیاز کلی سازگاری',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontFamily: 'Vazirmatn',
                ),
              ),
              const SizedBox(height: 10),
              ScoreRing(score: s.overall, size: 120),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _DimTile(icon: Icons.favorite, label: 'عشق', value: s.love, color: AppTheme.rose),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DimTile(icon: Icons.chat_bubble_outline, label: 'ارتباط', value: s.communication, color: AppTheme.sky),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DimTile(icon: Icons.handshake_outlined, label: 'اعتماد', value: s.trust, color: const Color(0xFF4CD97B)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DimTile(icon: Icons.local_fire_department_outlined, label: 'کشش', value: s.attraction, color: const Color(0xFFFF9E6E)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DimTile(icon: Icons.all_inclusive, label: 'پایداری', value: s.longTerm, color: AppTheme.gold),
            ),
            const SizedBox(width: 10),
            const Expanded(child: SizedBox()),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader('تحلیل رابطه'),
        GlassCard(
          accent: AppTheme.violet,
          child: Text(
            couple.whyText,
            style: TextStyle(
              fontSize: 13,
              height: 2.1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
              fontFamily: 'Vazirmatn',
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          accent: AppTheme.gold,
          child: Text(
            couple.elementChemistryText,
            style: TextStyle(
              fontSize: 12.5,
              height: 2,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              fontFamily: 'Vazirmatn',
            ),
          ),
        ),
        const SizedBox(height: 16),
        _AspectDeepDive(aspectId: couple.aspectId),
        const SizedBox(height: 12),
        _CoupleScoreLegend(),
      ],
    );
  }
}

/// Premium deep-dive: the classical synastry reading of this pair's
/// aspect — dynamics, strengths, challenges and the authored advice.
class _AspectDeepDive extends ConsumerWidget {
  const _AspectDeepDive({required this.aspectId});

  final String aspectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(entitlementProvider);
    if (!entitlement.hasPremium) {
      return LockedSection(
        title: 'تحلیل کامل رابطه',
        hint: 'ریشهٔ این هم‌خوانی: نقاط قوت، چالش‌ها و نسخهٔ اختصاصیِ این زوج — ویژهٔ پرمیوم',
        onOpenPremium: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PremiumScreen()),
        ),
      );
    }

    final theme = Theme.of(context);
    final data = AppContent.compatibility['aspectTexts']! as Map<String, Object?>;
    final a = data[aspectId]! as Map<String, Object?>;
    final strengths = (a['strengths']! as List<Object?>).whereType<String>().toList();
    final challenges = (a['challenges']! as List<Object?>).whereType<String>().toList();

    return GlassCard(
      highlight: true,
      accent: AppTheme.rose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: AppTheme.rose),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ریشهٔ این هم‌خوانی: ${a['title']! as String}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            a['dynamics']! as String,
            style: TextStyle(
              fontSize: 12.5,
              height: 2.05,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              fontFamily: 'Vazirmatn',
            ),
          ),
          const SizedBox(height: 12),
          _BulletList(
            title: 'نقاط قوت این بُعد',
            items: strengths,
            color: const Color(0xFF4CD97B),
            marker: '•',
          ),
          const SizedBox(height: 8),
          _BulletList(
            title: 'چالش‌های این بُعد',
            items: challenges,
            color: AppTheme.rose,
            marker: '!',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '• توصیهٔ ویژهٔ این رابطه: ${a['advice']! as String}',
              style: TextStyle(
                fontSize: 12,
                height: 2,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                fontFamily: 'Vazirmatn',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({
    required this.title,
    required this.items,
    required this.color,
    required this.marker,
  });

  final String title;
  final List<String> items;
  final Color color;
  final String marker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
            fontFamily: 'Vazirmatn',
          ),
        ),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.14),
                  ),
                  child: Text(
                    marker,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.9,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// «این درصدها یعنی چه؟» for the couple screen — dimensions with the
/// real engine weights, bands and the transparent method note.
class _CoupleScoreLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final compat = AppContent.compatibility;
    final guide = compat['dimensionGuide']! as Map<String, Object?>;
    final bandsData =
        (compat['scoreBands']! as List<Object?>).whereType<Map>().toList();

    const labels = {
      'love': 'عشق',
      'communication': 'ارتباط',
      'attraction': 'کشش',
      'trust': 'اعتماد',
      'longTerm': 'پایداری',
    };
    const weights = {
      'love': 28,
      'communication': 20,
      'attraction': 20,
      'trust': 16,
      'longTerm': 16,
    };

    return ScoreLegend(
      intro:
          'پنج بعدِ سنجشِ هم‌نوایی شما دو نفر — با وزنِ واقعیِ هر یک در امتیازِ نهایی.',
      accent: AppTheme.rose,
      dimensions: [
        for (final key in labels.keys)
          LegendDimension(
            labels[key]!,
            guide[key]! as String,
            weight: weights[key],
          ),
      ],
      bands: [
        for (final b in bandsData)
          LegendBand(
            b['min']! as int,
            b['label']! as String,
            b['meaning']! as String,
          ),
      ],
      methodNote: compat['methodNote']! as String,
    );
  }
}

class _BigSign extends StatelessWidget {
  const _BigSign({required this.symbol, required this.name});

  final String symbol;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                AppTheme.violet.withValues(alpha: 0.25),
                AppTheme.rose.withValues(alpha: 0.16),
              ],
            ),
          ),
          child: Center(child: ZodiacSymbol(symbol, fontSize: 40)),
        ),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(fontSize: 12, fontFamily: 'Vazirmatn')),
      ],
    );
  }
}

class _DimTile extends StatelessWidget {
  const _DimTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            PersianNumbers.percent(value),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'Vazirmatn',
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              fontFamily: 'Vazirmatn',
            ),
          ),
        ],
      ),
    );
  }
}
