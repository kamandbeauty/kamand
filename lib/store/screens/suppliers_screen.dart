import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../store_core.dart';
import '../suppliers/supplier_repository.dart';
import '../providers/store_providers.dart';
import 'store_ui_helpers.dart';

/// مدیریت تأمین‌کنندگان (§6) + پرداخت + صورت‌حساب
class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  String _search = '';
  List<Map<String, Object?>> _rows = [];
  bool _loading = true;

  Future<void> _reload(StoreCore core) async {
    // خروج از فریم فعلی تا setState حین build صدا زده نشود
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    try {
      final suppliers = core.suppliers.list(search: _search);
      final report = core.reports.supplierReport();
      final payableBySupplier = <String, int>{};
      for (final r in report) {
        payableBySupplier[r['id'] as String] = r['payable'] as int? ?? 0;
      }
      if (!mounted) return;
      setState(() {
        _rows = [
          for (final s in suppliers)
            {
              'supplier': s,
              'payable': payableBySupplier[s.id] ?? core.suppliers.payable(s.id),
            }
        ];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showStoreSnack(context, 'خطا در بارگذاری: $e', error: true);
    }
  }

  Future<void> _showSupplierForm(StoreCore core, {dynamic edit}) async {
    final name = TextEditingController(text: edit?.name ?? '');
    final mobile = TextEditingController(text: edit?.mobile ?? '');
    final company = TextEditingController(text: edit?.company ?? '');
    final address = TextEditingController(text: edit?.address ?? '');
    final economicId = TextEditingController(text: edit?.economicId ?? '');
    final notes = TextEditingController(text: edit?.notes ?? '');
    final activeNotifier = ValueNotifier<bool>(edit?.isActive ?? true);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(edit == null ? 'افزودن تأمین‌کننده' : 'ویرایش تأمین‌کننده',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'نام *')),
              const SizedBox(height: 10),
              TextField(controller: mobile, decoration: const InputDecoration(labelText: 'موبایل')),
              const SizedBox(height: 10),
              TextField(controller: company, decoration: const InputDecoration(labelText: 'شرکت/برند')),
              const SizedBox(height: 10),
              TextField(controller: address, decoration: const InputDecoration(labelText: 'آدرس')),
              const SizedBox(height: 10),
              TextField(
                  controller: economicId,
                  decoration: const InputDecoration(labelText: 'شناسه ملی / کد اقتصادی')),
              const SizedBox(height: 10),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'یادداشت')),
              ValueListenableBuilder<bool>(
                valueListenable: activeNotifier,
                builder: (ctx, v, _) => SwitchListTile(
                  dense: true,
                  value: v,
                  onChanged: (nv) => activeNotifier.value = nv,
                  title: const Text('تأمین‌کنندهٔ فعال',
                      style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (name.text.trim().isEmpty) {
                    showStoreSnack(ctx, 'نام الزامی است', error: true);
                    return;
                  }
                  core.suppliers.save(
                    id: edit?.id,
                    name: name.text.trim(),
                    mobile: mobile.text.trim(),
                    company: company.text.trim(),
                    address: address.text.trim(),
                    economicId: economicId.text.trim(),
                    notes: notes.text.trim(),
                    isActive: activeNotifier.value,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('ذخیره'),
              ),
            ],
          ),
        ),
      ),
    );
    await _reload(core);
  }

  Future<void> _showPaySheet(StoreCore core, dynamic supplier, int payable) async {
    final amount = TextEditingController();
    final accounts = core.accounts.list(onlyActive: true);
    String accountId = accounts.isNotEmpty ? accounts.first.id : 'acc-cash';
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('پرداخت به ${supplier.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('بدهی فعلی: ${formatToman(payable)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.RubyError, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TomanField(controller: amount, label: 'مبلغ پرداخت'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: accountId,
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.typeLabel})')),
                ],
                onChanged: (v) => setSheet(() => accountId = v ?? accountId),
                decoration: const InputDecoration(labelText: 'از حساب'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final v = parseToman(amount.text);
                  if (v == null || v <= 0) {
                    showStoreSnack(ctx, 'مبلغ نامعتبر است', error: true);
                    return;
                  }
                  try {
                    core.suppliers.pay(
                      supplierId: supplier.id,
                      amount: v,
                      date: todayIso(),
                      accountId: accountId,
                    );
                    Navigator.pop(ctx);
                    showStoreSnack(ctx, 'پرداخت ثبت شد');
                  } catch (e) {
                    showStoreSnack(ctx, '$e', error: true);
                  }
                },
                child: const Text('ثبت پرداخت'),
              ),
            ],
          ),
        ),
      ),
    );
    await _reload(core);
  }

  Future<void> _openDetail(StoreCore core, dynamic supplier, int payable) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SupplierDetailScreen(core: core, supplierId: supplier.id),
      ),
    );
    await _reload(core);
  }

  @override
  Widget build(BuildContext context) {
    return StoreScaffold(
      title: 'تأمین‌کنندگان',
      fab: null,
      body: (context, core) {
        if (_loading) {
          _reload(core);
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) {
                        _search = v;
                        _reload(core);
                      },
                      decoration: const InputDecoration(
                        labelText: 'جست‌وجوی نام / موبایل / شرکت',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _showSupplierForm(core),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('جدید'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _rows.isEmpty
                  ? const Center(
                      child: Text('هنوز تأمین‌کننده‌ای ثبت نشده است',
                          style: TextStyle(color: AppTheme.RubyTextSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _rows.length,
                      itemBuilder: (_, i) {
                        final supplier = _rows[i]['supplier'] as Supplier;
                        final payable = _rows[i]['payable'] as int;
                        return Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            onTap: () => _openDetail(core, supplier, payable),
                            leading: CircleAvatar(
                              backgroundColor: (supplier.isActive
                                      ? AppTheme.RubyPrimary
                                      : Colors.grey)
                                  .withValues(alpha: 0.15),
                              child: Icon(Icons.local_shipping,
                                  color: supplier.isActive
                                      ? AppTheme.RubyPrimary
                                      : Colors.grey),
                            ),
                            title: Text(supplier.name,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                            subtitle: Text(
                              [
                                if (supplier.company.isNotEmpty) supplier.company,
                                if (supplier.mobile.isNotEmpty) supplier.mobile,
                              ].join(' · '),
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  payable > 0 ? 'بدهی: ${formatToman(payable)}' : 'تسویه',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: payable > 0 ? AppTheme.RubyError : AppTheme.RubySuccess,
                                  ),
                                ),
                                if (payable > 0)
                                  TextButton(
                                    onPressed: () => _showPaySheet(core, supplier, payable),
                                    child: const Text('پرداخت', style: TextStyle(fontSize: 11)),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SupplierDetailScreen extends StatefulWidget {
  final StoreCore core;
  final String supplierId;
  const _SupplierDetailScreen({required this.core, required this.supplierId});

  @override
  State<_SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<_SupplierDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final core = widget.core;
    final supplier = core.suppliers.byId(widget.supplierId);
    if (supplier == null) {
      return const Scaffold(body: Center(child: Text('تأمین‌کننده پیدا نشد')));
    }
    final payable = core.suppliers.payable(supplier.id);
    final purchases = core.purchases.list(supplierId: supplier.id);
    final statement = core.suppliers.statement(supplier.id, limit: 60);
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: Text(supplier.name)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('بدهی فعلی',
                          style: TextStyle(color: AppTheme.RubyTextSecondary, fontSize: 12)),
                      Text(
                        formatToman(payable),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: payable > 0 ? AppTheme.RubyError : AppTheme.RubySuccess,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    [
                      if (supplier.company.isNotEmpty) 'شرکت: ${supplier.company}',
                      if (supplier.mobile.isNotEmpty) 'موبایل: ${supplier.mobile}',
                      if (supplier.address.isNotEmpty) 'آدرس: ${supplier.address}',
                      if (supplier.economicId.isNotEmpty) 'شناسه: ${supplier.economicId}',
                    ].join('\n'),
                    style: const TextStyle(fontSize: 12, color: AppTheme.RubyTextSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader('فاکتورهای خرید'),
          if (purchases.isEmpty)
            const Text('خریدی ثبت نشده است',
                textAlign: TextAlign.center, style: TextStyle(color: AppTheme.RubyTextSecondary))
          else
            ...purchases.map((p) => Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    dense: true,
                    title: Text('خرید ${p.number.isEmpty ? p.id.substring(0, 12) : p.number}'),
                    subtitle: Text(
                        'جمع: ${formatToman(p.total)} · پرداخت: ${formatToman(p.paid)} · ${faDate(p.date)}'),
                    trailing: Text(
                      p.status == 'paid' ? 'تسویه' : 'مانده: ${formatToman(p.total - p.paid)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: p.status == 'paid' ? AppTheme.RubySuccess : AppTheme.RubyWarning,
                      ),
                    ),
                  ),
                )),
          const SectionHeader('صورت‌حساب مالی'),
          if (statement.isEmpty)
            const Text('رویدادی ثبت نشده است',
                textAlign: TextAlign.center, style: TextStyle(color: AppTheme.RubyTextSecondary))
          else
            ...statement.map((e) => Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    dense: true,
                    title: Text(e.description.isEmpty ? e.eventType : e.description,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    subtitle: Text(faDate(e.eventDate), style: const TextStyle(fontSize: 10.5)),
                    trailing: Text(
                      '${e.supplierDelta > 0 ? '+' : e.supplierDelta < 0 ? '−' : ''}${formatToman(e.supplierDelta.abs())}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: e.supplierDelta > 0
                            ? AppTheme.RubyError
                            : AppTheme.RubySuccess,
                      ),
                    ),
                  ),
                )),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
