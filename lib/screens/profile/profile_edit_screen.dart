import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/cities.dart';
import '../../core/date/app_date.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/profile/profile.dart';
import '../../providers/app_providers.dart';
import '../../widgets/birth_date_picker.dart';

/// ویرایش پروفایل — name, birth date/time/city.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nameController = TextEditingController();
  int _year = 1370;
  int _month = 1;
  int _day = 1;
  int? _birthMinutes;
  String? _city;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(primaryProfileStateForEditProvider);
    if (profile != null) {
      _nameController.text = profile.name;
      final parts = profile.birthDate.split('-');
      if (parts.length == 3) {
        _year = int.tryParse(parts[0]) ?? _year;
        _month = int.tryParse(parts[1]) ?? _month;
        _day = int.tryParse(parts[2]) ?? _day;
      }
      final minutes = timeStringToMinutes(profile.birthTime);
      _birthMinutes = profile.birthTimeKnown ? minutes : null;
      _city = profile.birthCity;
    }
    _loaded = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profile = ref.read(primaryProfileStateForEditProvider);
    if (profile == null) return;

    if (!AppDate.isValid(_year, _month, _day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تاریخ تولد معتبر نیست.')),
      );
      return;
    }

    setState(() => _saving = true);
    final error = await ref.read(primaryProfileProvider.notifier).save(
          profile.copyWith(
            name: _nameController.text.trim().isEmpty
                ? profile.name
                : _nameController.text.trim(),
            birthDate:
                '$_year-${_month.toString().padLeft(2, '0')}-${_day.toString().padLeft(2, '0')}',
            birthTime: _birthMinutes == null
                ? null
                : minutesToTimeString(_birthMinutes!),
            birthTimeKnown: _birthMinutes != null,
            birthCity: _city,
            updatedAt: utcNowIso(),
          ),
        );
    setState(() => _saving = false);

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('اطلاعات پروفایل به‌روز شد.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('ویرایش اطلاعات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          TextField(
            controller: _nameController,
            maxLength: 24,
            decoration: const InputDecoration(
              labelText: 'نام یا نام مستعار',
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'تاریخ تولد',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Vazirmatn',
            ),
          ),
          const SizedBox(height: 12),
          BirthDateField(
            year: _year,
            month: _month,
            day: _day,
            onChanged: (y, m, d) => setState(() {
              _year = y;
              _month = m;
              _day = d;
            }),
          ),
          const SizedBox(height: 20),
          Text(
            'ساعت تولد (اختیاری)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Vazirmatn',
            ),
          ),
          const SizedBox(height: 12),
          BirthTimeField(
            selected: _birthMinutes,
            onChanged: (m) => setState(() => _birthMinutes = m),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String?>(
            initialValue: _city,
            items: [
              const DropdownMenuItem(value: null, child: Text('شهر تولد (اختیاری)')),
              for (final city in kIranCities)
                DropdownMenuItem(value: city, child: Text(city)),
            ],
            onChanged: (v) => setState(() => _city = v),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 18),
              label: const Text('ذخیرهٔ تغییرات'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small helper provider: current profile for pre-filling the form.
final primaryProfileStateForEditProvider = Provider<Profile?>((ref) {
  return ref.watch(primaryProfileProvider).profile;
});
