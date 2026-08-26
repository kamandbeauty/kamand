import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/customer_provider.dart';
import '../providers/store_providers.dart';
import '../store_core.dart';
import 'store_ui_helpers.dart';

/// مالی مشتریان (§5، §10، §11): بدهکاران، دریافت، برگشت وجه، سقف اعتبار
class CustomerFinanceScreen extends ConsumerStatefulWidget {
  const CustomerFinanceScreen({super.key});

  @override
  ConsumerState<CustomerFinanceScreen> createState() =>
      _CustomerFinanceScreenState();
}

class _CustomerFinanceScreenState extends ConsumerState<CustomerFinanceScreen> {
  bool _loading = true;
  List<Map<String, Object?>> _debtors = [];
  int _totalDebt = 0;

  Future<void> _reload(StoreCore core) async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    try {
      final rows = core.reports.debtors();
      var total = 0;
      for (final r in rows) {
        total += r['debt'] as int;
      }
      setState(() {
        _debtors = rows;
        _totalDebt = total;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      showStoreSnack(context, 'خطا: $e', error: true);
    }
  }

  String _displayName(String customerId) {
    final customers = ref.read(customerListProvider);
    for (final c in customers) {
      if (c.id == customerId) return c.name;
    }
    return 'مشتری $customerId';
  }

  Future<void> _openDetail(StoreCore core, Map<String, Object?> row) async {
    final customerId = row['customer_id'] as String;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (ctx, scrollController) => _CustomerFinanceSheet(
          core: core,
          customerId: customerId,
          name: _displayName(customerId),
          scrollController: scrollController,
        ),
      ),
    );
    await _reload(core);
  }

  @override
  Widget build(BuildContext context) {
    return StoreScaffold(
      title: 'مالی مشتریان',
      body: (core) {
        if (_loading) {
          _reload(core);
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: () => _reload(core),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              InfoCard(
                label: 'جمع دریافتنی از مشتریان',
                value: formatToman(_totalDebt),
                icon: Icons.group,
                color: AppTheme.RubyWarning,
              ),
              const SizedBox(height: 10),
              if (_debtors.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('هیچ مشتری بدهکاری وجود ندارد',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.RubyTextSecondary)),
                )
              else
                for (final d in _debtors)
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      onTap: () => _openDetail(core, d),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.RubyWarning.withOpacity(0.13),
                        child: const Icon(Icons.person,
                            color: AppTheme.RubyWarning, size: 22),
                      ),
                      title: Text(_displayName(d['customer_id'] as String),
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w900)),
                      subtitle: Text(
                          'آخرین تراکنش: ${faDate(d['last_date'] as String?)}',
                          style: const TextStyle(fontSize: 11)),
                      trailing: Text(
                        formatToman(d['debt'] as int),
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.RubyError),
                      ),
                    ),
                  ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}

class _CustomerFinanceSheet extends ConsumerStatefulWidget {
  final StoreCore core;
  final String customerId;
  final String name;
  final ScrollController scrollController;

  const _CustomerFinanceSheet({
    required this.core,
    required this.customerId,
    required this.name,
    required this.scrollController,
  });

  @override
  ConsumerState<_CustomerFinanceSheet> createState() =>
      _CustomerFinanceSheetState();
}

class _CustomerFinanceSheetState extends ConsumerState<_CustomerFinanceSheet> {
  Future<void> _action(Future<String?> Function() fn) async {
    try {
      await fn();
      if (mounted) {
        showStoreSnack(context, 'ثبت شد');
        setState(() {});
      }
      // همگام‌سازی نمایش مانده در لیست مشتریان قدیمی
      final derived = widget.core.bridge.derivedCustomerBalance(widget.customerId);
      ref.read(customerListProvider.notifier).setDerivedBalance(
            widget.customerId,
            derived.toDouble(),
          );
    } catch (e) {
      if (mounted) showStoreSnack(context, '$e', error: true);
    }
  }

