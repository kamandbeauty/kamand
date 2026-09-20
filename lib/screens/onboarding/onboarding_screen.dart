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
  // کاربر درخواست کرده اسم و شهر پرسیده نشود - بنابراین فقط نوع کسب‌وکار را می‌پرسیم
  // این صفحه اکنون فقط برای کاربرانی که قبلاً نصب کرده‌اند و می‌خواهند تنظیمات را کامل کنند
  // نمایش داده می‌شود، ولی در اجرای اول مستقیم به داشبورد می‌رود (در splash_screen)
  String _selectedUsageType = 'store';

  void _finishOnboarding() {
    final currentUser = ref.read(userProvider);
    final updatedUser = UserModel(
      id: currentUser.id,
      name: currentUser.name.isEmpty ? 'کاربر' : currentUser.name,
      phone: currentUser.phone,
      country: currentUser.country.isEmpty ? 'ایران' : currentUser.country,
      province: currentUser.province,
      city: currentUser.city,
      usageType: _selectedUsageType,
      isOnboarded: true,
    );

    ref.read(userProvider.notifier).updateUser(updatedUser);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // اگر کاربر مستقیم به این صفحه آمد (مثلاً از تنظیمات)، فقط نوع کسب‌وکار را بپرس
    // بدون سوال اسم و شهر
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      // رد کردن آنبوردینگ - مستقیم به داشبورد
                      final currentUser = ref.read(userProvider);
                      ref.read(userProvider.notifier).updateUser(
                            currentUser.copyWith(isOnboarded: true, name: currentUser.name.isEmpty ? 'کاربر' : currentUser.name),
                          );
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const DashboardScreen()),
                      );
                    },
                    child: const Text('رد کردن', style: TextStyle(color: Colors.grey)),
                  ),
                  const Text(
                    'خوش آمدید',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Image.asset(
                      'assets/images/ruby_fox_mascot.png',
                      height: 180,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.pets,
                        color: AppTheme.primaryBlue,
                        size: 110,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'نوع کسب‌وکار شما',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'برای شخصی‌سازی بهتر، نوع فعالیت خود را انتخاب کنید',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
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
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _finishOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('شروع استفاده از روبی', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
