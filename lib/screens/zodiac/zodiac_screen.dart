import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../domain/zodiac/zodiac_art.dart';
import '../../domain/zodiac/zodiac_sign.dart';
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

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          // ── هدرِ برج — بنرِ تمام‌عرض با صورتِ فلکی ─────────────────
          _SignHeaderBanner(sign: sign),
          const SizedBox(height: 18),

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

/// بنرِ تمام‌عرضِ برج: اثرِ هنریِ سینماییِ اختصاصیِ همان برج (مثل
/// عقربِ فلزی روی سحابی) روی آسمانِ کیهانیِ ابری — نه دایره، کلِ
/// عرض. بالا: نشانِ عنصرِ شخصیتی؛ پایین: نامِ برج و پیل‌های
/// شیشه‌ایِ سیارهٔ حاکم و بازهٔ تاریخ.
class _SignHeaderBanner extends StatelessWidget {
  const _SignHeaderBanner({required this.sign});

  final ZodiacSign sign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // ارتفاعِ حداقلِ صحنه؛ اگر محتوا بلندتر باشد، بنر رشد می‌کند
        // (هرگز سرریز نمی‌کند).
        final minH = math.max(constraints.maxWidth * 10 / 19, 200.0);
        return ConstrainedBox(
        constraints: BoxConstraints(minHeight: minH),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
        children: [
          // اثرِ هنریِ سینماییِ برج — تمام‌عرض
          Positioned.fill(
            child: Image.asset(
              zodiacArtAsset(sign.id),
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          // اسکریمِ ملایم برای خواناییِ متن
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.30, 1],
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
          // محتوا — غیر-Positioned تا Stack را سایز دهد (بدونِ
          // فلکس؛ فاصله‌ها ثابت‌اند و سرریز ممکن نیست)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // «پشتِ سر» — نشانِ عنصرِ شخصیتی
                Align(
                  alignment: AlignmentDirectional.topStart,
                  child: _ElementPill(sign: sign),
                ),
                const SizedBox(height: 30),
                Text(
                  sign.nameFa,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'Vazirmatn',
                    shadows: const [
                      Shadow(color: Colors.black45, blurRadius: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sign.nameEn.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 3,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeaderPill(
                      icon: Icons.public,
                      label: 'سیارهٔ حاکم: ${sign.rulingPlanet}',
                    ),
                    _HeaderPill(
                      icon: Icons.cake_outlined,
                      label: PersianNumbers.toPersian(sign.dateRangeFa),
                    ),
                  ],
                ),
              ],
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

/// نشانِ عنصرِ شخصیتی — شیشهٔ سفید؛ با لمس، هنرِ کاملِ عنصر باز می‌شود.
class _ElementPill extends StatelessWidget {
  const _ElementPill({required this.sign});

  final ZodiacSign sign;

  IconData get _icon => switch (sign.elementId) {
        'fire' => Icons.local_fire_department_outlined,
        'earth' => Icons.terrain,
        'air' => Icons.toys,
        _ => Icons.waves,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: () => _showElementArt(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: 14, color: Colors.white.withValues(alpha: 0.95)),
              const SizedBox(width: 6),
              Text(
                'عنصرِ تو: ${sign.element}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.95),
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showElementArt(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Image.asset(
                elementAsset(sign.elementId),
                fit: BoxFit.cover,
                width: double.infinity,
                height: 320,
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.45, 1],
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.60),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 18,
                left: 18,
                bottom: 16,
                child: Text(
                  'عنصرِ شخصیتیِ تو: ${sign.element}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// پیلِ شیشه‌ایِ کوچکِ هدر (بدونِ قاب).
class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.95),
              fontFamily: 'Vazirmatn',
            ),
          ),
        ],
      ),
    );
  }
}
