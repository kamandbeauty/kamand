import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/persian_number_formatter.dart';
import '../../../models/customer_model.dart';
import '../../../providers/customer_provider.dart';
import '../../core/money.dart';
import '../../installments/installment_repository.dart';
import '../../providers/store_providers.dart';
import '../../store_core.dart';
import '../store_ui_helpers.dart';

/// فروش اقساطی (§13، §14) — با نمایش شفاف کارمزد/مالیات/تسویهٔ خالص (§19)
class InstallmentSaleScreen extends ConsumerStatefulWidget {
  const InstallmentSaleScreen({super.key});

  @override
  ConsumerState<InstallmentSaleScreen> createState() =>
      _InstallmentSaleScreenState();
}

class _InstallmentSaleScreenState extends ConsumerState<InstallmentSaleScreen> {
  bool _loading = true;
  List<InstallmentSaleEntity> _sales = [];

  Future<void> _reload(StoreCore core) async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    try {
      core.installments.refreshStatuses();
      setState(() {
        _sales = core.installments.sales();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      showStoreSnack(context, 'خطا: $e', error: true);
    }
  }

  Future<void> _openCreate(StoreCore core) async {
    final providers = core.installments.providers(onlyEnabled: true);
    if (providers.isEmpty) {
      showStoreSnack(context, 'اول یک سیستم اقساطی فعال کنید', error: true);
      return;
    }
    final customers = ref.read(customerListProvider);
    final gross = TextEditingController();
    final down = TextEditingController();
    final count = TextEditingController();
    final firstPct = TextEditingController();
    final subCount = TextEditingController();
    final invoiceNo = TextEditingController();
    final notes = TextEditingController();
    var providerId = providers.first.id;
    String? customerId = customers.isNotEmpty ? customers.first.id : null;
    var overrideLimit = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final prov = core.installments.providerById(providerId);
          final grossV = parseToman(gross.text) ?? 0;
          final downV = parseToman(down.text) ?? 0;
          final financed = grossV - downV > 0 ? grossV - downV : 0;
          CommissionBreakdown? breakdown;
          if (prov != null && !prov.isStore && financed > 0) {
            breakdown = CommissionCalculator.calculate(
              grossFinanced: financed,
              commissionBps: prov.commissionBps,
              commissionFixed: prov.commissionFixed,
              commissionVatBps: prov.commissionVatBps,
              otherDeductions: prov.otherDeductions,
            );
          }
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('فروش اقساطی جدید',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: providerId,
                    items: [
                      for (final p in providers)
                        DropdownMenuItem(
                            value: p.id,
                            child: Text(
                                '${p.name}${p.isStore ? ' (مستقیم فروشگاه)' : ''}')),
                    ],
                    onChanged: (v) =>
                        setSheet(() => providerId = v ?? providerId),
                    decoration: const InputDecoration(labelText: 'سیستم اقساطی *'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: customerId,
                    items: [
                      for (final c in customers)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                      if (customers.isEmpty)
                        const DropdownMenuItem(value: '', child: Text('مشتری متفرقه')),
                    ],
                    onChanged: (v) => setSheet(() => customerId = v),
                    decoration: const InputDecoration(labelText: 'مشتری *'),
                  ),
                  const SizedBox(height: 10),
                  TomanField(controller: gross, label: 'مبلغ کل فروش *'),
                  const SizedBox(height: 10),
                  TomanField(controller: down, label: 'بیعانهٔ نقدی (اختیاری)'),
                  const SizedBox(height: 10),
                  TextField(
                      controller: count,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'تعداد اقساط (خالی = پیش‌فرض درگاه)')),
                  // باسلام: درصد قسط اول + تعداد اقساط بعدی (انتخاب همان لحظهٔ فروش)
                  if (prov != null &&
                      prov.scheduleType == ScheduleType.basalam) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: firstPct,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'درصد قسط اول',
                        suffixText: '٪',
                        hintText:
                            'پیش‌فرض درگاه: ${prov.firstPercentBps / 100}٪',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: subCount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'تعداد اقساط بعد از قسط اول',
                        hintText: 'پیش‌فرض درگاه: ${prov.subsequentCount}',
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                      controller: invoiceNo,
                      decoration: const InputDecoration(
                          labelText: 'شماره فاکتور مرتبط (اختیاری)')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: notes,
                      decoration: const InputDecoration(labelText: 'یادداشت')),
                  if (prov != null && prov.isStore)
                    CheckboxListTile(
                      dense: true,
                      value: overrideLimit,
                      onChanged: (v) =>
                          setSheet(() => overrideLimit = v ?? false),
                      title: const Text(
                          'عبور از سقف اعتبار مشتری (اقساط مستقیم فروشگاه)',
                          style: TextStyle(fontSize: 12)),
                    ),
                  if (financed > 0 && breakdown != null) ...[
                    const SizedBox(height: 8),
                    _BreakdownCard(breakdown: breakdown!),
                  ],
                  if (prov != null && prov.isStore && financed > 0)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'اقساط مستقیم فروشگاه: $financed تومان به بدهی مشتری می‌افزاید و مشمول سقف اعتبار است.',
                        style: const TextStyle(
                            fontSize: 10.5, color: AppTheme.RubyTextSecondary),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      final g = parseToman(gross.text) ?? 0;
                      final d = parseToman(down.text) ?? 0;
                      if (g <= 0 || d >= g) {
                        showStoreSnack(ctx, 'مبلغ‌ها را بررسی کنید', error: true);
                        return;
                      }
                      try {
                        final provNow =
                            core.installments.providerById(providerId);
                        final fPctText = firstPct.text.trim();
                        final subText = subCount.text.trim();
                        core.installments.createSale(
                          providerId: providerId,
                          customerId: customerId ?? 'guest',
                          customerName: customers
                                  .cast<CustomerModel?>()
                                  .firstWhere((c) => c?.id == customerId,
                                      orElse: () => null)
                                  ?.name ??
                              'مشتری متفرقه',
                          gross: g,
                          downPayment: d,
                          date: DateTime.now().toIso8601String().substring(0, 10),
                          installmentCount: int.tryParse(count.text),
                          invoiceNumber: invoiceNo.text.trim(),
                          downPaymentAccountId: 'acc-cash',
                          notes: notes.text.trim(),
                          overrideCreditLimit: overrideLimit,
                          firstInstallmentPercentBps: (provNow != null &&
                                  provNow.scheduleType == ScheduleType.basalam &&
                                  fPctText.isNotEmpty)
                              ? ((double.tryParse(
                                          fPctText.replaceAll(',', '.')) ??
                                      0) *
                                  100)
                                  .round()
                              : null,
                          subsequentCountOverride: (provNow != null &&
                                  provNow.scheduleType == ScheduleType.basalam &&
                                  subText.isNotEmpty)
                              ? int.tryParse(subText)
                              : null,
                        );
                        Navigator.pop(ctx);
                        showStoreSnack(ctx, 'فروش اقساطی ثبت شد');
                      } on CreditLimitExceeded catch (e) {
                        showStoreSnack(ctx, '$e', error: true);
                      } catch (e) {
                        showStoreSnack(ctx, '$e', error: true);
                      }
                    },
                    child: const Text('ثبت فروش اقساطی'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    await _reload(core);
  }

