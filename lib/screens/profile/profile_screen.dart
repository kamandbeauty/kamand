import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date/app_date.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../data/repositories/profile_repository.dart';
import '../../providers/app_providers.dart';
import '../../providers/horoscope_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../love/partner_form_screen.dart';
import '../settings/about_screen.dart';
import '../settings/settings_screen.dart';
import '../premium/premium_screen.dart';
import 'profile_edit_screen.dart';

/// پروفایل — avatar, quick info, all actions (product spec §21).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(primaryProfileProvider);
    final entitlement = ref.watch(entitlementProvider);

    if (!profileState.ready) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    final profile = profileState.profile;
    if (profile == null) {
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [ErrorState(message: 'پروفایلی یافت نشد.')],
        ),
      );
    }

    final sign = ref.watch(zodiacSignByIdProvider(profile.zodiacId));
    final birthDate = parseJalaliDateKey(profile.birthDate);
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          // ── Header card ─────────────────────────────────────────
          GlassCard(
            highlight: true,
            accent: AppTheme.violet,
            padding: const EdgeInsets.all(22),
            child: Column(
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
                    child: ZodiacSymbol(sign?.symbol ?? '?', fontSize: 44),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  profile.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sign == null
                      ? '—'
                      : '${sign.nameFa} · ${sign.nameEn}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (birthDate != null)
                      InfoChip(
                        label: AppDate.formatMedium(
                          AppDate.fromYMD(
                            birthDate.year,
                            birthDate.month,
                            birthDate.day,
                          ),
                        ),
                        icon: Icons.cake_outlined,
                      ),
                    if (profile.birthTimeKnown && profile.birthTime != null)
                      InfoChip(
                        label: 'ساعت ${PersianNumbers.toPersian(profile.birthTime!)}',
                        icon: Icons.schedule,
                      ),
                    if (profile.birthCity != null)
                      InfoChip(
                        label: profile.birthCity!,
                        icon: Icons.location_on_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Actions ─────────────────────────────────────────────
          _ActionTile(
            icon: Icons.edit_outlined,
            title: 'ویرایش اطلاعات',
            subtitle: 'نام، تاریخ تولد، ساعت و شهر',
            onTap: () => _push(context, const ProfileEditScreen()),
          ),
          _ActionTile(
            icon: Icons.favorite_border,
            title: 'شریک عاطفی',
            subtitle: 'افزودن یا ویرایش برای محاسبهٔ سازگاری زوج',
            onTap: () => _push(context, const PartnerFormScreen()),
          ),
          _ActionTile(
            icon: Icons.notifications_active_outlined,
            title: 'اعلان روزانه',
            subtitle: 'یادآوری صبحگاهی طالع امروز',
            onTap: () => _push(context, const SettingsScreen()),
          ),
          _ActionTile(
            icon: Icons.dark_mode_outlined,
            title: 'ظاهر برنامه',
            subtitle: 'تیره، روشن یا هماهنگ با سیستم',
            onTap: () => _push(context, const SettingsScreen()),
          ),
          _ActionTile(
            icon: Icons.workspace_premium_outlined,
            title: 'پرمیوم',
            subtitle: entitlement.hasPremium ? 'فعال است' : 'تحلیل عمیق‌تر، چارت تولد و بیشتر',
            accent: AppTheme.gold,
            badge: entitlement.hasPremium ? 'فعال' : 'پرمیوم',
            onTap: () => _push(context, const PremiumScreen()),
          ),
          _ActionTile(
            icon: Icons.info_outline,
            title: 'دربارهٔ برنامه',
            subtitle: 'نسخه، سازنده و بیانیهٔ محتوا',
            onTap: () => _push(context, const AboutScreen()),
          ),
          _ActionTile(
            icon: Icons.privacy_tip_outlined,
            title: 'حریم خصوصی',
            subtitle: 'داده‌ها فقط روی دستگاه تو',
            onTap: () => _push(context, const PrivacyScreen()),
          ),
          _ActionTile(
            icon: Icons.description_outlined,
            title: 'شرایط استفاده',
            subtitle: 'محدودیت مسئولیت',
            onTap: () => _push(context, const TermsScreen()),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                )
              else
                Icon(
                  Icons.arrow_back_ios_new,
                  size: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

