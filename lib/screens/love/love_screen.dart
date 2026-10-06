import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../domain/compatibility/compatibility_engine.dart';
import '../../domain/profile/profile.dart';
import '../../providers/app_providers.dart';
import '../../providers/horoscope_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import 'compatibility_detail_screen.dart';
import 'couple_screen.dart';
import 'partner_form_screen.dart';

/// عشق — سازگاری با ۱۲ برج + شریک عاطفی (product spec §18).
class LoveScreen extends ConsumerStatefulWidget {
  const LoveScreen({super.key});

  @override
  ConsumerState<LoveScreen> createState() => _LoveScreenState();
}

class _LoveScreenState extends ConsumerState<LoveScreen> {
  @override
  void initState() {
    super.initState();
    // Keep partner store bound to the active profile.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(primaryProfileProvider).profile;
      if (profile != null) {
        ref.read(partnerProvider.notifier).loadFor(profile.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(primaryProfileProvider);
    final profile = profileState.profile;
    if (!profileState.ready) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    if (profile == null) {
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [ErrorState(message: 'پروفایلی یافت نشد.')],
        ),
      );
    }

    final rankedAsync = ref.watch(rankedCompatibilityProvider);
    final partnerState = ref.watch(partnerProvider);
    final analytics = ref.watch(analyticsProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Text(
            'با چه برج‌هایی هماهنگ هستی؟',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Vazirmatn',
            ),
          ),
          const SizedBox(height: 16),

          // ── Partner section ─────────────────────────────────────
          _PartnerCard(profile: profile),
          const SizedBox(height: 20),

          // ── Compatibility list ──────────────────────────────────
          rankedAsync.when(
            data: (ranked) {
              analytics.logEvent(AnalyticsEvent.compatibilityOpened.id);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('بهترین تطابق‌ها', subtitle: 'سه برج نخست'),
                  ..._rankTiles(context, ranked.best),
                  const SizedBox(height: 18),
                  const SectionHeader('همهٔ برج‌ها', subtitle: 'به ترتیب هماهنگی'),
                  ..._rankTiles(context, ranked.ranked),
                  const SizedBox(height: 18),
                  const SectionHeader('چالش‌برانگیزترین‌ها'),
                  ..._rankTiles(
                    context,
                    ranked.challenging.reversed.toList(),
                  ),
                ],
              );
            },
            loading: () =>
                const LoadingState(height: 200, message: 'در حال محاسبهٔ سازگاری…'),
            error: (e, _) => ErrorState(
              message: 'در محاسبهٔ سازگاری مشکلی پیش آمد.',
              onRetry: () => ref.invalidate(rankedCompatibilityProvider),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _rankTiles(BuildContext context, List<CompatibilityResult> items) {
    return [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CompatibilityTile(
            result: item,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CompatibilityDetailScreen(result: item),
              ),
            ),
          ),
        ),
    ];
  }
}

class _CompatibilityTile extends StatelessWidget {
  const _CompatibilityTile({required this.result, required this.onTap});

  final CompatibilityResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = result.level;
    final levelColor = _levelColor(level);

    return GlassCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Center(
                  child: ZodiacSymbol(result.signB.symbol, fontSize: 24),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.signB.nameFa,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      level == CompatibilityLevel.challenging ||
                              level == CompatibilityLevel.hard
                          ? Icons.bolt_outlined
                          : Icons.favorite,
                      size: 12,
                      color: levelColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      CompatibilityEngine.levelLabelFa(level),
                      style: TextStyle(
                        fontSize: 11,
                        color: levelColor,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            PersianNumbers.percent(result.scores.overall),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: levelColor,
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

class _PartnerCard extends ConsumerWidget {
  const _PartnerCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnerState = ref.watch(partnerProvider);
    final partner = partnerState.partner;

    if (!partnerState.ready) {
      return const LoadingState(height: 120);
    }

    if (partner == null) {
      return EmptyState(
        emoji: '🌙',
        title: 'هنوز کسی را برای مقایسه اضافه نکرده‌ای',
        message:
            'تاریخ تولد شریک عاطفی‌ات را اضافه کن تا سازگاری عاطفی شما محاسبه شود.',
        actionLabel: 'افزودن شریک',
        onAction: () => _openPartnerForm(context),
      );
    }

    final coupleAsync = ref.watch(coupleCompatibilityProvider);

    return coupleAsync.when(
      data: (couple) => GlassCard(
        highlight: true,
        accent: AppTheme.rose,
        onTap: () => _openCouple(context),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'من و ${partner.name}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const Spacer(),
                const Icon(Icons.arrow_back_ios_new, size: 14),
              ],
            ),
            const SizedBox(height: 14),
            if (couple != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      ZodiacSymbol(couple.signA.symbol, fontSize: 34),
                      const SizedBox(height: 2),
                      Text(
                        couple.signA.nameFa,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Icon(
                      Icons.favorite,
                      color: AppTheme.rose.withValues(alpha: 0.85),
                      size: 22,
                    ),
                  ),
                  Column(
                    children: [
                      ZodiacSymbol(couple.signB.symbol, fontSize: 34),
                      const SizedBox(height: 2),
                      Text(
                        couple.signB.nameFa,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            if (couple != null) ...[
              const SizedBox(height: 12),
              Text(
                PersianNumbers.percent(couple.scores.overall),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _levelColor(couple.level),
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ],
          ],
        ),
      ),
      loading: () => const LoadingState(height: 140),
      error: (e, _) => const ErrorState(message: 'در محاسبهٔ سازگاری زوج مشکل پیش آمد.'),
    );
  }

  void _openPartnerForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PartnerFormScreen()),
    );
  }

  void _openCouple(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CoupleScreen()),
    );
  }
}