  Future<void> _receive() async {
    final core = widget.core;
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
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('دریافت از ${widget.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              TomanField(controller: amount, label: 'مبلغ *'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: accountId,
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.typeLabel})')),
                ],
                onChanged: (v) => setSheet(() => accountId = v ?? accountId),
                decoration: const InputDecoration(labelText: 'به حساب'),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  final v = parseToman(amount.text);
                  if (v == null || v <= 0) {
                    showStoreSnack(ctx, 'مبلغ نامعتبر', error: true);
                    return;
                  }
                  Navigator.pop(ctx);
                  _action(() async => core.customerFinance.receivePayment(
                        customerId: widget.customerId,
                        amount: v,
                        date: DateTime.now().toIso8601String().substring(0, 10),
                        accountId: accountId,
                      ));
                },
                child: const Text('ثبت دریافت'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refund() async {
    final core = widget.core;
    final amount = TextEditingController();
    final reason = TextEditingController();
    final accounts = core.accounts.list(onlyActive: true);
    String accountId = accounts.isNotEmpty ? accounts.first.id : 'acc-cash';
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('برگشت وجه به ${widget.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              TomanField(controller: amount, label: 'مبلغ *'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: accountId,
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.typeLabel})')),
                ],
                onChanged: (v) => setSheet(() => accountId = v ?? accountId),
                decoration: const InputDecoration(labelText: 'از حساب'),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: reason,
                  decoration: const InputDecoration(labelText: 'علت')),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.RubyError),
                onPressed: () {
                  final v = parseToman(amount.text);
                  if (v == null || v <= 0) {
                    showStoreSnack(ctx, 'مبلغ نامعتبر', error: true);
                    return;
                  }
                  Navigator.pop(ctx);
                  _action(() async => core.customerFinance.refund(
                        customerId: widget.customerId,
                        amount: v,
                        date: DateTime.now().toIso8601String().substring(0, 10),
                        accountId: accountId,
                        reason: reason.text.trim(),
                      ));
                },
                child: const Text('ثبت برگشت وجه'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _charge(String kind) async {
    final core = widget.core;
    final amount = TextEditingController();
    var collectNow = true;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(kind == 'pack' ? 'دریافت بسته‌بندی از مشتری' : 'دریافت هزینهٔ ارسال از مشتری',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              TomanField(controller: amount, label: 'مبلغ *'),
              SwitchListTile(
                dense: true,
                value: collectNow,
                onChanged: (v) => setSheet(() => collectNow = v),
                title: const Text('همین حالا نقدی دریافت شد', style: TextStyle(fontSize: 12.5)),
                subtitle: const Text('خاموش = به بدهی مشتری اضافه می‌شود',
                    style: TextStyle(fontSize: 10.5)),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () {
                  final v = parseToman(amount.text);
                  if (v == null || v <= 0) {
                    showStoreSnack(ctx, 'مبلغ نامعتبر', error: true);
                    return;
                  }
                  Navigator.pop(ctx);
                  _action(() async => kind == 'pack'
                      ? core.customerFinance.packagingCharge(
                          customerId: widget.customerId,
                          amount: v,
                          date: DateTime.now().toIso8601String().substring(0, 10),
                          accountId: collectNow ? 'acc-cash' : null,
                        )
                      : core.customerFinance.shippingCharge(
                          customerId: widget.customerId,
                          amount: v,
                          date: DateTime.now().toIso8601String().substring(0, 10),
                          accountId: collectNow ? 'acc-cash' : null,
                        ));
                },
                child: const Text('ثبت'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _creditLimit() async {
    final core = widget.core;
    final ctrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('سقف اعتبار برای اقساط مستقیم فروشگاه',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            TomanField(controller: ctrl, label: 'سقف اعتبار (۰ = بدون سقف)'),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                final v = parseToman(ctrl.text) ?? 0;
                core.credit.setCreditLimit(widget.customerId, v);
                Navigator.pop(ctx);
                if (mounted) {
                  showStoreSnack(context, 'سقف اعتبار ذخیره شد');
                  setState(() {});
                }
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final core = widget.core;
    final summary = core.customerFinance.summary(widget.customerId);
    final statement = core.customerFinance.statement(widget.customerId, limit: 40);
    final limit = core.credit.creditLimit(widget.customerId);
    final usedStore = core.installments.outstandingStoreDebt(widget.customerId);
    final typeLabels = const {
      'SALE': 'فروش',
      'PAYMENT_RECEIVED': 'دریافت وجه',
      'REFUND': 'برگشت وجه',
      'SALE_RETURN': 'برگشت کالا',
      'INSTALLMENT_CREATED': 'فروش اقساطی',
      'INSTALLMENT_PAID': 'پرداخت قسط',
      'PACKAGING_CHARGE': 'دریافت بسته‌بندی',
      'SHIPPING_CHARGE': 'دریافت ارسال',
      'REVENUE_REVERSED': 'اصلاح درآمد',
    };
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Text(widget.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _row('ماندهٔ بدهی (مشتق از دفتر کل)', formatToman(summary.receivable),
                    color: AppTheme.RubyError),
                _row('جمع پرداخت‌ها', formatToman(summary.totalPaid)),
                _row('جمع برگشت وجه', formatToman(summary.totalRefunded)),
                _row('جمع برگشت کالا', formatToman(summary.totalReturned)),
                _row('خرید اقساطی', formatToman(summary.installmentPurchases)),
                _row('ماندهٔ اقساط', formatToman(summary.outstandingInstallments)),
                if (summary.overdueCount > 0)
                  _row('اقساط معوق',
                      '${summary.overdueCount} قسط — ${formatToman(summary.overdueAmount)}',
                      color: AppTheme.RubyError),
                if (limit > 0) ...[
                  const Divider(height: 16),
                  _row('سقف اعتبار', formatToman(limit)),
                  _row('استفاده‌شده (اقساط فروشگاه)', formatToman(usedStore)),
                  _row('اعتبار قابل استفاده', formatToman((limit - usedStore) < 0 ? 0 : limit - usedStore),
                      color: AppTheme.RubySuccess),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
                onPressed: _receive,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('دریافت')),
            OutlinedButton.icon(
                onPressed: _refund,
                icon: const Icon(Icons.upload, size: 18),
                label: const Text('برگشت وجه')),
            OutlinedButton.icon(
                onPressed: () => _charge('pack'),
                icon: const Icon(Icons.inventory_2, size: 18),
                label: const Text('بسته‌بندی')),
            OutlinedButton.icon(
                onPressed: () => _charge('ship'),
                icon: const Icon(Icons.local_shipping, size: 18),
                label: const Text('ارسال')),
            OutlinedButton.icon(
                onPressed: _creditLimit,
                icon: const Icon(Icons.speed, size: 18),
                label: const Text('سقف اعتبار')),
          ],
        ),
        const SectionHeader('صورت‌حساب'),
        for (final e in statement)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              typeLabels[e.eventType] ?? e.eventType,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${faDate(e.eventDate)}${e.description.isEmpty ? '' : ' · ${e.description}'}',
              style: const TextStyle(fontSize: 10.5),
            ),
            trailing: Text(
              e.customerDelta > 0
                  ? '+${formatToman(e.customerDelta)}'
                  : e.customerDelta < 0
                      ? '−${formatToman(-e.customerDelta)}'
                      : formatToman(e.amount),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: e.customerDelta > 0
                    ? AppTheme.RubyError
                    : e.customerDelta < 0
                        ? AppTheme.RubySuccess
                        : AppTheme.RubyTextSecondary,
              ),
            ),
          ),
        if (statement.isEmpty)
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('تراکنشی ثبت نشده است',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.RubyTextSecondary, fontSize: 12)),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _row(String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Text(k,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.RubyTextSecondary))),
            Text(v,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: color ?? AppTheme.RubyTextPrimary)),
          ],
        ),
      );
}
