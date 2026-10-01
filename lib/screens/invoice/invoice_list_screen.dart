import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../core/utils/thousand_separator_formatter.dart';
import '../../models/invoice_model.dart';
import '../../providers/invoice_provider.dart';
import 'invoice_preview_screen.dart';
import '../dashboard/dashboard_screen.dart';

const _orange = AppTheme.RubyPrimary;
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _slate700 = Color(0xFF334155);
const _slate800 = Color(0xFF1E293B);

class InvoiceListScreen extends ConsumerWidget {
  const InvoiceListScreen({super.key});

  String _statusLabel(InvoiceModel inv) {
    if (inv.type == 'proforma') return 'پیش فاکتور';
    switch (inv.status) {
      case 'paid': return 'پرداخت شده';
      case 'unpaid': return 'پرداخت نشده';
      case 'partial': return 'پرداخت ناقص';
      case 'cancelled': return 'لغو شده';
      default: return inv.status;
    }
  }

  Color _statusColor(InvoiceModel inv) {
    if (inv.type == 'proforma') return const Color(0xFFD97706);
    switch (inv.status) {
      case 'paid': return const Color(0xFF059669);
      case 'partial': return const Color(0xFFD97706);
      default: return const Color(0xFFE11D48);
    }
  }

  void _showDetail(BuildContext context, WidgetRef ref, InvoiceModel inv) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoicePreviewScreen(invoice: inv)),
    );
  }

  Future<void> _copyInvoice(BuildContext context, WidgetRef ref, InvoiceModel inv) async {
    final copied = await ref.read(invoiceListProvider.notifier).copyInvoice(inv);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'فاکتور کپی شد؛ شماره ${PersianNumberFormatter.toPersian(copied.number)}',
        ),
      ),
    );
  }

  bool _canCollect(InvoiceModel inv) =>
      inv.type == 'sale' &&
      inv.paymentType != 'cash' &&
      inv.remainingAmount > 0;

  Future<void> _recordPayment(BuildContext context, WidgetRef ref, InvoiceModel inv) async {
    final ctrl = TextEditingController(
      text: ThousandSeparatorInputFormatter.formatDisplay(
        inv.remainingAmount.round().toString(),
        allowDecimal: false,
      ),
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ثبت دریافت'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'باقی‌مانده: ${PersianNumberFormatter.formatCurrency(inv.remainingAmount)}',
              style: const TextStyle(fontSize: 12, color: _slate500),
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
    // کنترلر تا پایان انیمیشن بسته‌شدن دیالوگ باید زنده بماند.
    Future<void>.delayed(const Duration(milliseconds: 400), ctrl.dispose);
    if (amount == null || amount <= 0) return;
    await ref.read(invoiceListProvider.notifier).recordPayment(inv.id, amount);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          amount > inv.remainingAmount
              ? 'دریافت تا سقف باقی‌مانده ثبت شد'
              : 'دریافت ثبت شد',
        ),
      ),
    );
  }

  Future<void> _convertProforma(
    BuildContext context,
    WidgetRef ref,
    InvoiceModel inv,
  ) async {
    final paymentType = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('نوع پرداخت فاکتور فروش'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('این پیش‌فاکتور به‌صورت نقدی یا غیرنقدی ثبت شود؟'),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('نقدی'),
              subtitle: const Text('فاکتور تسویه‌شده ثبت می‌شود'),
              onTap: () => Navigator.pop(dialogContext, 'cash'),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('غیرنقدی'),
              subtitle: const Text('مانده فاکتور در حساب مشتری ثبت می‌شود'),
              onTap: () => Navigator.pop(dialogContext, 'non_cash'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('انصراف'),
          ),
        ],
      ),
    );

    // بستن دیالوگ یا لمس «انصراف» نباید پیش‌فاکتور را تغییر دهد.
    if (paymentType == null || !context.mounted) return;

    try {
      await ref.read(invoiceListProvider.notifier).convertProformaToInvoice(
            inv.id,
            paymentType: paymentType,
          );
      if (!context.mounted) return;
      final paymentLabel = paymentType == 'cash' ? 'نقدی' : 'غیرنقدی';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'پیش‌فاکتور به فاکتور فروش $paymentLabel تبدیل شد',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تبدیل پیش‌فاکتور انجام نشد: $error')),
      );
    }
  }

  Future<void> _deleteInvoice(BuildContext context, WidgetRef ref, InvoiceModel inv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف فاکتور'),
        content: Text(
          'فاکتور شماره ${PersianNumberFormatter.toPersian(inv.number)} حذف شود؟',
        ),
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
    await ref.read(invoiceListProvider.notifier).deleteInvoice(inv.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('فاکتور حذف شد')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoiceListProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sorted = invoices.reversed.toList(); // جدیدترین اول
    return Scaffold(
      backgroundColor: dark? const Color(0xFF0F172A): const Color(0xFFFFFBEB),
      appBar: AppBar(
        backgroundColor: dark? _slate800: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: dark? Colors.white: _slate800),
        title: Text('لیست فاکتورها', style: TextStyle(color: dark? Colors.white: _slate800, fontWeight: FontWeight.w900, fontSize: 15)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: dark? _slate700: const Color(0xFFE2E8F0))),
      ),
      body: sorted.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.receipt_long, size: 48, color: _slate400),
              const SizedBox(height: 12),
              Text('هنوز فاکتوری ثبت نشده', style: TextStyle(color: _slate500, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('از هوم «ثبت فاکتور جدید» را بزنید', style: TextStyle(color: _slate400, fontSize: 12)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sorted.length,
              itemBuilder: (ctx, idx){
                final inv = sorted[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: dark ? _slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: dark ? _slate700 : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        onTap: () => _showDetail(context, ref, inv),
                        contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        title: Text(
                          inv.customerName.isEmpty ? 'مشتری عمومی' : inv.customerName,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: dark ? Colors.white : _slate800,
                          ),
                        ),
                        subtitle: Text(
                          'فاکتور #${PersianNumberFormatter.toPersian(inv.number)} • ${PersianNumberFormatter.toPersian(inv.date)} • ${PersianNumberFormatter.toPersian(inv.items.length)} قلم',
                          style: const TextStyle(fontSize: 11, color: _slate500),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              PersianNumberFormatter.formatCurrency(inv.totalAmount),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: dark ? Colors.white : _slate800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _statusColor(inv).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _statusLabel(inv),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: _statusColor(inv),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (inv.type == 'proforma' || _canCollect(inv))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Row(
                            children: [
                              if (inv.type == 'proforma')
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _convertProforma(context, ref, inv),
                                    icon: const Icon(Icons.swap_horiz, size: 17),
                                    label: const Text('تبدیل به فاکتور فروش'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF059669),
                                      minimumSize: const Size(0, 36),
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                      side: const BorderSide(color: Color(0x80059669)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              if (_canCollect(inv))
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _recordPayment(context, ref, inv),
                                    icon: const Icon(Icons.payments_outlined, size: 17),
                                    label: const Text('ثبت دریافت'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF059669),
                                      minimumSize: const Size(0, 36),
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                      side: const BorderSide(color: Color(0x80059669)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _copyInvoice(context, ref, inv),
                                icon: const Icon(Icons.copy_outlined, size: 17),
                                label: const Text('کپی فاکتور'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _orange,
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                  side: BorderSide(color: _orange.withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _deleteInvoice(context, ref, inv),
                                icon: const Icon(Icons.delete_outline, size: 17),
                                label: const Text('حذف فاکتور'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.45)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        ),
        backgroundColor: _orange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('فاکتور جدید', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ),
    );
  }
}
