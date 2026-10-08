import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../providers/app_providers.dart';
import '../../providers/horoscope_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import 'natal_chart_screen.dart';

/// Asset path for a sign's element artwork.
String elementAsset(String elementId) {
  switch (elementId) {
    case 'fire':
      return 'assets/images/element_fire.jpg';
    case 'earth':
      return 'assets/images/element_earth.jpg';
    case 'air':
      return 'assets/images/element_air.jpg';
    case 'water':
    default:
      return 'assets/images/element_water.jpg';
  }
}

/// برج من — deep dive into the user's sign (product spec §16).
class ZodiacScreen extends ConsumerWidget {
  const ZodiacScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(primaryProfileProvider);

    if (!profileState.ready) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final profile = profileState.profile;
    if (profile == null) {
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            ErrorState(message: 'پروفایلی یافت نشد. از ابتدا وارد شو.'),
          ],
        ),
      );
    }

    final sign = ref.watch(zodiacSignByIdProvider(profile.zodiacId));
    if (sign == null) {
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [ErrorState(message: 'اطلاعات برج یافت نشد.')],
        ),
      );
    }

    final theme = Theme.of(context);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          // ── Hero ────────────────────────────────────────────────
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: reduceMotion ? 1 : 0.7, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutBack,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage(elementAsset(sign.elementId)),
                    fit: BoxFit.cover,
                    opacity: 0.85,
                  ),
                ),
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.surface.withValues(alpha: 0.0),
                        theme.colorScheme.surface.withValues(alpha: 0.55),
                      ],
                      radius: 0.9,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 132,
                      height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      AppTheme.violet.withValues(alpha: 0.28),
                      AppTheme.gold.withValues(alpha: 0.20),
                    ],
                  ),
                  border:
                      Border.all(color: AppTheme.gold.withValues(alpha: 0.45)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.violet.withValues(alpha: 0.25),
                      blurRadius: 42,
                    ),
                  ],
                ),
                      child: Center(
                        child: ZodiacSymbol(sign.symbol, fontSize: 72),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              sign.nameFa,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
                fontFamily: 'Vazirmatn',
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              sign.nameEn,
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                InfoChip(
                  label: 'عنصر: ${sign.element}',
                  icon: Icons.local_fire_department_outlined,
                ),
                InfoChip(
                  label: 'سیارهٔ حاکم: ${sign.rulingPlanet}',
                  icon: Icons.public,
                ),
                InfoChip(
                  label: PersianNumbers.toPersian(sign.dateRangeFa),
                  icon: Icons.cake_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          _Section(
            title: 'ویژگی کلی',
            child: GlassCard(
              accent: AppTheme.violet,
              child: Text(
                sign.description,
                style: _bodyStyle(theme),
              ),
            ),
          ),
          _Section(
            title: 'تو چه جور آدمی هستی؟',
            child: GlassCard(
              child: Text(sign.personality, style: _bodyStyle(theme)),
            ),
          ),
          _Section(
            title: 'نقاط قوت',
            child: GlassCard(
              accent: const Color(0xFF4CD97B),
              child: Column(
                children: [
                  for (var i = 0; i < sign.strengths.length; i++)
                    _BulletRow(
                      color: const Color(0xFF4CD97B),
                      text: sign.strengths[i],
                      isLast: i == sign.strengths.length - 1,
                    ),
                ],
              ),
            ),
          ),
          _Section(
            title: 'نقاط ضعف',
            child: GlassCard(
              accent: AppTheme.rose,
              child: Column(
                children: [
                  for (var i = 0; i < sign.weaknesses.length; i++)
                    _BulletRow(
                      color: AppTheme.rose,
                      text: sign.weaknesses[i],
                      isLast: i == sign.weaknesses.length - 1,
                    ),
                ],
              ),
            ),
          ),
          _Section(
            title: 'در عشق',
            child: GlassCard(
              accent: AppTheme.rose,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.favorite, size: 18, color: AppTheme.rose),
                  const SizedBox(width: 10),
                  Expanded(child: Text(sign.loveStyle, style: _bodyStyle(theme))),
                ],
              ),
            ),
          ),
          _Section(
            title: 'در کار',
            child: GlassCard(
              accent: AppTheme.sky,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.work_outline, size: 18, color: AppTheme.sky),
                  const SizedBox(width: 10),
                  Expanded(child: Text(sign.workStyle, style: _bodyStyle(theme))),
                ],
              ),
            ),
          ),
          _Section(
            title: 'در دوستی',
            child: GlassCard(
              accent: AppTheme.gold,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.group_outlined, size: 18, color: AppTheme.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(sign.friendshipStyle, style: _bodyStyle(theme)),
                  ),
                ],
              ),
            ),
          ),
          _Section(
            title: 'چارت تولد',
            child: GlassCard(
              highlight: true,
              accent: AppTheme.violet,
              padding: const EdgeInsets.all(14),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NatalChartScreen()),
              ),
              child: Row(
                children: [
                  ZodiacSymbol(sign.symbol,
                      fontSize: 34, color: AppTheme.violet),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نقشهٔ تولدِ تو',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'جایگاهِ واقعیِ سیاره‌ها، طالعِ دقیق و خانه‌ها',
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
          ),
          const SizedBox(height: 8),
          Text(
            'توصیف برج‌ها جنبهٔ سنتی و تفسیری دارد؛ نه قضاوت قطعی دربارهٔ هیچ‌کس.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontFamily: 'Vazirmatn',
            ),
          ),
        ],
      ),
    );
  }

  static TextStyle _bodyStyle(ThemeData theme) => TextStyle(
        fontSize: 13,
        height: 2.05,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
        fontFamily: 'Vazirmatn',
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title),
        child,
        const SizedBox(height: 18),
      ],
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({
    required this.color,
    required this.text,
    required this.isLast,
  });

  final Color color;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.9,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                fontFamily: 'Vazirmatn',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
