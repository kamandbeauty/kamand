import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../models/invoice_model.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/supplier_provider.dart';

const _orange = AppTheme.RubyPrimary;
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _slate700 = Color(0xFF334155);
const _slate800 = Color(0xFF1E293B);

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(invoiceListProvider);
    final customers = ref.watch(customerListProvider);
    final suppliers = ref.watch(supplierListProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    // طلب‌ها: فاکتورهای فروش با remaining >0
    final receivables = invoices.where((inv) => inv.type == 'sale' && inv.remainingAmount > 0).toList();
    final totalReceivable = receivables.fold<double>(0, (s, inv) => s + inv.remainingAmount);
    final customerDebtTotal = customers.fold<double>(0, (s, c) => s + c.balance);

    // بدهی‌ها: فاکتورهای خرید با remaining >0
    final payables = invoices.where((inv) => inv.type == 'purchase' && inv.remainingAmount > 0).toList();
    final totalPayable = payables.fold<double>(0, (s, inv) => s + inv.remainingAmount);
    final supplierDebtTotal = suppliers.fold<double>(0, (s, sup) => s + sup.balance);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFFFFBEB),
      appBar: AppBar(
        title: const Text('بدهی و طلب‌ها'),
        backgroundColor: dark ? _slate800 : Colors.white,
        foregroundColor: dark ? Colors.white : _slate800,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _orange,
          unselectedLabelColor: _slate500,
          indicatorColor: _orange,
          tabs: [
            Tab(text: 'طلب‌ها (${PersianNumberFormatter.toPersian(receivables.length.toString())})'),
            Tab(text: 'بدهی‌ها (${PersianNumberFormatter.toPersian(payables.length.toString())})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // خلاصه بالا
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: dark ? _slate800 : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: dark ? _slate700 : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('کل طلب', style: TextStyle(fontSize: 11, color: _slate500)),
                      const SizedBox(height: 4),
                      Text(PersianNumberFormatter.formatCurrency(totalReceivable > customerDebtTotal ? totalReceivable : customerDebtTotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF059669))),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: dark ? _slate700 : const Color(0xFFE2E8F0)),
                Expanded(
                  child: Column(
                    children: [
                      const Text('کل بدهی', style: TextStyle(fontSize: 11, color: _slate500)),
                      const SizedBox(height: 4),
                      Text(PersianNumberFormatter.formatCurrency(totalPayable > supplierDebtTotal ? totalPayable : supplierDebtTotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFE11D48))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildReceivableTab(receivables, customers, dark),
                _buildPayableTab(payables, suppliers, dark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivableTab(List<InvoiceModel> receivables, List customers, bool dark) {
    if (receivables.isEmpty && customers.where((c) => c.balance > 0).isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle_outline, size: 48, color: _slate400), const SizedBox(height: 12), Text('طلبی وجود ندارد', style: TextStyle(color: _slate500, fontWeight: FontWeight.w700))]));
    }

    // ترکیب فاکتور و مشتری
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (customers.where((c) => c.balance > 0).isNotEmpty) ...[
          const Padding(padding: EdgeInsets.only(bottom: 8, right: 4), child: Text('مشتریان بدهکار', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
          ...customers.where((c) => c.balance > 0).map((c) => _customerDebtCard(c, dark)),
          const SizedBox(height: 16),
        ],
        const Padding(padding: EdgeInsets.only(bottom: 8, right: 4), child: Text('فاکتورهای تسویه نشده', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
        ...receivables.reversed.map((inv) => _invoiceDebtCard(inv, dark, isReceivable: true)),
      ],
    );
  }

  Widget _buildPayableTab(List<InvoiceModel> payables, List suppliers, bool dark) {
    if (payables.isEmpty && suppliers.where((s) => s.balance > 0).isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle_outline, size: 48, color: _slate400), const SizedBox(height: 12), Text('بدهی‌ای وجود ندارد', style: TextStyle(color: _slate500, fontWeight: FontWeight.w700))]));
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (suppliers.where((s) => s.balance > 0).isNotEmpty) ...[
          const Padding(padding: EdgeInsets.only(bottom: 8, right: 4), child: Text('تامین‌کنندگان طلبکار', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
          ...suppliers.where((s) => s.balance > 0).map((s) => _supplierDebtCard(s, dark)),
          const SizedBox(height: 16),
        ],
        const Padding(padding: EdgeInsets.only(bottom: 8, right: 4), child: Text('فاکتورهای خرید تسویه نشده', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
        ...payables.reversed.map((inv) => _invoiceDebtCard(inv, dark, isReceivable: false)),
      ],
    );
  }

  Widget _customerDebtCard(dynamic c, bool dark) {
    return Card(
      color: dark ? _slate800 : Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFDCFCE7), child: Text(c.name[0], style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w900))),
        title: Text(c.name, style: TextStyle(fontWeight: FontWeight.w800, color: dark ? Colors.white : _slate800)),
        subtitle: Text(c.mobile.isNotEmpty ? c.mobile : c.phone, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11, color: _slate500)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('طلب', style: TextStyle(fontSize: 10, color: _slate400)),
            Text(PersianNumberFormatter.formatCurrency(c.balance), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF059669))),
          ],
        ),
      ),
    );
  }

  Widget _supplierDebtCard(dynamic s, bool dark) {
    return Card(
      color: dark ? _slate800 : Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFFEE2E2), child: Text(s.name[0], style: const TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w900))),
        title: Text(s.name, style: TextStyle(fontWeight: FontWeight.w800, color: dark ? Colors.white : _slate800)),
        subtitle: Text(s.mobile.isNotEmpty ? s.mobile : s.phone, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11, color: _slate500)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('بدهی', style: TextStyle(fontSize: 10, color: _slate400)),
            Text(PersianNumberFormatter.formatCurrency(s.balance), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFFE11D48))),
          ],
        ),
      ),
    );
  }

  Widget _invoiceDebtCard(InvoiceModel inv, bool dark, {required bool isReceivable}) {
    return Card(
      color: dark ? _slate800 : Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('فاکتور #${PersianNumberFormatter.toPersian(inv.number)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: dark ? Colors.white : _slate800)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: (isReceivable ? const Color(0xFF059669) : const Color(0xFFE11D48)).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(isReceivable ? 'طلب' : 'بدهی', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isReceivable ? const Color(0xFF059669) : const Color(0xFFE11D48))),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(isReceivable ? inv.customerName : (inv.supplierName.isNotEmpty ? inv.supplierName : 'تامین‌کننده'), style: const TextStyle(fontSize: 12, color: _slate500)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('مانده: ${PersianNumberFormatter.formatCurrency(inv.remainingAmount)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: isReceivable ? const Color(0xFF059669) : const Color(0xFFE11D48))),
                Text(PersianNumberFormatter.toPersian(inv.date), style: const TextStyle(fontSize: 11, color: _slate400)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: inv.totalAmount > 0 ? (inv.paidAmount / inv.totalAmount).clamp(0, 1) : 0,
              backgroundColor: dark ? _slate700 : const Color(0xFFE2E8F0),
              color: isReceivable ? const Color(0xFF059669) : const Color(0xFFE11D48),
              minHeight: 4,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('پرداخت: ${PersianNumberFormatter.formatCurrency(inv.paidAmount)}', style: const TextStyle(fontSize: 10, color: _slate400)),
                Text('کل: ${PersianNumberFormatter.formatCurrency(inv.totalAmount)}', style: const TextStyle(fontSize: 10, color: _slate400)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
