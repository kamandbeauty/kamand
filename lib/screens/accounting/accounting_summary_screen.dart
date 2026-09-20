import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/product_provider.dart';

const _orange = AppTheme.RubyPrimary;
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _slate700 = Color(0xFF334155);
const _slate800 = Color(0xFF1E293B);

class AccountingSummaryScreen extends ConsumerWidget {
  const AccountingSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoiceListProvider);
    final expenses = ref.watch(expenseListProvider);
    final customers = ref.watch(customerListProvider);
    final suppliers = ref.watch(supplierListProvider);
    final products = ref.watch(productListProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    // محاسبات
    double totalSales = 0;
    double totalPurchases = 0;
    double totalProfit = 0;
    double totalBuy = 0;
    double totalReceivable = 0; // طلب از مشتری
    double totalPayable = 0; // بدهی به تامین کننده
    int saleCount = 0;
    int purchaseCount = 0;

    for (final inv in invoices) {
      if (inv.type == 'sale') {
        totalSales += inv.totalAmount;
        totalProfit += inv.profitAmount;
        totalBuy += inv.totalBuyAmount;
        totalReceivable += inv.remainingAmount;
        saleCount++;
      } else if (inv.type == 'purchase') {
        totalPurchases += inv.totalAmount;
        totalPayable += inv.remainingAmount;
        purchaseCount++;
      }
    }

    double totalExpenses = expenses.fold(0, (s, e) => s + e.amount);
    double customerDebts = customers.fold(0, (s, c) => s + c.balance);
    double supplierDebts = suppliers.fold(0, (s, sup) => s + sup.balance);
    double netProfit = totalProfit - totalExpenses;
    double inventoryValue = products.fold(0, (s, p) => s + (p.buyPrice * p.stock));

    // اگر بدهی مشتری در فاکتورها بیشتر از balance باشد، max را بگیر
    double totalReceivableAll = totalReceivable > customerDebts ? totalReceivable : customerDebts;
    double totalPayableAll = totalPayable > supplierDebts ? totalPayable : supplierDebts;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFFFFBEB),
      appBar: AppBar(
        title: const Text('خلاصه حساب و سود'),
        backgroundColor: dark ? _slate800 : Colors.white,
        foregroundColor: dark ? Colors.white : _slate800,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // کارت اصلی سود
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFF059669), const Color(0xFF047857)]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: const Color(0xFF059669).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('سود خالص', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                        child: Text('${PersianNumberFormatter.toPersian(saleCount.toString())} فروش', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(PersianNumberFormatter.formatCurrency(netProfit), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _miniStat('سود ناخالص', totalProfit, Colors.white70)),
                      Container(width: 1, height: 30, color: Colors.white24),
                      Expanded(child: _miniStat('هزینه‌ها', totalExpenses, Colors.white70, isNegative: true)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4 کارت ردیفی
            Row(
              children: [
                Expanded(child: _summaryCard(title: 'فروش کل', value: totalSales, icon: Icons.trending_up, color: const Color(0xFF2563EB), dark: dark)),
                const SizedBox(width: 10),
                Expanded(child: _summaryCard(title: 'خرید کل', value: totalPurchases, icon: Icons.shopping_cart_outlined, color: const Color(0xFFEA580C), dark: dark)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _summaryCard(title: 'طلب از مشتریان', value: totalReceivableAll, icon: Icons.account_balance_wallet_outlined, color: const Color(0xFF059669), dark: dark, subtitle: 'دریافتنی')),
                const SizedBox(width: 10),
                Expanded(child: _summaryCard(title: 'بدهی به تامین‌کننده', value: totalPayableAll, icon: Icons.payments_outlined, color: const Color(0xFFE11D48), dark: dark, subtitle: 'پرداختنی')),
              ],
            ),
            const SizedBox(height: 16),

            // جزئیات
            _sectionCard(
              dark: dark,
              title: 'جزئیات مالی',
              children: [
                _detailRow('تعداد فاکتور فروش', '${PersianNumberFormatter.toPersian(saleCount.toString())} فاکتور', dark),
                _detailRow('تعداد فاکتور خرید', '${PersianNumberFormatter.toPersian(purchaseCount.toString())} فاکتور', dark),
                _detailRow('مجموع خرید کالاها (بهای تمام شده)', PersianNumberFormatter.formatCurrency(totalBuy), dark),
                _detailRow('سود ناخالص از فروش', PersianNumberFormatter.formatCurrency(totalProfit), dark, valueColor: const Color(0xFF059669)),
                _detailRow('کل هزینه‌ها', PersianNumberFormatter.formatCurrency(totalExpenses), dark, valueColor: const Color(0xFFE11D48)),
                const Divider(height: 20),
                _detailRow('سود خالص (سود - هزینه)', PersianNumberFormatter.formatCurrency(netProfit), dark, isBold: true, valueColor: netProfit >= 0 ? const Color(0xFF059669) : const Color(0xFFE11D48)),
              ],
            ),
            const SizedBox(height: 12),

            _sectionCard(
              dark: dark,
              title: 'انبار و دارایی',
              children: [
                _detailRow('تعداد کالا', '${PersianNumberFormatter.toPersian(products.length.toString())} قلم', dark),
                _detailRow('ارزش موجودی انبار', PersianNumberFormatter.formatCurrency(inventoryValue), dark),
                _detailRow('تعداد مشتریان', '${PersianNumberFormatter.toPersian(customers.length.toString())} نفر', dark),
                _detailRow('تعداد تامین‌کنندگان', '${PersianNumberFormatter.toPersian(suppliers.length.toString())} نفر', dark),
              ],
            ),
            const SizedBox(height: 12),

            // دسته بندی هزینه
            if (expenses.isNotEmpty)
              _sectionCard(
                dark: dark,
                title: 'هزینه‌ها به تفکیک دسته',
                children: [
                  ..._expenseCategoryRows(expenses, dark),
                ],
              ),

            const SizedBox(height: 24),
            const Center(child: Text('محاسبات به صورت آفلاین و بر اساس فاکتورهای ثبت شده انجام می‌شود', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: _slate400))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, double value, Color labelColor, {bool isNegative = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 11)),
        const SizedBox(height: 2),
        Text('${isNegative ? "- " : ""}${PersianNumberFormatter.formatCurrency(value).replaceAll(' تومان', '')}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _summaryCard({required String title, required double value, required IconData icon, required Color color, required bool dark, String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: dark ? _slate800 : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: dark ? _slate700 : const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
              const Spacer(),
              if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 10, color: _slate400, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 11, color: _slate500, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(PersianNumberFormatter.formatCurrency(value).replaceAll(' تومان', ''), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: dark ? Colors.white : _slate800)),
          const SizedBox(height: 2),
          const Text('تومان', style: TextStyle(fontSize: 10, color: _slate400)),
        ],
      ),
    );
  }

  Widget _sectionCard({required bool dark, required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: dark ? _slate800 : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: dark ? _slate700 : const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: dark ? Colors.white : _slate800)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, bool dark, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: dark ? _slate400 : _slate500, fontWeight: isBold ? FontWeight.w800 : FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.w900 : FontWeight.w800, color: valueColor ?? (dark ? Colors.white : _slate800))),
        ],
      ),
    );
  }

  List<Widget> _expenseCategoryRows(List<dynamic> expenses, bool dark) {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map.entries.map((entry) {
      return _detailRow(entry.key, PersianNumberFormatter.formatCurrency(entry.value), dark, valueColor: const Color(0xFFE11D48));
    }).toList();
  }
}
