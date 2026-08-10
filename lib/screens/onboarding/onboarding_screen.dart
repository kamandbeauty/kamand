import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../dashboard/dashboard_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 1;

  final TextEditingController _nameController = TextEditingController(text: 'علی علوی');
  String _selectedCountry = 'ایران';
  String _selectedProvince = 'تهران';
  String _selectedCity = 'تهران';
  String _selectedUsageType = 'store';

  final List<String> _provinces = ['تهران', 'خراسان رضوی', 'اصفهان', 'فارس', 'آذربایجان شرقی', 'البرز', 'خوزستان'];

  void _nextStep() {
    if (_step == 1 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفا نام خود را وارد کنید')),
      );
      return;
    }

    if (_step < 5) {
      setState(() => _step++);
    } else {
      final updatedUser = UserModel(
        id: 'u1',
        name: _nameController.text.trim(),
        country: _selectedCountry,
        province: _selectedCountry == 'ایران' ? _selectedProvince : '',
        city: _selectedCity,
        usageType: _selectedUsageType,
        isOnboarded: true,
      );

      ref.read(userProvider.notifier).updateUser(updatedUser);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  void _prevStep() {
    if (_step > 1) {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: _step / 5,
              backgroundColor: Colors.grey.shade200,
              color: AppTheme.primaryBlue,
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'مرحله $_step از ۵',
                style: const TextStyle(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildStepContent(),
              ),
            ),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_step > 1 && _step < 5)
                    OutlinedButton(
                      onPressed: _prevStep,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('قبلی'),
                    )
                  else
                    const SizedBox.shrink(),

                  ElevatedButton(
                    onPressed: _nextStep,
                    child: Text(_step == 5 ? 'شروع استفاده از روبی' : 'بعدی'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 1:
        return Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.lightBlueBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, size: 48, color: AppTheme.primaryBlue),
            ),
            const SizedBox(height: 24),
            const Text(
              'سلام! من روبی هستم 👋',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'اسم شما چیه؟',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'مثلا: علی رضایی...',
              ),
            ),
          ],
        );

      case 2:
        return Column(
          children: [
            const Text(
              'کشور را انتخاب کنید',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppConstants.countries.map((c) {
                final selected = _selectedCountry == c;
                return ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  selectedColor: AppTheme.primaryBlue,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCountry = c);
                  },
                );
              }).toList(),
            ),
          ],
        );

      case 3:
        return Column(
          children: [
            const Text(
              'استان و شهر محل استقرار',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if (_selectedCountry == 'ایران') ...[
              DropdownButtonFormField<String>(
                value: _selectedProvince,
                decoration: const InputDecoration(labelText: 'استان'),
                items: _provinces
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedProvince = v!),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              initialValue: _selectedCity,
              decoration: const InputDecoration(labelText: 'شهر'),
              onChanged: (v) => _selectedCity = v,
            ),
          ],
        );

      case 4:
        return Column(
          children: [
            const Text(
              'نوع استفاده از برنامه',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: AppConstants.usageTypes.length,
              itemBuilder: (ctx, idx) {
                final item = AppConstants.usageTypes[idx];
                final selected = _selectedUsageType == item['id'];
                return Card(
                  color: selected ? AppTheme.lightBlueBg : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: selected ? AppTheme.primaryBlue : Colors.grey.shade300,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      item['title']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_circle, color: AppTheme.primaryBlue)
                        : null,
                    onTap: () => setState(() => _selectedUsageType = item['id']!),
                  ),
                );
              },
            ),
          ],
        );

      case 5:
        return Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.verified, size: 64, color: Colors.green),
            const SizedBox(height: 20),
            Text(
              'خوش آمدید، ${_nameController.text}! 🎉',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'اطلاعات شما ذخیره شد و اکنون می‌توانید صدور فاکتور را آغاز کنید.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
