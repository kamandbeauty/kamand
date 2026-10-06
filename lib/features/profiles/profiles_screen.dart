import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/calendar/date_engine.dart';
import '../../core/normalization/persian_normalizer.dart';
import '../../domain/models/profile.dart';
import '../analysis/birth_analysis_screen.dart';
import '../shared/empty_state.dart';
import 'privacy_screen.dart';

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('پروفایل‌های محلی'),
        actions: [
          IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())), icon: const Icon(Icons.shield_outlined), tooltip: 'حریم خصوصی'),
          IconButton(onPressed: () => _showProfileDialog(context, ref), icon: const Icon(Icons.add), tooltip: 'افزودن پروفایل'),
        ],
      ),
      body: profiles.isEmpty
          ? const EmptyState(title: 'پروفایلی ثبت نشده', message: 'اطلاعات فقط روی همین دستگاه ذخیره می‌شود.', icon: Icons.person_add_alt_1_outlined)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              itemCount: profiles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final profile = profiles[index];
                final birth = profile.birthDate.isEmpty ? '' : ' · ${profile.birthDate} (${profile.birthCalendar == 'gregorian' ? 'میلادی' : 'شمسی'})';
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(profile.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(profile.name.isEmpty ? 'نام وارد نشده$birth' : '${profile.name}$birth'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BirthAnalysisScreen(profile: profile))), icon: const Icon(Icons.insights_outlined), tooltip: 'تحلیل تولد'),
                        IconButton(onPressed: () => ref.read(profilesProvider.notifier).delete(profile.id), icon: const Icon(Icons.delete_outline), tooltip: 'حذف'),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: profiles.isNotEmpty ? FloatingActionButton.extended(onPressed: () => _showProfileDialog(context, ref), icon: const Icon(Icons.add), label: const Text('افزودن')) : null,
    );
  }

  Future<void> _showProfileDialog(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final name = TextEditingController();
    final mother = TextEditingController();
    final birthDate = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var calendar = CalendarKind.jalali;
    String? birthError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('پروفایل جدید'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(controller: title, decoration: const InputDecoration(labelText: 'عنوان پروفایل'), validator: (value) => value == null || value.trim().isEmpty ? 'عنوان را وارد کنید' : null),
                    const SizedBox(height: 10),
                    TextField(controller: name, decoration: const InputDecoration(labelText: 'نام')),
                    const SizedBox(height: 10),
                    TextField(controller: mother, decoration: const InputDecoration(labelText: 'نام مادر (اختیاری)')),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<CalendarKind>(
                      initialValue: calendar,
                      decoration: const InputDecoration(labelText: 'تقویم تاریخ تولد'),
                      items: const [DropdownMenuItem(value: CalendarKind.jalali, child: Text('شمسی')), DropdownMenuItem(value: CalendarKind.gregorian, child: Text('میلادی'))],
                      onChanged: (value) => setDialogState(() => calendar = value ?? CalendarKind.jalali),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: birthDate, keyboardType: TextInputType.datetime, decoration: InputDecoration(labelText: 'تاریخ تولد (اختیاری)', hintText: calendar == CalendarKind.jalali ? '1403-01-01' : '2024-03-20', prefixIcon: const Icon(Icons.date_range_outlined))),
                    if (birthError != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(birthError!, style: const TextStyle(color: Colors.redAccent))),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final rawBirthDate = PersianNormalizer.toLatinDigits(birthDate.text.trim());
                  final parsedBirthDate = rawBirthDate.isEmpty ? null : DateEngine.parse(rawBirthDate, calendar);
                  if (rawBirthDate.isNotEmpty && parsedBirthDate == null) {
                    setDialogState(() => birthError = 'تاریخ واردشده برای تقویم انتخاب‌شده معتبر نیست.');
                    return;
                  }
                  final now = DateTime.now().toUtc().toIso8601String();
                  ref.read(profilesProvider.notifier).save(Profile(id: 'profile-${now.hashCode}', title: title.text.trim(), name: name.text.trim(), motherName: mother.text.trim(), gender: 'نامشخص', birthDate: parsedBirthDate?.iso ?? '', birthCalendar: parsedBirthDate == null ? '' : calendar.name, createdAt: now));
                  Navigator.pop(dialogContext);
                },
                child: const Text('ذخیره'),
              ),
            ],
          );
        },
      ),
    );
    title.dispose();
    name.dispose();
    mother.dispose();
    birthDate.dispose();
  }
}
