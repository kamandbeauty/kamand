import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/profile.dart';
import '../shared/empty_state.dart';
import 'privacy_screen.dart';

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('پروفایل‌های محلی'), actions: [IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())), icon: const Icon(Icons.shield_outlined), tooltip: 'حریم خصوصی'), IconButton(onPressed: () => _showProfileDialog(context, ref), icon: const Icon(Icons.add), tooltip: 'افزودن پروفایل')]),
      body: profiles.isEmpty
          ? EmptyState(title: 'پروفایلی ثبت نشده', message: 'اطلاعات فقط روی همین دستگاه ذخیره می‌شود.', icon: Icons.person_add_alt_1_outlined)
          : ListView.separated(padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), itemCount: profiles.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (context, index) { final profile = profiles[index]; return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person_outline)), title: Text(profile.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(profile.name.isEmpty ? 'نام وارد نشده' : profile.name), trailing: IconButton(onPressed: () => ref.read(profilesProvider.notifier).delete(profile.id), icon: const Icon(Icons.delete_outline), tooltip: 'حذف')); }),
      floatingActionButton: profiles.isNotEmpty ? FloatingActionButton.extended(onPressed: () => _showProfileDialog(context, ref), icon: const Icon(Icons.add), label: const Text('افزودن')) : null,
    );
  }

  Future<void> _showProfileDialog(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final name = TextEditingController();
    final mother = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('پروفایل جدید'), content: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextFormField(controller: title, decoration: const InputDecoration(labelText: 'عنوان پروفایل'), validator: (value) => value == null || value.trim().isEmpty ? 'عنوان را وارد کنید' : null), const SizedBox(height: 10), TextField(controller: name, decoration: const InputDecoration(labelText: 'نام')), const SizedBox(height: 10), TextField(controller: mother, decoration: const InputDecoration(labelText: 'نام مادر (اختیاری)'))]))), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')), FilledButton(onPressed: () { if (!formKey.currentState!.validate()) return; final now = DateTime.now().toUtc().toIso8601String(); ref.read(profilesProvider.notifier).save(Profile(id: 'profile-${now.hashCode}', title: title.text.trim(), name: name.text.trim(), motherName: mother.text.trim(), gender: 'نامشخص', birthDate: '', createdAt: now)); Navigator.pop(dialogContext); }, child: const Text('ذخیره'))]));
    title.dispose();
    name.dispose();
    mother.dispose();
  }
}
