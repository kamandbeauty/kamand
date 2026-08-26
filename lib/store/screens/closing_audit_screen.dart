import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/store_providers.dart';
import '../../store_core.dart';
import '../store_ui_helpers.dart';

/// بستن روز (§38) + تاریخچهٔ حسابرسی (§40)
class ClosingAuditScreen extends ConsumerStatefulWidget {
  const ClosingAuditScreen({super.key});

  @override
  ConsumerState<ClosingAuditScreen> createState() => _ClosingAuditScreenState();
}

class _ClosingAuditScreenState extends ConsumerState<ClosingAuditScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return StoreScaffold(
      title: 'بستن روز و حسابرسی',
      body: (core) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('بستن روز'),
                      selected: _tab == 0,
                      onSelected: (_) => setState(() => _tab = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('تاریخچهٔ حسابرسی'),
                      selected: _tab == 1,
                      onSelected: (_) => setState(() => _tab = 1),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _tab == 0 ? _ClosingTab(core: core) : _AuditTab(core: core),
            ),
          ],
        );
      },
    );
  }
}

class _ClosingTab extends StatefulWidget {
  final StoreCore core;
  const _ClosingTab({required this.core});

  @override
  State<_ClosingTab> createState() => _ClosingTabState();
}

class _ClosingTabState extends State<_ClosingTab> {
  final _cash = TextEditingController();
  final _bank = TextEditingController();
  final _notes = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final core = widget.core;
    final expectedCash = core.reports.expectedCashBalance();
    final expectedBank = core.reports.expectedBankBalance();
    final history = core.reports.closingHistory(limit: 30);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _row('نقد مورد انتظار (صندوق + کارت‌خوان)', formatToman(expectedCash)),
                _row('بانک مورد انتظار', formatToman(expectedBank)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TomanField(controller: _cash, label: 'شمارش واقعی صندوق'),
        const SizedBox(height: 10),
        TomanField(controller: _bank, label: 'ماندهٔ واقعی بانک'),
        const SizedBox(height: 10),
        TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'یادداشت صندوقدار')),
        if (parseToman(_cash.text) != null)
          _diff('اختلاف صندوق', parseToman(_cash.text)! - expectedCash),
        if (parseToman(_bank.text) != null)
          _diff('اختلاف بانک', parseToman(_bank.text)! - expectedBank),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            try {
              core.reports.saveDailyClosing(
                date: DateTime.now().toIso8601String().substring(0, 10),
                actualCash: parseToman(_cash.text) ?? 0,
                actualBank: parseToman(_bank.text) ?? 0,
                notes: _notes.text.trim(),
              );
              showStoreSnack(context, 'بستن روز ثبت شد');
            } catch (e) {
              showStoreSnack(context, '$e', error: true);
            }
          },
          icon: const Icon(Icons.fact_check),
          label: const Text('ثبت بستن روز'),
        ),
        const SectionHeader('تاریخچه'),
        for (final h in history)
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              dense: true,
              title: Text('بستن روز ${faDate(h['closing_date'] as String)}'),
              subtitle: Text(
                'صندوق: ${formatToman(h['actual_cash'] as int)} (انتظار ${formatToman(h['expected_cash'] as int)}) · بانک: ${formatToman(h['actual_bank'] as int)} (انتظار ${formatToman(h['expected_bank'] as int)})',
                style: const TextStyle(fontSize: 10.5),
              ),
              trailing: Text(
                _diffLabel((h['actual_cash'] as int) - (h['expected_cash'] as int)),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: (h['actual_cash'] as int) == (h['expected_cash'] as int)
                      ? AppTheme.RubySuccess
                      : AppTheme.RubyError,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _diffLabel(int d) =>
      d == 0 ? 'برابر' : (d > 0 ? 'اضافه: ${formatToman(d)}' : 'کمبود: ${formatToman(-d)}');

  Widget _diff(String label, int diff) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12.5)),
            Text(
              _diffLabel(diff),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: diff == 0 ? AppTheme.RubySuccess : AppTheme.RubyError,
              ),
            ),
          ],
        ),
      );

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(fontSize: 12.5, color: AppTheme.RubyTextSecondary)),
            Text(v, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _AuditTab extends StatelessWidget {
  final StoreCore core;
  const _AuditTab({required this.core});

  @override
  Widget build(BuildContext context) {
    final rows = core.audit.recent(limit: 150);
    if (rows.isEmpty) {
      return const Center(
          child: Text('رویدادی ثبت نشده است',
              style: TextStyle(color: AppTheme.RubyTextSecondary)));
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
            title: Text('${r['action']} — ${r['entity']}:${r['entity_id']}',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
            subtitle: Text(
              '${faDate(r['log_date'] as String)}${(r['detail'] as String).isEmpty ? '' : ' · ${r['detail']}'}',
              style: const TextStyle(fontSize: 10.5),
            ),
          ),
        );
      },
    );
  }
}
