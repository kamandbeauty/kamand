import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/service_config.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../../services/account_service.dart';
import '../../services/premium_billing_service.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _busy = false;

  Future<void> _run(Future<AccountSession> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final session = await action();
      await ref.read(userProvider.notifier).updateUser(session.user);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حساب کاربری با موفقیت به‌روزرسانی شد')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _phoneLogin() async {
    final phoneCtrl = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ورود با شماره موبایل'),
        content: TextField(
          controller: phoneCtrl,
          autofocus: true,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: 'شماره موبایل ایران',
            hintText: '09123456789',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, phoneCtrl.text.trim()),
            child: const Text('ارسال کد'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), phoneCtrl.dispose);
    if (phone == null || phone.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(accountServiceProvider).requestIranianOtp(phone);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (mounted) setState(() => _busy = false);
    if (!mounted) return;

    final codeCtrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('کد تایید ملی‌پیامک'),
        content: TextField(
          controller: codeCtrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLength: 8,
          decoration: const InputDecoration(
            labelText: 'کد پیامک‌شده',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, codeCtrl.text.trim()),
            child: const Text('تایید و ورود'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), codeCtrl.dispose);
    if (code == null || code.isEmpty) return;
    await _run(
      () => ref.read(accountServiceProvider).verifyIranianOtp(phone, code),
    );
  }

  Future<void> _signOut(UserModel user) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(accountServiceProvider).signOut();
      await ref.read(userProvider.notifier).updateUser(
            user.copyWith(
              email: '',
              authProvider: '',
              isPremium: false,
              premiumExpiresAt: '',
            ),
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final signedIn = user.authProvider.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('حساب کاربری و پریمیوم')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: user.hasActivePremium
                    ? const [Color(0xFF7C3AED), Color(0xFFF59E0B)]
                    : const [Color(0xFF1E293B), Color(0xFF475569)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFFFD166),
                  size: 48,
                ),
                const SizedBox(height: 10),
                Text(
                  user.hasActivePremium ? 'پریمیوم فعال است' : 'روبی پریمیوم',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user.hasActivePremium
                      ? (user.premiumExpiresAt.isEmpty
                          ? 'اشتراک شما فعال است'
                          : 'اعتبار تا ${user.premiumExpiresAt}')
                      : 'اولین امکان ویژه: صدور فاکتور رسمی',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!signedIn) ...[
            const Text(
              'برای خرید اشتراک ابتدا وارد شوید',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy || !ServiceConfig.hasGoogleAuth
                  ? null
                  : () => _run(
                        () => ref.read(accountServiceProvider).signInWithGoogle(),
                      ),
              icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
              label: const Text('ورود با حساب Google'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy || !ServiceConfig.hasAuthApi ? null : _phoneLogin,
              icon: const Icon(Icons.sms_outlined),
              label: const Text('ورود با شماره موبایل ایران'),
            ),
          ] else ...[
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(user.name.isEmpty ? 'کاربر روبی' : user.name),
                subtitle: Text(
                  user.email.isNotEmpty ? user.email : user.phone,
                  textDirection: TextDirection.ltr,
                ),
                trailing: TextButton(
                  onPressed: _busy ? null : () => _signOut(user),
                  child: const Text('خروج'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!user.hasActivePremium)
              FilledButton.icon(
                onPressed: _busy || !ServiceConfig.hasBazaarBilling
                    ? null
                    : () => _run(
                          () => ref
                              .read(premiumBillingServiceProvider)
                              .subscribe(),
                        ),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('خرید اشتراک با کافه‌بازار'),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy || !ServiceConfig.hasBazaarBilling
                  ? null
                  : () => _run(
                        () => ref
                            .read(premiumBillingServiceProvider)
                            .restoreSubscription(),
                      ),
              icon: const Icon(Icons.restore_rounded),
              label: const Text('بازیابی اشتراک بازار'),
            ),
          ],
          if (!ServiceConfig.hasAuthApi || !ServiceConfig.hasBazaarBilling) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Text(
                'سرویس حساب یا پرداخت هنوز برای این Build پیکربندی نشده است. '
                'پس از قرارگرفتن آدرس API، شناسه محصول و کلید عمومی بازار، '
                'دکمه‌های مربوط فعال می‌شوند.',
                style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
              ),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 18),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
