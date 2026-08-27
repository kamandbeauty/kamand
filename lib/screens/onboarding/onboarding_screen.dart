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

  final TextEditingController _nameController = TextEditingController();
  String _selectedCountry = 'ایران';
  String _selectedCity = '';
  String _selectedUsageType = 'store';

  static const _onboardingRed = Color(0xFFE9573F);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 1 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفا نام خود را وارد کنید')),
      );
      return;
    }

    if (_step < 4) {
      setState(() => _step++);
    } else {
      final updatedUser = UserModel(
        id: 'u1',
        name: _nameController.text.trim(),
        phone: '',
        country: _selectedCountry,
        province: '',
        city: _selectedCity.trim(),
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
    final firstStep = _step == 1;
    return Scaffold(
      backgroundColor: firstStep ? _onboardingRed : null,
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _step / 4,
              minHeight: 4,
              backgroundColor: firstStep ? Colors.white.withValues(alpha: 0.25) : Colors.grey.shade200,
              color: firstStep ? Colors.white : AppTheme.primaryBlue,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Text(
                'مرحله $_step از ۴',
                style: TextStyle(
                  color: firstStep ? Colors.white : AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildStepContent(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_step > 1 && _step < 4)
                    OutlinedButton(
                      onPressed: _prevStep,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: firstStep ? Colors.white : AppTheme.primaryBlue,
                        side: BorderSide(color: firstStep ? Colors.white : AppTheme.primaryBlue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                      child: const Text('قبلی'),
                    )
                  else
                    const SizedBox.shrink(),
                  ElevatedButton(
                    onPressed: _nextStep,
                    style: firstStep
                        ? ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _onboardingRed,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          )
                        : null,
                    child: Text(_step == 4 ? 'شروع استفاده از روبی' : 'بعدی'),
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
        final height = MediaQuery.of(context).size.height;
        return Column(
          children: [
            SizedBox(height: height < 700 ? 8 : 18),
            SizedBox(
              height: height < 700 ? height * 0.42 : height * 0.50,
              child: Image.asset(
                'assets/images/ruby_fox_mascot.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.pets,
                  color: Colors.white,
                  size: 110,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'اسم شما چیه؟',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
              decoration: InputDecoration(
                hintText: 'نام شما',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Colors.white, width: 2),
                ),
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
            const SizedBox(height: 24),
            const Text(
              'شهر محل فعالیت',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'نام شهر را وارد کنید',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 28),
            TextFormField(
              initialValue: '',
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: 'شهر',
                hintText: 'مثلاً تهران',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _selectedCity = v,
            ),
          ],
        );

      case 4:
        return Column(
          children: [
            const Text(
              'نوع کسب‌وکار یا استفاده شما',
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

      default:
        return const SizedBox.shrink();
    }
  }
}
