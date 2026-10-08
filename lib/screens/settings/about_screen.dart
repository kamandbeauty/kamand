import 'package:flutter/material.dart';

import '../../core/constants/app_info.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';

/// دربارهٔ برنامه + بیانیهٔ محتوا (entertainment disclaimer — spec §48).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('دربارهٔ برنامه'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'نسخهٔ ${PersianNumbers.toPersian(AppInfo.version)}'
              ' (${PersianNumbers.toPersianNum(AppInfo.buildNumber)})',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontFamily: 'Vazirmatn',
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          GlassCard(
            highlight: true,
            accent: AppTheme.violet,
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [AppTheme.violet, AppTheme.gold],
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'طالع بین',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'نسخهٔ ${PersianNumbers.toPersian(AppInfo.version)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _TextCard(
            title: 'این برنامه چه می‌کند؟',
            body:
                '«طالع بین» بر اساس تاریخ تولد تو، برج ستاره‌ای‌ات را محاسبه می‌کند و '
                'هر روز طالع، امتیازها، رنگ و عدد شانس و تحلیل سازگاری عاطفی را نمایش می‌دهد. '
                'همهٔ محاسبات به‌صورت آفلاین و روی همین دستگاه انجام می‌شود.',
          ),
          const SizedBox(height: 12),
          const _TextCard(
            title: 'بیانیهٔ محتوا',
            body:
                'محتوای این برنامه بر پایهٔ سنّت‌های کهن اخترگویی (آسترولاژی) تدوین شده و '
                'جنبهٔ سرگرمی و تفسیری دارد؛ نه ادعای علمی و نه پیش‌بینی قطعی است. '
                'برای تصمیم‌های مهمِ زندگی — پزشکی، مالی یا حقوقی — همیشه به متخصص مراجعه کن.',
            emphasized: true,
          ),
          const SizedBox(height: 12),
          const _TextCard(
            title: 'داده‌ها و حریم خصوصی',
            body:
                'هیچ اطلاعاتی از تو به سرور ارسال نمی‌شود؛ حتی دسترسی اینترنت هم برای برنامه وجود ندارد. '
                'اطلاعات تولد فقط برای محاسبات داخلی استفاده می‌شود و هر لحظه می‌توانی همهٔ آن را حذف کنی.',
          ),
        ],
      ),
    );
  }
}

/// حریم خصوصی (product spec §35).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حریم خصوصی')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [
          _TextCard(
            title: 'چه داده‌هایی ذخیره می‌شود؟',
            body:
                'فقط اطلاعاتی که خودت وارد می‌کنی: نام (اختیاری)، تاریخ و ساعت تولد، شهر تولد (اختیاری) '
                'و تنظیمات برنامه. همهٔ این داده‌ها روی حافظهٔ همین دستگاه ذخیره می‌شود.',
          ),
          SizedBox(height: 12),
          _TextCard(
            title: 'داده‌ها کجا می‌روند؟',
            body:
                'به هیچ‌جا. برنامه دسترسی اینترنت ندارد و هیچ سروری در کار نیست. '
                'بدون اجازهٔ صریح تو، هیچ داده‌ای از دستگاه خارج نمی‌شود.',
          ),
          SizedBox(height: 12),
          _TextCard(
            title: 'مجوزها',
            body:
                'تنها مجوزهای لازم: اعلان‌ها (برای یادآوری روزانه، فقط اگر فعالش کنی) و '
                'دریافت رویداد راه‌اندازی (برای حفظ زمان یادآوری پس از ری‌استارت گوشی). '
                'هیچ مجوز موقعیت مکانی، مخاطبین یا دوربینی درخواست نمی‌شود.',
          ),
          SizedBox(height: 12),
          _TextCard(
            title: 'حذف داده‌ها',
            body:
                'از مسیر تنظیمات ← «حذف تمام اطلاعات من» می‌توانی همهٔ داده‌ها را برای همیشه پاک کنی.',
          ),
          SizedBox(height: 12),
          _TextCard(
            title: 'اطلاعات تولد؛ دادهٔ شخصی',
            body:
                'تاریخ تولد جزو داده‌های شخصی محسوب می‌شود؛ به همین دلیل طراحی برنامه بر '
                '«ذخیرهٔ محلی و بدون حساب کاربری» استوار است.',
          ),
        ],
      ),
    );
  }
}

/// شرایط استفاده.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('شرایط استفاده')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [
          _TextCard(
            title: 'ماهیت محتوا',
            body:
                'محتوای طالع‌بینی این برنامه تفسیری و سرگرم‌کننده است و مبنای علمی قطعی ندارد. '
                'مسئولیت هر تصمیمی که بر اساس این محتوا بگیری، با خود توست.',
          ),
          SizedBox(height: 12),
          _TextCard(
            title: 'بدون ضمانت',
            body:
                'خدمات «همان‌گونه که هست» ارائه می‌شود. برنامه جایگزین مشاورهٔ پزشکی، مالی یا حقوقی نیست.',
          ),
          SizedBox(height: 12),
          _TextCard(
            title: 'استفادهٔ منصفانه',
            body:
                'خروجی‌های برنامه را می‌توانی برای سرگرمی شخصی و اشتراک با دوستان استفاده کنی؛ '
                'بازنشر تجاری محتوای برنامه مجاز نیست.',
          ),
        ],
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({
    required this.title,
    required this.body,
    this.emphasized = false,
  });

  final String title;
  final String body;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      accent: emphasized ? AppTheme.gold : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              fontFamily: 'Vazirmatn',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.5,
              height: 2,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              fontFamily: 'Vazirmatn',
            ),
          ),
        ],
      ),
    );
  }
}