  Future<void> _openSchedule(StoreCore core, InstallmentSaleEntity sale) async {
    final schedule = core.installments.schedule(sale.id);
    final provider =
        core.installments.providerById(sale.providerId);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('جزئیات فروش اقساطی — ${provider?.name ?? ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _kv('مبلغ کل', formatToman(sale.gross)),
          _kv('بیعانه', formatToman(sale.downPayment)),
          _kv('مبلغ تأمین‌شده', formatToman(sale.financed)),
          if (provider != null && !provider.isStore) ...[
            _kv('کارمزد', formatToman(sale.commission)),
            if (sale.commissionVat > 0)
              _kv('مالیات کارمزد', formatToman(sale.commissionVat)),
            if (sale.otherDeductions > 0)
              _kv('سایر کسورات', formatToman(sale.otherDeductions)),
            _kv('تسویهٔ مورد انتظار', formatToman(sale.netSettlement)),
            _kv('تاریخ تسویهٔ مورد انتظار', faDate(sale.expectedSettlementDate)),
          ],
          _kv('وضعیت', sale.status),
          const Divider(height: 26),
          const Text('برنامهٔ اقساط مشتری',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          for (final i in schedule)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: i.remaining == 0
                    ? AppTheme.RubySuccess.withValues(alpha: 0.15)
                    : i.dueDate.compareTo(DateTime.now().toIso8601String().substring(0, 10)) < 0
                        ? AppTheme.RubyError.withValues(alpha: 0.15)
                        : AppTheme.RubyPrimary.withValues(alpha: 0.12),
                child: Text(
                  PersianNumberFormatter.toPersian('${i.number}'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
              title: Text(formatToman(i.amount),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              subtitle: Text(
                i.remaining == 0
                    ? 'پرداخت‌شده — ${faDate(i.paidDate)}'
                    : 'سررسید: ${faDate(i.dueDate)}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: i.remaining > 0
                  ? const Icon(Icons.pending_actions,
                      size: 18, color: AppTheme.RubyWarning)
                  : const Icon(Icons.check_circle,
                      size: 18, color: AppTheme.RubySuccess),
            ),
          // ── برنامهٔ تسویهٔ درگاه → فروشگاه (نسخهٔ ۳) ──
          if (provider != null && !provider.isStore) ...[
            const Divider(height: 26),
            const Text('برنامهٔ تسویهٔ درگاه (واریز به فروشگاه)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            ...core.installments.settlementScheduleRows(sale.id).map(
                  (r) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: (r['received_amount'] as int) >=
                              (r['amount'] as int)
                          ? AppTheme.RubySuccess.withValues(alpha: 0.15)
                          : AppTheme.RubyPrimary.withValues(alpha: 0.12),
                      child: Text(
                        PersianNumberFormatter.toPersian('${r['number']}'),
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ),
                    title: Text(
                      formatToman(r['amount'] as int),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      (r['received_amount'] as int) >= (r['amount'] as int)
                          ? 'دریافت‌شده — ${faDate(r['received_date'] as String?)}'
                          : 'انتظار: ${faDate(r['expected_date'] as String)}'
                              '${(r['received_amount'] as int) > 0 ? ' · دریافت جزئی: ${formatToman(r['received_amount'] as int)}' : ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: (r['received_amount'] as int) < (r['amount'] as int)
                        ? const Icon(Icons.account_balance,
                            size: 18, color: Colors.indigo)
                        : const Icon(Icons.check_circle,
                            size: 18, color: AppTheme.RubySuccess),
                  ),
                ),
          ],
          const SizedBox(height: 12),
          if (sale.status != 'CANCELLED' && sale.status != 'REFUNDED')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final ok = await confirmDialog(ctx,
                          title: 'لغو فروش اقساطی',
                          message:
                              'همهٔ اثرهای مالی این فروش دقیقاً یک‌بار معکوس می‌شود و تاریخچه حفظ خواهد شد. ادامه؟',
                          confirmLabel: 'لغو فروش');
                      if (!ok) return;
                      try {
                        core.installments.cancelSale(sale.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _reload(core);
                      } catch (e) {
                        if (ctx.mounted) showStoreSnack(ctx, '$e', error: true);
                      }
                    },
                    child: const Text('لغو فروش', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final ok = await confirmDialog(ctx,
                          title: 'برگشت فروش اقساطی',
                          message:
                              'فروش به‌عنوان برگشت ثبت و اثرهای مالی معکوس می‌شود. ادامه؟',
                          confirmLabel: 'ثبت برگشت');
                      if (!ok) return;
                      try {
                        core.installments.refundSale(sale.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _reload(core);
                      } catch (e) {
                        if (ctx.mounted) showStoreSnack(ctx, '$e', error: true);
                      }
                    },
                    child: const Text('برگشت', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    await _reload(core);
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(fontSize: 12.5, color: AppTheme.RubyTextSecondary)),
            Text(v, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return StoreScaffold(
      title: 'فروش اقساطی',
      fab: FloatingActionButton.extended(
        onPressed: () async {
          final core = await ref.read(storeCoreProvider.future);
          _openCreate(core);
        },
        icon: const Icon(Icons.add),
        label: const Text('فروش اقساطی جدید'),
      ),
      body: (context, core) {
        if (_loading) {
          _reload(core);
          return const Center(child: CircularProgressIndicator());
        }
        if (_sales.isEmpty) {
          return const Center(
            child: Text('هنوز فروش اقساطی ثبت نشده است',
                style: TextStyle(color: AppTheme.RubyTextSecondary)),
          );
        }
        return RefreshIndicator(
          onRefresh: () => _reload(core),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _sales.length,
            itemBuilder: (_, i) {
              final s = _sales[i];
              final provider = core.installments.providerById(s.providerId);
              final settled = core.installments.settledAmount(s.id);
              return Card(
                color: Colors.white,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  onTap: () => _openSchedule(core, s),
                  title: Text(
                    '${s.customerName} — ${formatToman(s.gross)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    provider == null
                        ? ''
                        : '${provider.name} · ${s.installmentCount} قسط · ${faDate(s.saleDate)}'
                            '${provider.isStore ? '' : ' · تسویه: ${formatToman(settled)}/${formatToman(s.netSettlement)}'}',
                    style: const TextStyle(fontSize: 10.5),
                  ),
                  trailing: _statusChip(s.status),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _statusChip(String status) {
    late final Color color;
    late final String label;
    switch (status) {
      case 'SETTLED':
        color = AppTheme.RubySuccess;
        label = 'تسویه‌شده';
        break;
      case 'PARTIALLY_SETTLED':
        color = Colors.indigo;
        label = 'تسویهٔ جزئی';
        break;
      case 'CANCELLED':
        color = Colors.grey;
        label = 'لغو‌شده';
        break;
      case 'REFUNDED':
        color = AppTheme.RubyError;
        label = 'برگشتی';
        break;
      case 'AUTHORIZED':
        color = Colors.blue;
        label = 'تأییدشده';
        break;
      default:
        color = AppTheme.RubyWarning;
        label = 'ثبت‌شده';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w900, color: color)),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final CommissionBreakdown breakdown;
  const _BreakdownCard({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.RubyWarning.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          _row('مبلغ تأمین‌شده', breakdown.grossFinanced),
          _row('کارمزد سیستم', -breakdown.commission),
          if (breakdown.commissionVat > 0)
            _row('مالیات بر کارمزد', -breakdown.commissionVat),
          if (breakdown.otherDeductions > 0)
            _row('سایر کسورات', -breakdown.otherDeductions),
          const Divider(height: 12),
          _row('تسویهٔ خالص مورد انتظار', breakdown.netSettlement,
              bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, int value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                    color: AppTheme.RubyTextSecondary)),
            Text(
              value < 0 ? formatToman(value.abs()) : formatToman(value),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: value < 0 ? AppTheme.RubyError : AppTheme.RubyTextPrimary,
              ),
            ),
          ],
        ),
      );
}
