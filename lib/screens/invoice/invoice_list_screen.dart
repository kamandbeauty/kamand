import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../models/invoice_model.dart';
import '../../providers/invoice_provider.dart';
import 'invoice_create_screen.dart';
import 'invoice_preview_screen.dart';

const _orange = AppTheme.RubyPrimary;
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _slate700 = Color(0xFF334155);
const _slate800 = Color(0xFF1E293B);

class InvoiceListScreen extends ConsumerWidget {
  const InvoiceListScreen({super.key});

  String _statusLabel(InvoiceModel inv) {
    if (inv.type == 'proforma') return 'پیش‌فاکتور';
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
                  decoration: BoxDecoration(color: dark? _slate800: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: dark? _slate700: const Color(0xFFE2E8F0))),
                  child: ListTile(
                    onTap: ()=> _showDetail(context, ref, inv),
                    title: Text(inv.customerName.isEmpty? 'مشتری عمومی': inv.customerName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: dark? Colors.white: _slate800)),
                    subtitle: Text('فاکتور #${PersianNumberFormatter.toPersian(inv.number)} • ${PersianNumberFormatter.toPersian(inv.date)} • ${PersianNumberFormatter.toPersian(inv.items.length)} قلم', style: TextStyle(fontSize: 11, color: _slate500)),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(PersianNumberFormatter.formatCurrency(inv.totalAmount), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: dark? Colors.white: _slate800)),
                      const SizedBox(height: 4),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _statusColor(inv).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)), child: Text(_statusLabel(inv), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _statusColor(inv)))),
                    ]),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const InvoiceCreateScreen())),
        backgroundColor: _orange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('فاکتور جدید', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ),
    );
  }
}
