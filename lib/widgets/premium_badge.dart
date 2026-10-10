import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// نشانِ کوچکِ «پرمیوم» — طلاییِ شیشه‌ای و بدونِ قاب.
///
/// طبقِ دستورِ محصول، این نشان همیشه — هم قبل و هم بعد از خریدِ
/// اشتراک — کنارِ قابلیت‌های ویژه می‌نشیند تا کاربر همیشه بداند
/// این بخش یک قابلیتِ پرمیوم است که می‌تواند از آن استفاده کند.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, this.active = false});

  /// آیا اشتراکِ کاربر همین حالا فعال است؟ (فقط ظاهرِ نشان عوض می‌شود؛
  /// نشان در هر دو حالت نمایش داده می‌شود.)
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: active ? 'قابلیت پرمیوم — فعال' : 'قابلیت پرمیوم',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AstralTokens.celestialGold
              .withValues(alpha: active ? 0.22 : 0.14),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active
                  ? Icons.verified_outlined
                  : Icons.workspace_premium_outlined,
              size: 12,
              color: AstralTokens.celestialGold,
            ),
            const SizedBox(width: 4),
            Text(
              active ? 'پرمیومِ فعال' : 'پرمیوم',
              style:
                  AstralTextStyles.badge(color: AstralTokens.celestialGold),
            ),
          ],
        ),
      ),
    );
  }
}

/// تیترِ بخش‌های پرمیومِ باز‌شده — عنوان + نشانِ همیشگیِ پرمیوم، تا
/// حتی وقتی محتوا در دسترس است، ماهیتِ ویژهٔ آن فراموش نشود.
class PremiumSectionTitle extends StatelessWidget {
  const PremiumSectionTitle(this.title, {super.key, this.active = false});

  final String title;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Icon(Icons.auto_awesome_outlined,
            size: 15, color: AstralTokens.celestialGold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style:
                AstralTextStyles.titleSmall(color: theme.colorScheme.onSurface),
          ),
        ),
        PremiumBadge(active: active),
      ],
    );
  }
}
