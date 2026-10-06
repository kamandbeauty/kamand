import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../data/settings/settings_service.dart';
import '../../providers/app_providers.dart';
import '../../widgets/glass_card.dart';
import '../onboarding/onboarding_screen.dart';

/// Selectable theme-mode row (avoids version-sensitive Radio APIs).
class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ThemeModeSetting mode;
  final bool selected;
  final VoidCallback onTap;

  String get _label {
    switch (mode) {
      case ThemeModeSetting.dark:
        return 'تیره (آسمان شب)';
      case ThemeModeSetting.light:
        return 'روشن';
      case ThemeModeSetting.system:
        return 'هماهنگ با سیستم';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 18,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// تنظیمات — notifications, appearance, data reset (product spec §49/§50).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _resetting = false;

  Future<void> _toggleNotifications(bool value) async {
    final settings = ref.read(settingsProvider);
    if (value) {
      final granted = await ref
          .read(settingsProvider.notifier)
          .enableNotifications(
            settings.notificationHour,
            settings.notificationMinute,
          );
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('اجازهٔ اعلان داده نشد. از تنظیمات گوشی فعالش کن.'),
          ),
        );
      }
    } else {
      await ref.read(settingsProvider.notifier).disableNotifications();
    }
  }

  Future<void> _pickTime() async {
    final settings = ref.read(settingsProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.notificationHour,
        minute: settings.notificationMinute,
      ),
      helpText: 'زمان اعلان روزانه',
      confirmText: 'تأیید',
      cancelText: 'انصراف',
    );
    if (picked != null) {
      await ref
          .read(settingsProvider.notifier)
          .setNotificationTime(picked.hour, picked.minute);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'یادآوری روزانه برای ساعت ${PersianNumbers.twoDigits(picked.hour)}:'
              '${PersianNumbers.twoDigits(picked.minute)} تنظیم شد.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmWipe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف تمام اطلاعات من'),
        content: const Text(
          'تمام اطلاعات پروفایل، شریک عاطفی و تنظیمات حذف خواهد شد. '
          'این کار قابل بازگشت نیست. مطمئنی؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.rose),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف کن'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _resetting = true);
    try {
      await ref.read(primaryProfileProvider.notifier).wipe();
      await ref.read(entitlementProvider.notifier).reset();
      await ref.read(settingsProvider.notifier).resetAll();
      await ref.read(partnerProvider.notifier).loadFor('reset');
    } finally {
      setState(() => _resetting = false);
    }

    if (!mounted) return;
    // Fresh start → onboarding.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: _resetting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // ── Notifications ─────────────────────────────────
                GlassCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: settings.notificationsEnabled,
                        onChanged: _toggleNotifications,
                        title: const Text(
                          'اعلان روزانه',
                          style: TextStyle(fontFamily: 'Vazirmatn'),
                        ),
                        subtitle: Text(
                          'هر روز طالع امروزت را یادآوری می‌کنیم',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 11,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        secondary: const Icon(
                          Icons.notifications_active_outlined,
                          color: AppTheme.violet,
                        ),
                      ),
                      if (settings.notificationsEnabled)
                        ListTile(
                          leading: const Icon(Icons.schedule, size: 20),
                          title: const Text(
                            'زمان اعلان',
                            style: TextStyle(fontFamily: 'Vazirmatn'),
                          ),
                          trailing: Text(
                            '${PersianNumbers.twoDigits(settings.notificationHour)}:'
                            '${PersianNumbers.twoDigits(settings.notificationMinute)}',
                            style: const TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: _pickTime,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Appearance ────────────────────────────────────
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Text(
                          'ظاهر برنامه',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                      ),
                      for (final mode in ThemeModeSetting.values)
                        _ThemeModeTile(
                          mode: mode,
                          selected: settings.themeMode == mode,
                          onTap: () => ref
                              .read(settingsProvider.notifier)
                              .setThemeMode(mode),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Danger zone ───────────────────────────────────
                GlassCard(
                  accent: AppTheme.rose,
                  child: Column(
                    children: [
                      ListTile(
                        leading:
                            const Icon(Icons.delete_outline, color: AppTheme.rose),
                        title: const Text(
                          'حذف تمام اطلاعات من',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            color: AppTheme.rose,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          'بازگشت به ابتدای برنامه',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 11,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        onTap: _confirmWipe,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'نسخهٔ ${PersianNumbers.toPersian('1.0.0')} — همهٔ داده‌ها فقط روی همین دستگاه ذخیره می‌شود.',
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
}
