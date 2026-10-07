import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../domain/traditions/manazil.dart';
import '../../providers/tradition_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/mystic_badge.dart';
import 'chinese_tradition_screen.dart';
import 'iranian_tradition_screen.dart';
import 'mayan_tradition_screen.dart';
import 'numerology_tradition_screen.dart';
import 'tradition_widgets.dart';
import 'vedic_tradition_screen.dart';
import '../fortunes/abjad_fal_screen.dart';
import '../fortunes/animal_fortune_screen.dart';
import '../fortunes/gem_oracle_screen.dart';
import '../fortunes/greek_fortune_screen.dart';
import '../fortunes/marriage_fortune_screen.dart';
import '../fortunes/month_traits_screen.dart';
import '../fortunes/tarot_fortune_screen.dart';

/// «طالع‌بینی در سنت‌های جهان» — hub listing the five world traditions
/// and the seven fortune modules, each with its own mystic emblem.
///
/// Everything is computed offline from the birth date the user already
/// entered; no new data is collected.
class TraditionsHubScreen extends ConsumerWidget {
  const TraditionsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chinese = ref.watch(chineseSignProvider);
    final lifePath = ref.watch(lifePathProvider);
    final vedic = ref.watch(vedicChartProvider);
    final tzolkin = ref.watch(tzolkinProvider);
    final manzil = ref.watch(birthManzilProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('طالع‌بینی در سنت‌های جهان')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Hero strip: all twelve emblems ──────────────────────
          GlassCard(
            highlight: true,
            accent: AppTheme.violet,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              children: [
                Text(
                  'تولدت در پنج سنت کهنِ جهان چه می‌گوید؟',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'همه با همان تاریخ تولدت، همین‌جا و آفلاین محاسبه می‌شود.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.9,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final spec in MysticEmblems.all)
                      spec.badge(size: 38, showStar: false),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Section 1: the five world traditions ────────────────
          const SectionHeader(
            'پنج سنت کهنِ جهان',
            subtitle: 'چینی · فراشماره · ایرانی · ودیک · مایا',
            icon: Icons.public,
            iconColor: AppTheme.sky,
          ),
          _ModuleCard(
            spec: MysticEmblems.chinese,
            title: 'طالع‌بینی چینی',
            subtitle: chinese == null
                ? 'حیوان، عنصر و یین/یانگ سال تولد'
                : 'سال ${chinese.animal['nameFa']! as String}'
                      ' · ${chinese.element['nameFa']! as String}'
                      ' · ${chinese.yang ? 'یانگ' : 'یین'}',
            onTap: () => _push(context, const ChineseTraditionScreen()),
          ),
          const SizedBox(height: 12),
          _ModuleCard(
            spec: MysticEmblems.numerology,
            title: 'فراشماره و ابجد',
            subtitle: lifePath == null
                ? 'عدد مسیر زندگی از تاریخ تولد + ابجدِ نام'
                : 'عدد مسیر زندگی: ${PersianNumbers.toPersianNum(lifePath)}',
            onTap: () => _push(context, const NumerologyTraditionScreen()),
          ),
          const SizedBox(height: 12),
          _ModuleCard(
            spec: MysticEmblems.iranian,
            title: 'سنت ایرانی-اسلامی',
            subtitle: manzil == null
                ? 'منازل ۲۸گانهٔ ماه و میراث احکام نجوم'
                : 'منزل ماهِ تولد: منزلِ ${_manzilName(manzil)}',
            onTap: () => _push(context, const IranianTraditionScreen()),
          ),
          const SizedBox(height: 12),
          _ModuleCard(
            spec: MysticEmblems.vedic,
            title: 'طالع‌بینی ودیک (هند)',
            subtitle: vedic == null
                ? 'برج قمری و تولدستاره بر پایهٔ جیوتیشا'
                : 'برج قمری: ${vedic.rashi['nameFa']! as String}'
                      ' · تولدستاره: ${vedic.nakshatra['name']! as String}',
            onTap: () => _push(context, const VedicTraditionScreen()),
          ),
          const SizedBox(height: 12),
          _ModuleCard(
            spec: MysticEmblems.maya,
            title: 'تقویم مقدس مایا',
            subtitle: tzolkin == null
                ? 'تزولکین ۲۶۰روزه و امضای کیهانی تو'
                : 'امضای کیهانی: ${PersianNumbers.toPersianNum(tzolkin.tone)}'
                      ' ${tzolkin.nawal['nameFa']! as String}',
            onTap: () => _push(context, const MayanTraditionScreen()),
          ),
          const SizedBox(height: 24),

          // ── Section 2: fortunes ─────────────────────────────────
          const SectionHeader(
            'فال و طالع‌های بیشتر',
            subtitle: 'هفت درِ تازه به دنیای فال',
            icon: Icons.auto_fix_high,
            iconColor: AppTheme.gold,
          ),
          _ModuleCard(
            spec: MysticEmblems.gem,
            title: 'فال جم‌اوراکل',
            subtitle: 'سنگِ ماهِ تولدت و فالِ سه‌سنگیِ امروز',
            onTap: () => _push(context, const GemOracleScreen()),
          ),
          const SizedBox(height: 12),
          _ModuleCard(
            spec: MysticEmblems.abjad,
            title: 'فال ابجد',
            subtitle: 'ابجدِ نام و نامِ مادرت، با نیتِ دل',
            onTap: () => _push(context, const AbjadFalScreen()),
          ),
          const SizedBox(height: 12),
          _ModuleCard(
            spec: MysticEmblems.greek,
            title: 'طالع‌بینی یونانی',
            subtitle: 'عنصر، کیفیت، مزاج و اسطورهٔ برجِ تو',
            onTap: () => _push(context, const GreekFortuneScreen()),
          ),
          const SizedBox(height: 12),
          _ModuleCard(
            spec: MysticEmblems.marriage,
            title: 'طالع ازدواج',
            subtitle: 'سبکِ برجِ تو در پیمانِ زندگی',
            onTap: () => _push(context, const MarriageFortuneScreen()),
          ),
          const SizedBox(height: 12),
          _ModuleCard(
            spec: MysticEmblems.months,
            title: 'متولدین ماه‌های سال',
            subtitle: 'روایتِ ماهِ تولدت در تقویم خورشیدی',
            onTap: () => _push(context, const MonthTraitsScreen()),
          ),
          const SizedBox(height: 12),
          _ModuleCard(
            spec: MysticEmblems.tarot,
            title: 'طالع بینی تاروت',
            subtitle: 'کارتِ تولد و کارتِ امروزِ تو',
            onTap: () => _push(context, const TarotFortuneScreen()),
          ),
          const SizedBox(height: 12),
          _ModuleCard(
            spec: MysticEmblems.animal,
            title: 'حیوان درون',
            subtitle: 'روحِ حیوانیِ برجِ تو و پیامش',
            onTap: () => _push(context, const AnimalFortuneScreen()),
          ),
          const DisclaimerCard(),
        ],
      ),
    );
  }

  static String _manzilName(int index) =>
      ManazilCalculator.at(index)['name']! as String;

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

/// A hub card: mystic emblem + title + live subtitle + chevron.
class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.spec,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final MysticSpec spec;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      accent: spec.a,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          spec.badge(size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.7,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_left,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
        ],
      ),
    );
  }
}
