import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../providers/customer_provider.dart';

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت مشتریان'),
      ),
      body: ListView.builder(
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
                      color: c.balance > 0 ? Colors.rose : Colors.emerald,
                    ),
                  ),
                  if (c.balance > 0)
                    Text(
                      PersianNumberFormatter.formatCurrency(c.balance),
                      style: const TextStyle(fontSize: 11, color: Colors.rose),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
