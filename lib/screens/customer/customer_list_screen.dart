import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/jalali_helper.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../core/utils/thousand_separator_formatter.dart';
import '../../models/customer_model.dart';
import '../../providers/customer_provider.dart';

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({super.key});

  Future<void> _showCustomerForm(
    BuildContext context,
    WidgetRef ref, {
    CustomerModel? customer,
  }) async {
    final nameCtrl = TextEditingController(text: customer?.name ?? '');
    final mobileCtrl = TextEditingController(
      text: customer == null
          ? ''
          : (customer.mobile.isNotEmpty ? customer.mobile : customer.phone),
    );
    final addressCtrl = TextEditingController(text: customer?.address ?? '');
    final notesCtrl = TextEditingController(text: customer?.notes ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).viewPadding.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                customer == null ? 'افزودن مشتری' : 'ویرایش مشتری',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: nameCtrl,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'نام مشتری *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mobileCtrl,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'شماره مشتری',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'آدرس',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                textAlign: TextAlign.right,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'یادداشت',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('نام مشتری را وارد کنید')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.RubyPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    customer == null ? 'ذخیره مشتری' : 'ذخیره تغییرات',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved == true) {
      try {
        if (customer == null) {
          await ref.read(customerListProvider.notifier).addCustomer(
                CustomerModel(
                  id: 'customer-${DateTime.now().microsecondsSinceEpoch}',
                  name: nameCtrl.text.trim(),
                  mobile: mobileCtrl.text.trim(),
                  phone: '',
                  address: addressCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                  balance: 0,
                  createdAt: JalaliHelper.getTodayJalali(),
                ),
              );
        } else {
          await ref.read(customerListProvider.notifier).updateCustomer(
                CustomerModel(
                  id: customer.id,
                  name: nameCtrl.text.trim(),
                  mobile: mobileCtrl.text.trim(),
                  // فیلد شماره ثابت در این فرم نمایش داده نمی‌شود؛ مقدار قبلی
                  // باید برای کاربران نسخه‌های قدیمی بدون تغییر حفظ شود.
                  phone: customer.phone,
                  address: addressCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                  balance: customer.balance,
                  createdAt: customer.createdAt,
                ),
              );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ذخیره مشتری انجام نشد: $error')),
          );
        }
      }
    }

    // فیلدهای شیت تا پایان انیمیشن بسته‌شدن هنوز روی صفحه‌اند؛ dispose فوری
    // در حالت debug خطای «used after being disposed» می‌دهد.
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      nameCtrl.dispose();
      mobileCtrl.dispose();
      addressCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  Future<void> _showPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    CustomerModel customer,
  ) async {
    final ctrl = TextEditingController(
      text: ThousandSeparatorInputFormatter.formatDisplay(
        customer.balance.round().toString(),
        allowDecimal: false,
      ),
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ثبت دریافت از مشتری'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مانده بدهی: ${PersianNumberFormatter.formatCurrency(customer.balance)}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              inputFormatters: [ThousandSeparatorInputFormatter(allowDecimal: false)],
              decoration: const InputDecoration(
                labelText: 'مبلغ دریافتی',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              ThousandSeparatorInputFormatter.parseToDouble(ctrl.text),
            ),
            child: const Text('ثبت'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), ctrl.dispose);
    if (amount == null || amount <= 0) return;
    try {
      await ref.read(customerListProvider.notifier).recordPayment(customer.id, amount);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('دریافت ثبت شد و مانده‌حساب به‌روز شد')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ثبت دریافت انجام نشد: $error')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CustomerModel customer,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف مشتری'),
        content: Text('مشتری «${customer.name}» حذف شود؟ فاکتورهای قبلی او حذف نمی‌شوند.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(customerListProvider.notifier).deleteCustomer(customer.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حذف مشتری انجام نشد: $error')),
      );
    }
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    CustomerModel customer,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(
            customer.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (customer.balance > 0)
            ListTile(
              leading: const Icon(Icons.payments_outlined, color: Colors.green),
              title: const Text('ثبت دریافت'),
              onTap: () => Navigator.pop(ctx, 'pay'),
            ),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: AppTheme.RubyPrimary),
            title: const Text('ویرایش مشتری'),
            onTap: () => Navigator.pop(ctx, 'edit'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('حذف مشتری'),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'pay':
        await _showPaymentDialog(context, ref, customer);
      case 'edit':
        await _showCustomerForm(context, ref, customer: customer);
      case 'delete':
        await _confirmDelete(context, ref, customer);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت مشتریان'),
      ),
      body: customers.isEmpty
          ? const Center(child: Text('هنوز مشتری‌ای ثبت نشده است'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: customers.length,
              itemBuilder: (ctx, idx) {
                final c = customers[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: () => _showActions(context, ref, c),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.lightBlueBg,
                      child: Text(c.name.isNotEmpty ? c.name[0] : 'م'),
                    ),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(c.mobile.isNotEmpty ? c.mobile : c.phone),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          c.balance > 0 ? 'بدهکار' : 'تسویه',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: c.balance > 0 ? Colors.redAccent : Colors.green,
                          ),
                        ),
                        if (c.balance > 0)
                          Text(
                            PersianNumberFormatter.formatCurrency(c.balance),
                            style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomerForm(context, ref),
        backgroundColor: AppTheme.RubyPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('افزودن مشتری', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}
