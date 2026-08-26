import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../providers/store_providers.dart';
import '../store_core.dart';
import 'store_ui_helpers.dart';

/// گزارش‌ها (§31–§39): سود و زیان، فروش، جریان نقدی، سود کالا، بدهکاران…
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _index = 0;
  String _from = '';
  String _to = '';
  bool _loaded = false;

  static const _reports = [
    'سود و زیان',
    'فروش',
    'جریان نقدی',
    'پیش‌بینی نقدی',
    'سود کالا',
    'بدهکاران',
    'تأمین‌کنندگان',
    'هزینه‌ها',
    'اقساط (سیستم‌ها)',
    'موجودی انبار',
    'تطبیق مالی',
  ];

  void _ensureRange() {
    if (_to.isEmpty) {
      final now = DateTime.now();
      _to =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final start = DateTime(now.year, now.month, 1);
      _from =
          '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickRange() async {
    _ensureRange();
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
          start: DateTime.tryParse(_from) ?? now, end: DateTime.tryParse(_to) ?? now),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start.toIso8601String().substring(0, 10);
        _to = picked.end.toIso8601String().substring(0, 10);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureRange();
    return StoreScaffold(
      title: 'گزارش‌ها',
      actions: [
        TextButton(
          onPressed: _pickRange,
          child: Text(
            '${faDate(_from)} تا ${faDate(_to)}',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ],
      body: (context, core) {
        return Column(
          children: [
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                children: [
                  for (var i = 0; i < _reports.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(_reports[i], style: const TextStyle(fontSize: 11)),
                        selected: _index == i,
                        onSelected: (_) => setState(() {
                          _index = i;
                          _loaded = false;
                        }),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _body(core)),
          ],
        );
      },
    );
  }

  Widget _body(StoreCore core) {
    switch (_index) {
      case 0:
        return _profitLoss(core);
      case 1:
        return _sales(core);
      case 2:
        return _cashflow(core);
      case 3:
        return _forecast(core);
      case 4:
        return _productProfit(core);
      case 5:
        return _debtors(core);
      case 6:
        return _suppliers(core);
      case 7:
        return _expenses(core);
      case 8:
        return _providers(core);
      case 9:
        return _inventory(core);
      default:
        return _reconciliation(core);
    }
  }

  Widget _kv(String k, String v, {Color? color, bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: TextStyle(
                    fontSize: big ? 13 : 12.5, color: AppTheme.RubyTextSecondary)),
            Text(v,
                style: TextStyle(
                  fontSize: big ? 14 : 12.5,
                  fontWeight: FontWeight.w900,
                  color: color ?? AppTheme.RubyTextPrimary,
                )),
          ],
        ),
      );

  Widget _profitLoss(StoreCore core) {
    final pl = core.reports.profitAndLoss(_from, _to);
    return ListView(children: [
      const SectionHeader('درآمد'),
      _kv('فروش و دریافت‌های کالا', formatToman(pl.revenue)),
      _kv('برگشت از فروش', '−${formatToman(pl.returns)}', color: AppTheme.RubyError),
      _kv('درآمد خالص', formatToman(pl.netRevenue), big: true),
      const Divider(),
      _kv('بهای تمام‌شدهٔ کالای فروخته‌شده', '−${formatToman(pl.cogs)}'),
      _kv('سود ناخالص', formatToman(pl.grossProfit),
          color: AppTheme.RubySuccess, big: true),
      const Divider(),
      const SectionHeader('هزینه‌های عملیاتی'),
      _kv('کارمزد سیستم‌های اقساطی', '−${formatToman(pl.providerCommissions)}'),
      for (final e in pl.expensesByCategory.entries)
        _kv(e.key, '−${formatToman(e.value)}'),
      const Divider(),
      _kv('سود خالص', formatToman(pl.netProfit),
          color: pl.netProfit >= 0 ? AppTheme.RubySuccess : AppTheme.RubyError,
          big: true),
      const Divider(),
      const SectionHeader('جدا از سود — وضعیت نقدی'),
      _kv('وجه واقعاً دریافت‌شده', formatToman(pl.cashReceived)),
      _kv('وجه واقعاً پرداخت‌شده', formatToman(pl.cashPaidOut)),
      _kv('تسویهٔ در انتظار سیستم‌ها', formatToman(pl.outstandingProviderSettlement)),
      _kv('اقساط ماندهٔ مستقیم فروشگاه', formatToman(pl.outstandingStoreInstallments)),
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'سود = درآمد − بهای کالا − کارمزد − هزینه؛ هیچ‌جا با «نقد دریافتی» اشتباه نمی‌شود.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10.5, color: AppTheme.RubyTextSecondary),
        ),
      ),
    ]);
  }

  Widget _sales(StoreCore core) {
    final rows = core.reports.salesReport(_from, _to);
    if (rows.isEmpty) {
      return const _NoData('در این بازه فروشی ثبت نشده است');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final r = rows[i];
        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            dense: true,
            title: Text('بازه: ${faDate(r['period'] as String)}'),
            subtitle: Text(
              'فروش: ${formatToman(r['sales'] as int)} · ${r['cnt']} فاکتور · نقدی: ${formatToman(r['cash_in'] as int)} · نسیه: ${formatToman(r['credit'] as int)}',
              style: const TextStyle(fontSize: 10.5),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('سود ناخالص',
                    style: TextStyle(fontSize: 9.5, color: AppTheme.RubyTextSecondary)),
                Text(
                  formatToman(r['gross_profit'] as int),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.RubySuccess),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cashflow(StoreCore core) {
    final cf = core.reports.cashflow(_from, _to);
    return ListView(children: [
      const SectionHeader('جریان نقدی واقعی'),
      _kv('نقد آغازین', formatToman(cf['opening'] ?? 0)),
      _kv('ورودی نقدی', '+${formatToman(cf['incoming'] ?? 0)}',
          color: AppTheme.RubySuccess),
      _kv('خروجی نقدی', '−${formatToman(cf['outgoing'] ?? 0)}',
          color: AppTheme.RubyError),
      const Divider(),
      _kv('نقد پایانی', formatToman(cf['closing'] ?? 0), big: true),
    ]);
  }

  Widget _forecast(StoreCore core) {
    final rows = core.reports.forecastRows(_from, _to);
    final totals = core.reports.forecastTotals();
    return ListView(children: [
      const SectionHeader('پیش‌بینی جریان نقدی'),
      _kv('ورودی مورد انتظار', formatToman(totals['expectedIncoming'] ?? 0),
          color: AppTheme.RubySuccess, big: true),
      _kv('خروجی مورد انتظار (بدهی تأمین‌کنندگان)', formatToman(totals['expectedOutgoing'] ?? 0),
          color: AppTheme.RubyError, big: true),
      _kv('خالص مورد انتظار', formatToman(totals['expectedNet'] ?? 0), big: true),
      const Divider(),
      for (final r in rows)
        ListTile(
          dense: true,
          title: Text(r['kind'] as String,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
          subtitle: Text(
            '${faDate(r['d'] as String)} · ${r['customer_name'] ?? ''} ${r['provider_name'] ?? ''}',
            style: const TextStyle(fontSize: 10.5),
          ),
          trailing: Text(
            '+${formatToman(((r['amount'] as num?) ?? 0).toInt())}',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.RubySuccess),
          ),
        ),
      if (rows.isEmpty) const _NoData('در این بازه جریان مورد انتظاری نیست'),
    ]);
  }

  Widget _productProfit(StoreCore core) {
    final rows = core.reports.productProfit(_from, _to);
    if (rows.isEmpty) return const _NoData('در این بازه فروش کالایی ثبت نشده است');
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final r = rows[i];
        final revenue = ((r['revenue'] as num?) ?? 0).toInt();
        final cost = ((r['cost'] as num?) ?? 0).toInt();
        final gross = ((r['gross_profit'] as num?) ?? 0).toInt();
        final margin = core.reports.marginBps(revenue, cost);
        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            dense: true,
            title: Text(r['title'] as String,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            subtitle: Text(
              'فروش: ${formatToman(revenue)} · بهای کالا: ${formatToman(cost)} · برگشتی: ${((r['returned_units'] as num?) ?? 0).toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 10.5),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(formatToman(gross),
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: gross >= 0 ? AppTheme.RubySuccess : AppTheme.RubyError)),
                Text(
                  'حاشیه: ${(margin / 100).toStringAsFixed(1)}٪',
                  style: const TextStyle(fontSize: 10, color: AppTheme.RubyTextSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _debtors(StoreCore core) {
    final rows = core.reports.debtors();
    if (rows.isEmpty) return const _NoData('هیچ مشتری بدهکار نیست');
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final r = rows[i];
        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            dense: true,
            title: Text('شناسهٔ مشتری: ${r['customer_id']}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
            subtitle: Text('آخرین تراکنش: ${faDate(r['last_date'] as String?)}',
                style: const TextStyle(fontSize: 10.5)),
            trailing: Text(
              formatToman(r['debt'] as int),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.RubyError),
            ),
          ),
        );
      },
    );
  }

  Widget _suppliers(StoreCore core) {
    final rows = core.reports.supplierReport();
    if (rows.isEmpty) return const _NoData('تأمین‌کننده‌ای ثبت نشده است');
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final r = rows[i];
        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            dense: true,
            title: Text(r['name'] as String,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            subtitle: Text(
              'خرید: ${formatToman(r['purchases'] as int)} · پرداخت: ${formatToman(r['payments'] as int)}',
              style: const TextStyle(fontSize: 10.5),
            ),
            trailing: Text(
              'بدهی: ${formatToman(r['payable'] as int)}',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.RubyError),
            ),
          ),
        );
      },
    );
  }

  Widget _expenses(StoreCore core) {
    final rows = core.expenses.totalsByCategory(from: _from, to: _to);
    final monthly = core.expenses.monthlyTotals();
    if (rows.isEmpty && monthly.isEmpty) return const _NoData('هزینه‌ای ثبت نشده است');
    return ListView(children: [
      const SectionHeader('به تفکیک دسته (بازهٔ انتخابی)'),
      for (final r in rows)
        _kv('${r['cat_title']} (${r['cnt']} مورد)', formatToman(r['total'] as int),
            color: AppTheme.RubyError),
      const Divider(),
      const SectionHeader('ماهانه'),
      for (final m in monthly)
        _kv(m['ym'] as String, formatToman(m['total'] as int)),
      // مقایسهٔ بسته‌بندی (§43): هزینهٔ عمده در برابر دریافت از مشتری
      const Divider(),
      const SectionHeader('بسته‌بندی و ارسال'),
      _kv('هزینهٔ بسته‌بندی (خرید عمده)',
          formatToman(core.reports.sumLedgerSigned(const {'PACKAGING_EXPENSE'}, from: _from, to: _to)),
          color: AppTheme.RubyError),
      _kv('دریافت بسته‌بندی از مشتری',
          formatToman(core.reports.sumLedgerSigned(const {'PACKAGING_CHARGE'}, from: _from, to: _to)),
          color: AppTheme.RubySuccess),
      _kv('هزینهٔ ارسال فروشگاه',
          formatToman(core.reports.sumLedgerSigned(const {'SHIPPING_EXPENSE'}, from: _from, to: _to)),
          color: AppTheme.RubyError),
      _kv('دریافت ارسال از مشتری',
          formatToman(core.reports.sumLedgerSigned(const {'SHIPPING_CHARGE'}, from: _from, to: _to)),
          color: AppTheme.RubySuccess),
    ]);
  }

  Widget _providers(StoreCore core) {
    final rows = core.installments.providerReport(from: _from, to: _to);
    return ListView(children: [
      for (final r in rows)
        Card(
          color: Colors.white,
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['name'] as String,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  'تعداد فروش: ${r['sales_count']} · جمع فروش: ${formatToman(r['gross_total'] as int)} · تأمین‌شده: ${formatToman(r['financed_total'] as int)}',
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  'کارمزد: ${formatToman(r['commission_total'] as int)}${((r['commission_vat_total'] as int) > 0) ? ' (+مالیات ${formatToman(r['commission_vat_total'] as int)})' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.RubyError),
                ),
                Text(
                  'انتظار تسویه: ${formatToman(r['expected_settlement'] as int)} · تسویه‌شده: ${formatToman(r['settled_total'] as int)}',
                  style: const TextStyle(fontSize: 11, color: Colors.indigo),
                ),
                Text(
                  'طلب تسویه‌نشده: ${formatToman(r['outstanding_settlement'] as int)}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.RubyError,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      if (rows.isEmpty) const _NoData('سیستم اقساطی فعال نیست'),
    ]);
  }

  Widget _inventory(StoreCore core) {
    final rows = core.reports.inventoryReport();
    if (rows.isEmpty) return const _NoData('کالایی در انبار ثبت نشده است');
    return ListView(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: InfoCard(
          label: 'ارزش کل موجودی (بهای میانگین)',
          value: formatToman(core.inventory.valuation()),
          icon: Icons.warehouse,
          color: Colors.teal,
        ),
      ),
      for (final r in rows)
        Card(
          color: Colors.white,
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            dense: true,
            title: Text('کد: ${r['product_id']}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            subtitle: Text(
              'موجودی: ${(r['current_qty'] as num).toStringAsFixed(1)} · حداقل: ${(r['min_qty'] as num).toStringAsFixed(0)} · خرید: ${(r['purchased_total'] as num).toStringAsFixed(0)} · فروش: ${(r['sold_total'] as num).toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 10.5),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatToman(((r['stock_value'] as num?) ?? 0).toInt()),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                ),
                IconButton(
                  icon: const Icon(Icons.flag_outlined,
                      size: 18, color: AppTheme.RubyWarning),
                  tooltip: 'تعیین حداقل موجودی (هشدار کمبود)',
                  onPressed: () async {
                    final ctrl = TextEditingController(
                        text: ((r['min_qty'] as num?) ?? 0).toStringAsFixed(0));
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('حداقل موجودی برای هشدار کمبود',
                            style: TextStyle(fontSize: 15)),
                        content: TextField(
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'تعداد حداقل'),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('انصراف')),
                          FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('ذخیره')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      final v = double.tryParse(
                              ctrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                          0;
                      core.inventory.setMinQty(r['product_id'] as String, v);
                      showStoreSnack(context, 'حداقل موجودی ذخیره شد');
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _reconciliation(StoreCore core) {
    final checks = core.reports.reconciliationChecks();
    return ListView(children: [
      const SectionHeader('بررسی‌های سازگاری مالی (§51)'),
      for (final c in checks)
        Card(
          color: Colors.white,
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            dense: true,
            leading: Icon(
              c['ok'] == true ? Icons.check_circle : Icons.error,
              color: c['ok'] == true ? AppTheme.RubySuccess : AppTheme.RubyError,
            ),
            title: Text(c['name'] as String,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
            subtitle: (c['detail'] as String).isEmpty
                ? null
                : Text(c['detail'] as String,
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.RubyError)),
          ),
        ),
    ]);
  }
}

class _NoData extends StatelessWidget {
  final String text;
  const _NoData(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.RubyTextSecondary, fontSize: 12.5)),
      ),
    );
  }
}
