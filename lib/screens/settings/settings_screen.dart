import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/customer_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../../core/utils/prefs_store.dart';
import '../../models/app_settings_model.dart';
import '../../models/user_model.dart';
import '../../models/business_profile_model.dart';
import '../../store/screens/installment/installment_providers_screen.dart';

const _orange = AppTheme.RubyPrimary;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final business = ref.watch(businessProvider);
    final settings = ref.watch(settingsProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات برنامه'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline, color: _orange),
                  title: const Text('ویرایش مشخصات کاربر'),
                  subtitle: Text(user.name),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => _editUserProfile(context, user),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.store_outlined, color: _orange),
                  title: const Text('ویرایش پروفایل کسب‌وکار'),
                  subtitle: Text(business.shopName),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => _editBusinessProfile(context, business),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined, color: _orange),
                  title: const Text('تنظیمات فاکتور'),
                  subtitle: Text('شماره شروع: ${settings.startingInvoiceNum}'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => _editInvoiceSettings(context, settings),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette_outlined, color: _orange),
                  title: const Text('انتخاب رنگ و تم برنامه'),
                  subtitle: const Text('رنگ اصلی برنامه و فاکتور'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: _showThemePicker,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.schedule, color: _orange),
                  title: const Text('تنظیمات درگاه‌های اقساطی'),
                  subtitle: const Text('تعداد قسط، درصد کارمزد و زمان‌بندی تسویهٔ هر درگاه'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InstallmentProvidersScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('پشتیبان‌گیری و بازیابی محلی'),
                  subtitle: const Text('خروجی JSON از اطلاعات برنامه'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: _showBackupSheet,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick summary
          Card(
            color: dark ? null : const Color(0xFFFFF7ED),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'خلاصه مشخصات',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  _infoRow('نام', user.name),
                  _infoRow('تلفن کاربر', user.phone.isEmpty ? '—' : user.phone),
                  _infoRow('کشور / شهر', '${user.country} · ${user.city}'),
                  _infoRow('استان', user.province.isEmpty ? '—' : user.province),
                  _infoRow('نوع فعالیت', _usageLabel(user.usageType)),
                  _infoRow('فروشگاه', business.shopName),
                  _infoRow('تلفن کسب‌وکار', business.phone.isEmpty ? '—' : business.phone),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Center(
            child: Text(
              'مدیریت سفارشات و حسابداری جاوید\nناشر: Studio Javid (استودیو جاوید)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _showThemePicker() async {
    const colors = [
      Color(0xFFF97316),
      Color(0xFFE9573F),
      Color(0xFF8B5CF6),
      Color(0xFF2563EB),
      Color(0xFF0F766E),
      Color(0xFF16A34A),
      Color(0xFFDB2777),
      Color(0xFF475569),
    ];
    final selected = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'انتخاب رنگ و تم برنامه',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 18,
              runSpacing: 18,
              children: colors
                  .map(
                    (color) => InkWell(
                      onTap: () => Navigator.pop(ctx, color.value),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      final current = ref.read(settingsProvider);
      await ref.read(settingsProvider.notifier).updateSettings(
            current.copyWith(
              accentColor: selected,
              themeMode: 'light',
            ),
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رنگ برنامه ذخیره شد')),
      );
    }
  }

  Future<void> _showBackupSheet() async {
    if (!mounted) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Text(
                'پشتیبان‌گیری و بازیابی',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined, color: _orange),
              title: const Text('ساخت فایل پشتیبان'),
              subtitle: const Text('ذخیره و اشتراک‌گذاری فایل JSON'),
              onTap: () => Navigator.pop(ctx, 'export'),
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined, color: _orange),
              title: const Text('بازگردانی فایل پشتیبان'),
              subtitle: const Text('انتخاب فایل JSON از حافظه گوشی'),
              onTap: () => Navigator.pop(ctx, 'import'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'export') {
      await _exportBackup();
    } else if (action == 'import') {
      await _importBackup();
    }
  }

  Future<void> _exportBackup() async {
    try {
      final payload = await PrefsStore.exportAll();
      final directory = await getApplicationDocumentsDirectory();
      final name = 'factor-ruby-backup-${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$name');
      await file.writeAsString(
        JsonEncoder.withIndent('  ').convert(payload),
        flush: true,
      );

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json', name: name)],
        subject: 'پشتیبان مدیریت سفارشات و حسابداری جاوید',
        text: 'فایل پشتیبان اطلاعات فاکتور ساز روبی',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ساخت پشتیبان انجام نشد: $error')),
      );
    }
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false,
      );
      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        throw const FormatException('ساختار فایل پشتیبان معتبر نیست');
      }

      await PrefsStore.importAll(Map<String, dynamic>.from(decoded));
      ref.invalidate(userProvider);
      ref.invalidate(businessProvider);
      ref.invalidate(settingsProvider);
      ref.invalidate(invoiceListProvider);
      ref.invalidate(customerListProvider);
      ref.invalidate(productListProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پشتیبان با موفقیت بازگردانی شد.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('بازگردانی پشتیبان انجام نشد: $error')),
      );
    }
  }

  Widget _infoRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(k, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  String _usageLabel(String id) {
    const map = {
      'store': 'فروشگاه',
      'online_store': 'فروشگاه اینترنتی',
      'services': 'خدمات',
      'wholesale': 'عمده‌فروشی',
      'freelance': 'فریلنسر',
      'personal': 'استفاده شخصی',
      'simple_acc': 'حسابداری ساده',
      'other': 'سایر',
    };
    return map[id] ?? id;
  }

  Future<void> _editUserProfile(BuildContext context, UserModel user) async {
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);
    final countryCtrl = TextEditingController(text: user.country);
    final provinceCtrl = TextEditingController(text: user.province);
    final cityCtrl = TextEditingController(text: user.city);
    String usage = user.usageType;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).viewPadding.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ویرایش مشخصات کاربر',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'نام شما *',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'شماره تلفن / همراه',
                        hintText: '۰۹۱۲…',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: countryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'کشور',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: provinceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'استان',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'شهر',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: usage,
                      decoration: const InputDecoration(
                        labelText: 'نوع فعالیت',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'store', child: Text('فروشگاه')),
                        DropdownMenuItem(value: 'services', child: Text('خدمات')),
                        DropdownMenuItem(value: 'wholesale', child: Text('عمده‌فروشی')),
                        DropdownMenuItem(value: 'freelance', child: Text('فریلنسر')),
                        DropdownMenuItem(value: 'personal', child: Text('استفاده شخصی')),
                        DropdownMenuItem(value: 'simple_acc', child: Text('حسابداری ساده')),
                        DropdownMenuItem(value: 'other', child: Text('سایر')),
                      ],
                      onChanged: (v) {
                        if (v != null) setModal(() => usage = v);
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _orange,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('نام کاربر نمی‌تواند خالی باشد')),
                            );
                            return;
                          }
                          Navigator.pop(ctx, true);
                        },
                        child: const Text(
                          'ذخیره مشخصات',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (saved == true && mounted) {
      ref.read(userProvider.notifier).updateUser(
            user.copyWith(
              name: nameCtrl.text.trim(),
              phone: phoneCtrl.text.trim(),
              country: countryCtrl.text.trim().isEmpty ? 'ایران' : countryCtrl.text.trim(),
              province: provinceCtrl.text.trim(),
              city: cityCtrl.text.trim(),
              usageType: usage,
              isOnboarded: true,
            ),
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مشخصات کاربر ذخیره شد')),
      );
    }

    nameCtrl.dispose();
    phoneCtrl.dispose();
    countryCtrl.dispose();
    provinceCtrl.dispose();
    cityCtrl.dispose();
  }

  Future<void> _editBusinessProfile(
    BuildContext context,
    BusinessProfileModel business,
  ) async {
    final shopCtrl = TextEditingController(text: business.shopName);
    final phoneCtrl = TextEditingController(text: business.phone);
    final addressCtrl = TextEditingController(text: business.address);
    final taxCtrl = TextEditingController(text: business.taxId);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).viewPadding.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ویرایش پروفایل کسب‌وکار',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: shopCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نام فروشگاه / کسب‌وکار',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'شماره تماس',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'آدرس',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: taxCtrl,
                  decoration: const InputDecoration(
                    labelText: 'شناسه ملی / کد اقتصادی',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(
                      'ذخیره کسب‌وکار',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saved == true && mounted) {
      ref.read(businessProvider.notifier).updateBusiness(
            business.copyWith(
              shopName: shopCtrl.text.trim().isEmpty ? 'فاکتور ساز روبی' : shopCtrl.text.trim(),
              phone: phoneCtrl.text.trim(),
              address: addressCtrl.text.trim(),
              taxId: taxCtrl.text.trim(),
            ),
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اطلاعات کسب‌وکار ذخیره شد')),
      );
    }

    shopCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    taxCtrl.dispose();
  }

  Future<void> _editInvoiceSettings(
    BuildContext context,
    AppSettingsModel settings,
  ) async {
    final startCtrl = TextEditingController(text: settings.startingInvoiceNum.toString());
    String template = settings.templateStyle;
    bool showLogo = settings.showLogo;
    bool showCard = settings.showCardNum;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).viewPadding.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'تنظیمات فاکتور',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: startCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'شماره شروع فاکتور بعدی',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: template,
                      decoration: const InputDecoration(
                        labelText: 'قالب فاکتور',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'modern', child: Text('مدرن')),
                        DropdownMenuItem(value: 'classic', child: Text('کلاسیک')),
                        DropdownMenuItem(value: 'simple', child: Text('ساده')),
                      ],
                      onChanged: (v) {
                        if (v != null) setModal(() => template = v);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('نمایش لوگو روی فاکتور'),
                      value: showLogo,
                      activeColor: _orange,
                      onChanged: (v) => setModal(() => showLogo = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('نمایش شماره کارت'),
                      value: showCard,
                      activeColor: _orange,
                      onChanged: (v) => setModal(() => showCard = v),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _orange,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'ذخیره تنظیمات',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (saved == true && mounted) {
      ref.read(settingsProvider.notifier).updateSettings(
            settings.copyWith(
              startingInvoiceNum: int.tryParse(startCtrl.text.trim()) ?? settings.startingInvoiceNum,
              templateStyle: template,
              showLogo: showLogo,
              showCardNum: showCard,
            ),
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تنظیمات فاکتور ذخیره شد')),
      );
    }
    startCtrl.dispose();
  }
}
