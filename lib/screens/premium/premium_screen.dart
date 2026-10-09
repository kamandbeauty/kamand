import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/analytics/analytics_service.dart';
import '../../core/utils/persian_numbers.dart';
import '../../data/premium/promo_codes.dart';
import '../../domain/entitlement/entitlement.dart';
import '../../providers/app_providers.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/premium_badge.dart';

/// Premium — honest pricing page, no dark patterns (product spec §45).
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  PremiumPlan _selected = PremiumPlan.yearly;
  final TextEditingController _promoController = TextEditingController();
  String? _promoError;
  bool _redeeming = false;

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _redeemPromo() async {
    if (_redeeming) return;
    setState(() => _redeeming = true);
    final granted = await ref
        .read(entitlementProvider.notifier)
        .redeemPromo(_promoController.text);
    if (!mounted) return;
    setState(() => _redeeming = false);
    if (granted) {
      setState(() => _promoError = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('پرمیوم همیشگی با کدِ کمپین فعال شد — لذت ببر! 🎉'),
        ),
      );
    } else {
      setState(() => _promoError = 'این کد معتبر نیست یا قبلاً استفاده شده است.');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsProvider).logEvent(AnalyticsEvent.premiumScreenOpened.id);
    });
  }

  Future<void> _activate() async {
    final ok = await ref
        .read(entitlementProvider.notifier)
        .purchase(_selected);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'پرمیوم ${_selected.titleFa} فعال شد. ممنون از حمایتت!'
              : 'پرداخت همراه با انتشار در فروشگاه‌ها فعال می‌شود؛ '
                  'فعلاً از کدِ کمپین استفاده کن.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entitlement = ref.watch(entitlementProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('پرمیوم')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ── Hero ────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 130,
              width: double.infinity,
              child: Image.asset(
                'assets/images/premium_bg.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            highlight: true,
            accent: AppTheme.gold,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [AppTheme.gold, AppTheme.violet],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.gold.withValues(alpha: 0.35),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'طالع بین پرمیوم',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                    const SizedBox(width: 8),
                    PremiumBadge(active: entitlement.hasPremium),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  entitlement.hasPremium
                      ? 'اشتراک تو فعال است — از تمام امکانات لذت ببر.'
                      : 'تجربه‌ای عمیق‌تر از آسمانِ تو',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Feature list ────────────────────────────────────────
          GlassCard(
            child: Column(
              children: const [
                _FeatureRow(
                  icon: Icons.auto_awesome,
                  title: 'تحلیل عمیق‌ترِ روزانه',
                  detail: 'متن کامل عشق، کار، مالی، روحیه + هشدار و فرصت',
                ),
                _FeatureRow(
                  icon: Icons.favorite,
                  title: 'تحلیل کامل رابطه',
                  detail: 'توصیه‌های اختصاصی برای تو و شریک عاطفی‌ات',
                ),
                _FeatureRow(
                  icon: Icons.brightness_3,
                  title: 'نقشهٔ تولد',
                  detail:
                      'جایگاهِ واقعیِ سیاره‌ها، طالعِ دقیق، خانه‌ها و زاویه‌های نقشه — محاسبهٔ آفلاین روی گوشیِ خودت',
                ),
                _FeatureRow(
                  icon: Icons.insights_outlined,
                  title: 'گزارش ماهانهٔ پیشرفته',
                  detail: 'فرصت‌ها و هشدارهای هر ماه برای برجِ تو',
                ),
                _FeatureRow(
                  icon: Icons.block,
                  title: 'حذف تبلیغات',
                  detail: 'تجربه‌ای تمیز و بی‌واسطه',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Free vs premium clarity (no dark patterns) ─────────
          GlassCard(
            accent: AppTheme.sky,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'چه چیزهایی رایگان است؟',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'پروفایل و برج تولد، طالع روزانهٔ پایه، طالع هفتگی، سازگاری با ۱۲ برج، '
                  'رنگ و عدد شانس — همه همیشه رایگان‌اند.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.95,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Launch campaign (promo code) ────────────────────────
          if (!entitlement.hasPremium) ...[
            GlassCard(
              highlight: true,
              accent: AppTheme.gold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_offer, color: AppTheme.gold, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${PromoCodes.launch.campaignFa} — '
                        '${PersianNumbers.toPersianNum(PromoCodes.launch.percentOff)}٪ تخفیف',
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
                  Text(
                    'تا پایانِ کمپین، پرمیومِ همیشگی با کدِ تخفیف رایگان فعال می‌شود. '
                    'کد را این‌جا وارد کن:',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.9,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _promoController,
                          enabled: !_redeeming,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            letterSpacing: 2,
                            fontFamily: 'Vazirmatn',
                          ),
                          decoration: InputDecoration(
                            hintText: PromoCodes.launch.code,
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.35),
                            ),
                            isDense: true,
                            errorText: _promoError,
                          ),
                          onSubmitted: (_) => _redeemPromo(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.tonal(
                        onPressed: _redeeming ? null : _redeemPromo,
                        child: _redeeming
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Text('فعال‌سازی'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ] else if (entitlement.source == EntitlementSource.promo) ...[
            GlassCard(
              accent: AppTheme.gold,
              child: Row(
                children: [
                  const Icon(Icons.local_offer, color: AppTheme.gold, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'پرمیوم تو با کدِ «${PromoCodes.launch.campaignFa}» فعال شده است.',
                      style: const TextStyle(fontFamily: 'Vazirmatn'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // ── Plans ───────────────────────────────────────────────
          if (!entitlement.hasPremium) ...[
            _PlanCard(
              plan: PremiumPlan.monthly,
              selected: _selected == PremiumPlan.monthly,
              price: '۹۸ هزار تومان',
              note: 'در ماه',
              onSelect: () => setState(
                  () => _selected = PremiumPlan.monthly),
            ),
            const SizedBox(height: 10),
            _PlanCard(
              plan: PremiumPlan.yearly,
              selected: _selected == PremiumPlan.yearly,
              price: '۴۹۰ هزار تومان',
              note: 'در سال — معادل ۵۸٪ تخفیف',
              badge: 'پیشنهاد ما',
              onSelect: () =>
                  setState(() => _selected = PremiumPlan.yearly),
            ),
            const SizedBox(height: 10),
            _PlanCard(
              plan: PremiumPlan.lifetime,
              selected: _selected == PremiumPlan.lifetime,
              price: '۹۸۰ هزار تومان',
              note: 'یک بار، برای همیشه',
              onSelect: () => setState(
                  () => _selected = PremiumPlan.lifetime),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _activate,
                icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                label: Text('فعال‌سازی ${_selected.titleFa}'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'پرداختِ درون‌برنامه‌ای همراه با انتشار در فروشگاه‌ها فعال می‌شود؛ '
              'تا آن زمان، پرمیوم با کدِ کمپین فعال می‌شود. هیچ مبلغی الان '
              'دریافت نمی‌شود.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.8,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                fontFamily: 'Vazirmatn',
              ),
            ),
          ] else ...[
            GlassCard(
              accent: const Color(0xFF4CD97B),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Color(0xFF4CD97B)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'اشتراک پرمیوم ${entitlement.plan?.titleFa ?? ''} فعال است.',
                      style: const TextStyle(fontFamily: 'Vazirmatn'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.gold.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 19, color: AppTheme.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.price,
    required this.note,
    required this.onSelect,
    this.badge,
  });

  final PremiumPlan plan;
  final bool selected;
  final String price;
  final String note;
  final VoidCallback onSelect;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      accent: selected ? AppTheme.violet : null,
      highlight: selected,
      onTap: onSelect,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            size: 20,
            color: selected
                ? AppTheme.violet
                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'پرمیوم ${plan.titleFa}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppTheme.gold,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
              fontFamily: 'Vazirmatn',
            ),
          ),
        ],
      ),
    );
  }
}

// Version constant surfaced in about/settings.
const String kAppVersion = '۱.۰.۰';

String get appVersionDisplay => PersianNumbers.toPersian('1.0.0');
