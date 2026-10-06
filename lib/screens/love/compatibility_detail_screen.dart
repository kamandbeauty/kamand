import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../domain/compatibility/compatibility_engine.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../premium/premium_screen.dart';

/// جزئیات رابطه با یک برج (product spec §18).
class CompatibilityDetailScreen extends ConsumerWidget {
  const CompatibilityDetailScreen({super.key, required this.result});

  final CompatibilityResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entitlement = ref.watch(entitlementProvider);
    final s = result.scores;

    return Scaffold(
      appBar: AppBar(title: Text('سازگاری با ${result.signB.nameFa}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ── Hero: two symbols ───────────────────────────────────
          GlassCard(
            highlight: true,
            accent: _levelColor(result.level),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SignBadge(symbol: result.signA.symbol, name: result.signA.nameFa),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(
                        Icons.favorite,
                        size: 26,
                        color: AppTheme.rose.withValues(alpha: 0.85),
                      ),
                    ),
                    _SignBadge(symbol: result.signB.symbol, name: result.signB.nameFa),
                  ],
                ),
                const SizedBox(height: 16),
                ScoreRing(score: s.overall, size: 110, label: 'هماهنگی'),
                const SizedBox(height: 10),
                Text(
                  CompatibilityEngine.levelLabelFa(result.level),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _levelColor(result.level),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 6),
                InfoChip(label: 'زاویهٔ ${result.aspectTitle}'),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Five dimensions ─────────────────────────────────────
          _ScoreBar(label: 'عشق', value: s.love, color: AppTheme.rose, icon: Icons.favorite),
          const SizedBox(height: 10),
          _ScoreBar(label: 'کشش', value: s.attraction, color: const Color(0xFFFF9E6E), icon: Icons.local_fire_department_outlined),
          const SizedBox(height: 10),
          _ScoreBar(label: 'ارتباط', value: s.communication, color: AppTheme.sky, icon: Icons.chat_bubble_outline),
          const SizedBox(height: 10),
          _ScoreBar(label: 'اعتماد', value: s.trust, color: const Color(0xFF4CD97B), icon: Icons.handshake_outlined),
          const SizedBox(height: 10),
          _ScoreBar(label: 'پایداری', value: s.longTerm, color: AppTheme.gold, icon: Icons.all_inclusive),
          const SizedBox(height: 20),

          // ── Why ─────────────────────────────────────────────────
          const SectionHeader('چرا این دو برج با هم سازگارند؟'),
          GlassCard(
            accent: AppTheme.violet,
            child: Text(
              result.whyText,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.science_outlined, size: 16, color: AppTheme.gold),
                    const SizedBox(width: 8),
                    Text(
                      'شیمی عناصر',
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
                Text(
                  result.elementChemistryText,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 2,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Premium deep analysis ───────────────────────────────
          if (entitlement.hasPremium)
            GlassCard(
              highlight: true,
              accent: AppTheme.rose,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 16, color: AppTheme.rose),
                      const SizedBox(width: 8),
                      Text(
                        'تحلیل کامل رابطه',
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
                    '${result.signA.nameFa} با حسِ ${result.signA.element} و ${result.signB.nameFa} با سیارهٔ حاکمِ ${result.signB.rulingPlanet}، '
                    'در این رابطه هرکدام نقشی دارند: ${result.signA.nameFa} ${result.signA.loveStyle.split('،').first} '
                    'و ${result.signB.nameFa} ${result.signB.loveStyle.split('،').first}. '
                    'نقطهٔ تلاقی شما، ${_focusAdvice(result)} است. با گفتگوی منظم و احترام به تفاوت‌ها، این رابطه می‌تواند تعادلِ خوبی پیدا کند.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 2.1,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                ],
              ),
            )
          else
            LockedSection(
              title: 'تحلیل کامل رابطه',
              hint: 'تحلیل عمیق این زوج — ویژهٔ پرمیوم',
              onOpenPremium: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              ),
            ),
        ],
      ),
    );
  }

  String _focusAdvice(CompatibilityResult r) {
    final weakest = [
      (r.scores.communication, 'گفت‌وگو'),
      (r.scores.trust, 'اعتماد'),
      (r.scores.longTerm, 'پایداری'),
      (r.scores.attraction, 'کشش متقابل'),
      (r.scores.love, 'ابراز محبت'),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return 'تقویتِ ${weakest.first.$2}';
  }
}

class _SignBadge extends StatelessWidget {
  const _SignBadge({required this.symbol, required this.name});

  final String symbol;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.violet.withValues(alpha: 0.10),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
          ),
          child: Center(child: ZodiacSymbol(symbol, fontSize: 32)),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(fontSize: 11, fontFamily: 'Vazirmatn'),
        ),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                fontFamily: 'Vazirmatn',
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value / 100),
              duration: const Duration(milliseconds: 750),
              builder: (context, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  color: color,
                  backgroundColor:
                      theme.colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            PersianNumbers.percent(value),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'Vazirmatn',
            ),
          ),
        ],
      ),
    );
  }
}

Color _levelColor(CompatibilityLevel level) {
  switch (level) {
    case CompatibilityLevel.excellent:
      return const Color(0xFF4CD97B);
    case CompatibilityLevel.good:
      return AppTheme.sky;
    case CompatibilityLevel.fair:
      return AppTheme.gold;
    case CompatibilityLevel.challenging:
      return AppTheme.rose;
    case CompatibilityLevel.hard:
      return const Color(0xFFFF5C7A);
  }
}
