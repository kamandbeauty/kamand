import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/jalali_helper.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../models/customer_model.dart';
import '../../providers/customer_provider.dart';

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({super.key});

  Future<void> _showCustomerForm(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'افزودن مشتری',
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
                  child: const Text('ذخیره مشتری', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved == true) {
      ref.read(customerListProvider.notifier).addCustomer(
            CustomerModel(
              id: 'customer-${DateTime.now().millisecondsSinceEpoch}',
              name: nameCtrl.text.trim(),
              mobile: mobileCtrl.text.trim(),
              phone: '',
              address: addressCtrl.text.trim(),
              notes: notesCtrl.text.trim(),
              balance: 0,
              createdAt: JalaliHelper.getTodayJalali(),
            ),
          );
    }

    nameCtrl.dispose();
    mobileCtrl.dispose();
    addressCtrl.dispose();
    notesCtrl.dispose();
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
