import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../shared/section_title.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(privacySettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('حریم خصوصی')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          const SectionTitle(title: 'کنترل اطلاعات', subtitle: 'پیش‌فرض‌ها Privacy First هستند'),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: settings.analyticsEnabled,
                  onChanged: ref.read(privacySettingsProvider.notifier).setAnalyticsEnabled,
                  title: const Text('تحلیل ناشناس استفاده', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('در نسخه فعلی خاموش است و هیچ نام یا تاریخ تولدی ارسال نمی‌شود.'),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: settings.personalizedAdsEnabled,
                  onChanged: ref.read(privacySettingsProvider.notifier).setPersonalizedAdsEnabled,
                  title: const Text('تبلیغات شخصی‌سازی‌شده', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('در نسخه فعلی خاموش است؛ فعال‌سازی آن نیازمند رضایت کاربر است.'),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: settings.contentUpdatesEnabled,
                  onChanged: ref.read(privacySettingsProvider.notifier).setContentUpdatesEnabled,
                  title: const Text('دریافت به‌روزرسانی محتوا', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('در آینده برای دریافت بسته‌های محتوایی اختیاری استفاده می‌شود.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFFF6EDDC),
            child: const Padding(
              padding: EdgeInsets.all(17),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, color: Color(0xFF8A672B)),
                  SizedBox(width: 10),
                  Expanded(child: Text('پروفایل‌ها و تاریخ‌های تولد در نسخه فعلی فقط روی همین دستگاه ذخیره می‌شوند. این اطلاعات به‌عنوان Event تحلیل محصول ارسال نمی‌شوند.', style: TextStyle(height: 1.7))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
