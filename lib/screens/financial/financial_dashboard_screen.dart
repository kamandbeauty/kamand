import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../providers/financial_provider.dart';

class FinancialDashboardScreen extends ConsumerWidget {
  const FinancialDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(financialListProvider);

    final totalIncome = records.where((r) => r.isIncome).fold<double>(0, (sum, r) => sum + r.amount);
    final totalExpense = records.where((r) => !r.isIncome).fold<double>(0, (sum, r) => sum + r.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('گزارشات مالی و سود'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              color: AppTheme.primaryBlue,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text('خلاصه وضعیت مالی', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('کل درآمد', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              PersianNumberFormatter.formatCurrency(totalIncome),
                              style: const TextStyle(color: Colors.emeraldAccent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('کل هزینه', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              PersianNumberFormatter.formatCurrency(totalExpense),
                              style: const TextStyle(color: Colors.roseAccent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              itemBuilder: (ctx, idx) {
                final r = records[idx];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      r.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                      color: r.isIncome ? Colors.emerald : Colors.rose,
                    ),
                    title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${r.category} • ${r.date}'),
                    trailing: Text(
                      PersianNumberFormatter.formatCurrency(r.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: r.isIncome ? Colors.emerald : Colors.rose,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
