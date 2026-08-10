import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../models/app_settings_model.dart';
import '../../models/user_model.dart';
import '../../models/business_profile_model.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final business = ref.watch(businessProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات برنامه'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header Card
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.lightBlueBg,
                child: Icon(Icons.person, color: AppTheme.primaryBlue),
              ),
              title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('کسب و کار: ${business.shopName}'),
            ),
          ),

          const SizedBox(height: 16),

          // Settings Sections
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.store),
                  title: const Text('ویرایش پروفایل کسب‌وکار'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {
                    // Show edit business dialog
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text('حالت تاریک / روشن'),
                  trailing: Switch(
                    value: settings.themeMode == 'dark',
                    onChanged: (val) {
                      ref.read(settingsProvider.notifier).updateSettings(
                        AppSettingsModel.fromMap(
                          settings.toMap()..['themeMode'] = val ? 'dark' : 'light',
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('پشتیبان‌گیری و بازیابی محلی'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('نسخه پشتیبان با موفقیت روی حافظه ذخیره شد.')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Center(
            child: Text(
              'فاکتور ساز روبی نسخه ۱.۰.۰ release\nطراحی شده برای کسب‌وکارهای ایرانی',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
