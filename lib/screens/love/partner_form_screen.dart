import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/cities.dart';
import '../../core/date/app_date.dart';
import '../../data/analytics/analytics_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/profile/profile.dart';
import '../../providers/app_providers.dart';
import '../../providers/horoscope_providers.dart';
import '../../widgets/birth_date_picker.dart';
import '../../widgets/glass_card.dart';

/// افزودن/ویرایش شریک عاطفی (product spec §19).
class PartnerFormScreen extends ConsumerStatefulWidget {
  const PartnerFormScreen({super.key});

  @override
  ConsumerState<PartnerFormScreen> createState() => _PartnerFormScreenState();
}

class _PartnerFormScreenState extends ConsumerState<PartnerFormScreen> {
  final _nameController = TextEditingController();
  int _year = AppDate.maxBirthYear - 25;
  int _month = 1;
  int _day = 1;
  String? _city;
  bool _saving = false;

  Partner? _editing;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(partnerProvider).partner;
    if (existing != null) {
      _editing = existing;
      _nameController.text = existing.name;
      final parts = existing.birthDate.split('-');
      if (parts.length == 3) {
        _year = int.tryParse(parts[0]) ?? _year;
        _month = int.tryParse(parts[1]) ?? _month;
        _day = int.tryParse(parts[2]) ?? _day;
      }
      _city = existing.birthCity;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نام شریک عاطفی را بنویس.')),
      );
      return;
    }
    if (!AppDate.isValid(_year, _month, _day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تاریخ تولد معتبر نیست.')),
      );
      return;
    }

    final profile = ref.read(primaryProfileProvider).profile;
    if (profile == null) return;

    setState(() => _saving = true);

    final calc = ref.read(zodiacCalculatorProvider).calculate(
          AppDate.fromYMD(_year, _month, _day),
        );
    if (calc == null) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تاریخ تولد قابل پردازش نیست.')),
        );
      }
      return;
    }

    final notifier = ref.read(partnerProvider.notifier);
    final error = await notifier.save(
      Partner(
        id: _editing?.id ?? generateId(),
        profileId: profile.id,
        name: _nameController.text.trim(),
        birthDate:
            '$_year-${_month.toString().padLeft(2, '0')}-${_day.toString().padLeft(2, '0')}',
        birthCity: _city,
        zodiacId: calc.sign.id,
        createdAt: _editing?.createdAt ?? utcNowIso(),
      ),
    );

    setState(() => _saving = false);
    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }

    ref.read(analyticsProvider).logEvent(AnalyticsEvent.partnerCreated.id);
    ref.invalidate(coupleCompatibilityProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editing == null
                ? 'شریک عاطفی اضافه شد: ${calc.sign.nameFa}'
                : 'اطلاعات شریک عاطفی به‌روز شد.',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final editing = _editing;
    if (editing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف شریک عاطفی'),
        content: const Text('اطلاعات این شخص از گوشی تو حذف می‌شود.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.rose,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف کن'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(partnerProvider.notifier).remove();
      ref.invalidate(coupleCompatibilityProvider);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing == null ? 'افزودن شریک عاطفی' : 'ویرایش شریک عاطفی'),
        actions: [
          if (_editing != null)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, size: 21),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          GlassCard(
            accent: AppTheme.rose,
            child: Text(
              'اطلاعات فقط روی گوشی خودت ذخیره می‌شود و جایی ارسال نمی‌شود.',
              style: TextStyle(
                fontSize: 12,
                height: 1.9,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                fontFamily: 'Vazirmatn',
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _nameController,
            maxLength: 24,
            textInputAction: TextInputAction.done,
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
              color: theme.colorScheme.onSurface,
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
            'شهر تولد (اختیاری)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              fontFamily: 'Vazirmatn',
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: _city,
            items: [
              const DropdownMenuItem(value: null, child: Text('بدون انتخاب')),
              for (final city in kIranCities)
                DropdownMenuItem(value: city, child: Text(city)),
            ],
            onChanged: (v) => setState(() => _city = v),
            decoration: const InputDecoration(hintText: 'شهر'),
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
                  : const Icon(Icons.favorite, size: 18),
              label: Text(_editing == null ? 'افزودن' : 'ذخیرهٔ تغییرات'),
            ),
          ),
        ],
      ),
    );
  }
}
