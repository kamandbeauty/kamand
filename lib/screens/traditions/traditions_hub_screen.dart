import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../domain/traditions/manazil.dart';
import '../../providers/tradition_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../fortunes/abjad_fal_screen.dart';
import '../fortunes/animal_fortune_screen.dart';
import '../fortunes/gem_oracle_screen.dart';
import '../fortunes/greek_fortune_screen.dart';
import '../fortunes/marriage_fortune_screen.dart';
import '../fortunes/month_traits_screen.dart';
import '../fortunes/tarot_fortune_screen.dart';
import 'chinese_tradition_screen.dart';
import 'iranian_tradition_screen.dart';
import 'mayan_tradition_screen.dart';
import 'numerology_tradition_screen.dart';
import 'tradition_widgets.dart';
import 'vedic_tradition_screen.dart';

/// «طالع‌بینی در سنت‌های جهان» — hub listing the five traditions.
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
          Text(
            'تولدت در پنج سنت کهنِ طالع‌بینی جهان چه می‌گوید؟ همهٔ این‌ها با همان تاریخ تولدی که وارد کرده‌ای، همین‌جا روی گوشی محاسبه می‌شود.',
            style: TextStyle(
              fontSize: 12.5,
              height: 2.0,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontFamily: 'Vazirmatn',
            ),
          ),
          const SizedBox(height: 16),
          _TraditionCard(
            accent: AppTheme.rose,
            icon: Icons.temple_buddhist,
            title: 'طالع‌بینی چینی',
            subtitle: chinese == null
                ? 'حیوان، عنصر و یین/یانگ سال تولد'
                : 'سال ${chinese.animal['nameFa']! as String}'
                      ' · ${chinese.element['nameFa']! as String}'
                      ' · ${chinese.yang ? 'یانگ' : 'یین'}',
            onTap: () => _push(context, const ChineseTraditionScreen()),
          ),
          const SizedBox(height: 12),
          _TraditionCard(
            accent: AppTheme.sky,
            icon: Icons.calculate_outlined,
            title: 'فراشماره و ابجد',
            subtitle: lifePath == null
                ? 'عدد مسیر زندگی از تاریخ تولد + ابجدِ نام'
                : 'عدد مسیر زندگی: ${PersianNumbers.toPersianNum(lifePath)}',
            onTap: () => _push(context, const NumerologyTraditionScreen()),
          ),
          const SizedBox(height: 12),
          _TraditionCard(
            accent: AppTheme.gold,
            icon: Icons.nightlight_round,
            title: 'سنت ایرانی-اسلامی',
            subtitle: manzil == null
                ? 'منازل ۲۸گانهٔ ماه و میراث احکام نجوم'
                : 'منزل ماهِ تولد: منزلِ ${_manzilName(manzil)}',
            onTap: () => _push(context, const IranianTraditionScreen()),
          ),
          const SizedBox(height: 12),
          _TraditionCard(
            accent: AppTheme.violet,
            icon: Icons.self_improvement,
            title: 'طالع‌بینی ودیک (هند)',
            subtitle: vedic == null
                ? 'برج قمری و تولدستاره بر پایهٔ جیوتیشا'
                : 'برج قمری: ${vedic.rashi['nameFa']! as String}'
                      ' · تولدستاره: ${vedic.nakshatra['name']! as String}',
            onTap: () => _push(context, const VedicTraditionScreen()),
          ),
          const SizedBox(height: 12),
          _TraditionCard(
            accent: const Color(0xFF4CD97B),
            icon: Icons.account_balance,
            title: 'تقویم مقدس مایا',
            subtitle: tzolkin == null
                ? 'تزولکین ۲۶۰روزه و امضای کیهانی تو'
                : 'امضای کیهانی: ${PersianNumbers.toPersianNum(tzolkin.tone)}'
                      ' ${tzolkin.nawal['nameFa']! as String}',
            onTap: () => _push(context, const MayanTraditionScreen()),
          ),
          const SizedBox(height: 24),
          SectionHeader('فال و طالع‌های بیشتر',
              subtitle: 'هفت درِ تازه به دنیای فال'),

          // ── Fortune modules ───────────────────────────────────────
          _TraditionCard(
            accent: AppTheme.gold,
            icon: Icons.diamond_outlined,
            title: 'فال جم‌اوراکل',
            subtitle: 'سنگِ ماهِ تولدت و فالِ سه‌سنگیِ امروز',
            onTap: () => _push(context, const GemOracleScreen()),
          ),
          const SizedBox(height: 12),
          _TraditionCard(
            accent: AppTheme.violet,
            icon: Icons.auto_fix_high,
            title: 'فال ابجد',
            subtitle: 'ابجدِ نام و نامِ مادرت، با نیتِ دل',
            onTap: () => _push(context, const AbjadFalScreen()),
          ),
          const SizedBox(height: 12),
          _TraditionCard(
            accent: AppTheme.sky,
            icon: Icons.account_balance_outlined,
            title: 'طالع‌بینی یونانی',
            subtitle: 'عنصر، کیفیت، مزاج و اسطورهٔ برجِ تو',
            onTap: () => _push(context, const GreekFortuneScreen()),
          ),
          const SizedBox(height: 12),
          _TraditionCard(
            accent: AppTheme.rose,
            icon: Icons.favorite,
            title: 'طالع ازدواج',
            subtitle: 'سبکِ برجِ تو در پیمانِ زندگی',
            onTap: () => _push(context, const MarriageFortuneScreen()),
          ),
          const SizedBox(height: 12),
          _TraditionCard(
            accent: AppTheme.gold,
            icon: Icons.calendar_month,
            title: 'متولدین ماه‌های سال',
            subtitle: 'روایتِ ماهِ تولدت در تقویم خورشیدی',
            onTap: () => _push(context, const MonthTraitsScreen()),
          ),
          const SizedBox(height: 12),
          _TraditionCard(
            accent: AppTheme.violet,
            icon: Icons.style,
            title: 'طالع بینی تاروت',
            subtitle: 'کارتِ تولد و کارتِ امروزِ تو',
            onTap: () => _push(context, const TarotFortuneScreen()),
          ),
          const SizedBox(height: 12),
          _TraditionCard(
            accent: const Color(0xFF4CD97B),
            icon: Icons.pets,
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

class _TraditionCard extends StatelessWidget {
  const _TraditionCard({
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      accent: accent,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.14),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
            ),
            child: Icon(icon, size: 22, color: accent),
          ),
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
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_left,
              size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
        ],
      ),
    );
  }
}
