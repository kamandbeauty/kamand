import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../installments/installment_repository.dart';
import '../../providers/store_providers.dart';
import '../../store_core.dart';
import '../store_ui_helpers.dart';

/// مرکز اقساط (§16، §17، §28): امروز / معوق / آینده + ثبت پرداخت
class InstallmentCenterScreen extends ConsumerStatefulWidget {
  const InstallmentCenterScreen({super.key});

  @override
  ConsumerState<InstallmentCenterScreen> createState() =>
      _InstallmentCenterScreenState();
}

class _InstallmentCenterScreenState
    extends ConsumerState<InstallmentCenterScreen> {
  int _tab = 0;
  List<Map<String, Object?>> _dueToday = [];
  List<Map<String, Object?>> _overdue = [];
  List<Map<String, Object?>> _upcoming = [];

  Future<void> _reload(StoreCore core) async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    try {
      core.installments.refreshStatuses();
      setState(() {
        _dueToday = core.installments.dueToday();
        _overdue = core.installments.overdue();
        final today = DateTime.now();
        final to = today.add(const Duration(days: 45));
        _upcoming = core.installments.upcoming(
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
          '${to.year.toString().padLeft(4, '0')}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}',
        );
      });
    } catch (e) {
      showStoreSnack(context, 'خطا: $e', error: true);
    }
  }

  Future<void> _pay(StoreCore core, Map<String, Object?> inst) async {
    final amount = TextEditingController();
    final ref = TextEditingController();
    final accounts = core.accounts.list(onlyActive: true);
    String? accountId = accounts.isNotEmpty ? accounts.first.id : null;
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
              Text(
                  'پرداخت قسط ${inst['number']} — ${inst['customer_name'] ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                'ماندهٔ این قسط: ${formatToman((inst['amount'] as int) - (inst['paid_amount'] as int))}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12.5, color: AppTheme.RubyWarning, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              TomanField(controller: amount, label: 'مبلغ (خالی = کل قسط)'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: accountId,
                items: [
                  const DropdownMenuItem(value: '', child: Text('بدون ورود به حساب')),
                  for (final a in accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setSheet(() => accountId = v),
                decoration: const InputDecoration(labelText: 'حساب دریافت'),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: ref,
                  decoration: const InputDecoration(
                      labelText: 'مرجع پرداخت (اختیاری، جلوگیری از ثبت تکراری)')),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  try {
                    final remaining =
                        (inst['amount'] as int) - (inst['paid_amount'] as int);
                    final v = parseToman(amount.text);
                    core.installments.payInstallment(
                      installmentId: inst['id'] as String,
                      date: DateTime.now().toIso8601String().substring(0, 10),
                      accountId: (accountId != null && accountId.isNotEmpty) ? accountId : null,
                      amount: (v == null || v <= 0) ? remaining : v,
                      paymentRef: ref.text.trim(),
                    );
                    Navigator.pop(ctx);
                    showStoreSnack(ctx, 'پرداخت قسط ثبت شد');
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

  @override
  Widget build(BuildContext context) {
    return StoreScaffold(
      title: 'اقساط و سررسیدها',
      body: (context, core) {
        if (_dueToday.isEmpty && _overdue.isEmpty && _upcoming.isEmpty) {
          _reload(core);
        }
        return RefreshIndicator(
          onRefresh: () => _reload(core),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text('امروز (${_dueToday.length})'),
                        selected: _tab == 0,
                        onSelected: (_) => setState(() => _tab = 0),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ChoiceChip(
                        label: Text('معوق (${_overdue.length})'),
                        selected: _tab == 1,
                        onSelected: (_) => setState(() => _tab = 1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ChoiceChip(
                        label: Text('آینده (${_upcoming.length})'),
                        selected: _tab == 2,
                        onSelected: (_) => setState(() => _tab = 2),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _list(core,
                    _tab == 0 ? _dueToday : (_tab == 1 ? _overdue : _upcoming)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _list(StoreCore core, List<Map<String, Object?>> rows) {
    if (rows.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 80),
        Icon(Icons.event_available, size: 48, color: AppTheme.RubyTextSecondary),
        SizedBox(height: 10),
        Center(
            child: Text('قسطی در این دسته نیست',
                style: TextStyle(color: AppTheme.RubyTextSecondary))),
      ]);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final r = rows[i];
        final remaining = (r['amount'] as int) - (r['paid_amount'] as int);
        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            onTap: () => _pay(core, r),
            leading: CircleAvatar(
              backgroundColor: _tab == 1
                  ? AppTheme.RubyError.withOpacity(0.13)
                  : AppTheme.RubyWarning.withOpacity(0.13),
              child: Icon(
                _tab == 1 ? Icons.warning_amber : Icons.event,
                color: _tab == 1 ? AppTheme.RubyError : AppTheme.RubyWarning,
                size: 20,
              ),
            ),
            title: Text(
              '${r['customer_name'] ?? ''} — قسط ${r['number']} از ${r['provider_name'] ?? ''}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              'مانده: ${formatToman(remaining)} · سررسید: ${faDate(r['due_date'] as String)}'
              '${(r['invoice_number'] as String? ?? '').isNotEmpty ? ' · فاکتور ${r['invoice_number']}' : ''}',
              style: const TextStyle(fontSize: 10.5),
            ),
            trailing: const Icon(Icons.payments_outlined,
                size: 20, color: AppTheme.RubySuccess),
          ),
        );
      },
    );
  }
}
