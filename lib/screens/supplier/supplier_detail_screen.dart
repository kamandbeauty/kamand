import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../models/supplier_model.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/expense_provider.dart';

const _orange = AppTheme.RubyPrimary;
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _slate700 = Color(0xFF334155);
const _slate800 = Color(0xFF1E293B);

class SupplierDetailScreen extends ConsumerWidget {
  final SupplierModel supplier;
  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoiceListProvider);
    final expenses = ref.watch(expenseListProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    // فاکتورهای خرید این تامین‌کننده
    final supInvoices = invoices.where((inv) => 
      inv.type == 'purchase' && 
      (inv.supplierId == supplier.id || inv.supplierName == supplier.name)
    ).toList();

    // محاسبات
    double totalPurchases = 0;
    double totalPaid = 0;
    double totalRemaining = 0;
    int purchaseCount = 0;

    for (final inv in supInvoices) {
      totalPurchases += inv.totalAmount;
      totalPaid += inv.paidAmount;
      totalRemaining += inv.remainingAmount;
      purchaseCount++;
    }

    // هزینه‌های مرتبط (اگر توضیحات شامل نام تامین‌کننده باشد)
    final relatedExpenses = expenses.where((exp) => 
      exp.notes.contains(supplier.name) || exp.title.contains(supplier.name)
    ).toList();
    double totalRelatedExpenses = relatedExpenses.fold(0, (s, e) => s + e.amount);

    // موجودی واقعی = بدهی از فاکتورها یا از balance تامین‌کننده
    double actualBalance = supplier.balance;
    if (totalRemaining > actualBalance) {
      actualBalance = totalRemaining;
    }

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFFFFBEB),
      appBar: AppBar(
        title: Text('کارت حساب ${supplier.name}'),
        backgroundColor: dark ? _slate800 : Colors.white,
        foregroundColor: dark ? Colors.white : _slate800,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // کارت اصلی تامین‌کننده
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFFEA580C), const Color(0xFFC2410C)]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: const Color(0xFFEA580C).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(supplier.name.isEmpty ? 'ت' : supplier.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(supplier.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                            if (supplier.mobile.isNotEmpty || supplier.phone.isNotEmpty)
                              Text(supplier.mobile.isNotEmpty ? supplier.mobile : supplier.phone, 
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                textDirection: TextDirection.ltr,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('مانده بدهی', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(PersianNumberFormatter.formatCurrency(actualBalance), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _miniStat('تعداد خرید', '$purchaseCount فاکتور', Colors.white70)),
                      Container(width: 1, height: 30, color: Colors.white24),
                      Expanded(child: _miniStat('کل خرید', PersianNumberFormatter.formatCurrency(totalPurchases).replaceAll(' تومان', ''), Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3 کارت خلاصه
            Row(
              children: [
                Expanded(child: _summaryCard(title: 'خرید کل', value: totalPurchases, icon: Icons.shopping_cart, color: const Color(0xFFEA580C), dark: dark)),
                const SizedBox(width: 8),
                Expanded(child: _summaryCard(title: 'پرداخت شده', value: totalPaid, icon: Icons.check_circle, color: const Color(0xFF059669), dark: dark)),
                const SizedBox(width: 8),
                Expanded(child: _summaryCard(title: 'مانده', value: totalRemaining, icon: Icons.pending, color: const Color(0xFFE11D48), dark: dark)),
              ],
            ),
            const SizedBox(height: 16),

            // اطلاعات تماس
            _sectionCard(
              dark: dark,
              title: 'اطلاعات تامین‌کننده',
              children: [
                if (supplier.mobile.isNotEmpty) _detailRow('موبایل', supplier.mobile, dark, isLtr: true),
                if (supplier.phone.isNotEmpty) _detailRow('تلفن', supplier.phone, dark, isLtr: true),
                if (supplier.address.isNotEmpty) _detailRow('آدرس', supplier.address, dark),
                if (supplier.notes.isNotEmpty) _detailRow('یادداشت', supplier.notes, dark),
                _detailRow('تاریخ ثبت', supplier.createdAt, dark),
              ],
            ),
            const SizedBox(height: 12),

            // لیست فاکتورهای خرید
            _sectionCard(
              dark: dark,
              title: 'فاکتورهای خرید (${PersianNumberFormatter.toPersian(purchaseCount.toString())})',
              children: [
                if (supInvoices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: Text('فاکتوری ثبت نشده', style: TextStyle(color: _slate400, fontSize: 12))),
                  )
                else
                  ...supInvoices.map((inv) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: dark ? _slate700 : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('فاکتور #${PersianNumberFormatter.toPersian(inv.number)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: dark ? Colors.white : _slate800)),
                              Text(PersianNumberFormatter.formatCurrency(inv.totalAmount), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: _orange)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(inv.date, style: TextStyle(fontSize: 11, color: _slate400)),
                              Text('مانده: ${PersianNumberFormatter.formatCurrency(inv.remainingAmount)}', 
                                style: TextStyle(fontSize: 11, color: inv.remainingAmount > 0 ? const Color(0xFFE11D48) : const Color(0xFF059669), fontWeight: FontWeight.w700)),
                            ],
                          ),
                          if (inv.items.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('${inv.items.length} قلم کالا', style: TextStyle(fontSize: 10, color: _slate500)),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
            const SizedBox(height: 12),

            // هزینه‌های مرتبط
            if (relatedExpenses.isNotEmpty)
              _sectionCard(
                dark: dark,
                title: 'هزینه‌های مرتبط',
                children: [
                  _detailRow('تعداد هزینه', '${PersianNumberFormatter.toPersian(relatedExpenses.length.toString())} مورد', dark),
                  _detailRow('مجموع هزینه‌های مرتبط', PersianNumberFormatter.formatCurrency(totalRelatedExpenses), dark, valueColor: const Color(0xFFE11D48)),
                  const SizedBox(height: 8),
                  ...relatedExpenses.take(5).map((exp) => 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(exp.title, style: TextStyle(fontSize: 11, color: dark ? _slate400 : _slate500)),
                          Text(PersianNumberFormatter.formatCurrency(exp.amount), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: dark ? Colors.white : _slate700)),
                        ],
                      ),
                    )
                  ).toList(),
                ],
              ),

            const SizedBox(height: 12),

            // خلاصه حساب
            _sectionCard(
              dark: dark,
              title: 'خلاصه حساب',
              children: [
                _detailRow('جمع کل خریدها', PersianNumberFormatter.formatCurrency(totalPurchases), dark),
                _detailRow('جمع پرداخت شده', PersianNumberFormatter.formatCurrency(totalPaid), dark, valueColor: const Color(0xFF059669)),
                _detailRow('هزینه‌های مرتبط', PersianNumberFormatter.formatCurrency(totalRelatedExpenses), dark, valueColor: const Color(0xFFE11D48)),
                const Divider(height: 16),
                _detailRow('مانده قابل پرداخت', PersianNumberFormatter.formatCurrency(actualBalance), dark, isBold: true, valueColor: actualBalance > 0 ? const Color(0xFFE11D48) : const Color(0xFF059669)),
                _detailRow('وضعیت', actualBalance > 0 ? 'بدهکار' : 'تسویه شده', dark, isBold: true, valueColor: actualBalance > 0 ? const Color(0xFFE11D48) : const Color(0xFF059669)),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _summaryCard({required String title, required double value, required IconData icon, required Color color, required bool dark}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: dark ? _slate800 : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: dark ? _slate700 : const Color(0xFFE2E8F0))),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 10, color: _slate500, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(PersianNumberFormatter.formatCurrency(value).replaceAll(' تومان', ''), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: dark ? Colors.white : _slate800), textAlign: TextAlign.center),
          const Text('تومان', style: TextStyle(fontSize: 9, color: _slate400)),
        ],
      ),
    );
  }

  Widget _sectionCard({required bool dark, required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: dark ? _slate800 : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: dark ? _slate700 : const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: dark ? Colors.white : _slate800)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, bool dark, {Color? valueColor, bool isBold = false, bool isLtr = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: dark ? _slate400 : _slate500, fontWeight: isBold ? FontWeight.w800 : FontWeight.w500)),
          Flexible(
            child: Text(value, 
              style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.w900 : FontWeight.w700, color: valueColor ?? (dark ? Colors.white : _slate800)),
              textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}
