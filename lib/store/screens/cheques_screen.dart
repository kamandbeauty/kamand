import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../cheques/cheque_repository.dart';
import '../providers/store_providers.dart';
import '../store_core.dart';
import 'store_ui_helpers.dart';

/// مرکز چک‌ها — در جریان / وصول / برگشتی + پرسش سررسید: «پاس شد؟»
class ChequesScreen extends ConsumerStatefulWidget {
  const ChequesScreen({super.key});

  @override
  ConsumerState<ChequesScreen> createState() => _ChequesScreenState();
}

class _ChequesScreenState extends ConsumerState<ChequesScreen> {
  int _tab = 0; // 0=در جریان 1=وصول‌شده 2=برگشتی
  List<dynamic> _rows = [];
  List<dynamic> _due = [];

  Future<void> _reload(StoreCore core) async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    try {
      final status = _tab == 0
          ? ChequeStatus.held
          : (_tab == 1 ? ChequeStatus.cleared : ChequeStatus.bounced);
      setState(() {
        _rows = core.cheques.list(status: status);
        _due = core.cheques.dueForConfirmation(todayIso());
      });
    } catch (e) {
      showStoreSnack(context, 'خطا: $e', error: true);
    }
  }

  /// سؤال سررسید: آیا چکی که از/به فلانی گرفتیم/دادیم پاس شده؟
  Future<void> _askDue(StoreCore core, dynamic cheque) async {
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
              Text(
                cheque.isReceived
                    ? 'آیا چکی که از ${cheque.counterpartyName} دریافت کردیم پاس شده؟'
                    : 'آیا چکی که به ${cheque.counterpartyName} دادیم پاس شده؟',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'چک ${cheque.chequeNumber} · ${formatToman(cheque.amount)} · '
                '${cheque.bankName.isEmpty ? '' : '${cheque.bankName} · '}'
                'سررسید: ${faDate(cheque.dueDate)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11.5, color: AppTheme.RubyTextSecondary),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: accountId,
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.typeLabel})')),
                ],
                onChanged: (v) => setSheet(() => accountId = v ?? accountId),
                decoration: const InputDecoration(labelText: 'وصول به حساب'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.RubyError),
                      onPressed: () {
                        try {
                          core.cheques.bounceCheque(cheque.id);
                          Navigator.pop(ctx);
                          showStoreSnack(ctx, 'برگشت چک ثبت شد (بدهی برمی‌گردد)');
                          _reload(core);
                        } catch (e) {
                          showStoreSnack(ctx, '$e', error: true);
                        }
                      },
                      child: const Text('برگشت خورد'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('هنوز نه'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        try {
                          core.cheques.clearCheque(
                            cheque.id,
                            accountId: accountId,
                            date: todayIso(),
                          );
                          Navigator.pop(ctx);
                          showStoreSnack(ctx, 'وصول چک ثبت شد');
                          _reload(core);
                        } catch (e) {
                          showStoreSnack(ctx, '$e', error: true);
                        }
                      },
                      child: const Text('بله، پاس شد'),
                    ),
                  ),
                ],
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
      title: 'چک‌ها',
      actions: [
        IconButton(
          onPressed: () async {
            final core = await ref.read(storeCoreProvider.future);
            _reload(core);
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: (context, core) {
        if (_rows.isEmpty && _due.isEmpty) _reload(core);
        return RefreshIndicator(
          onRefresh: () => _reload(core),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // ── یادآور سررسید ──
              if (_due.isNotEmpty) ...[
                const SectionHeader('⏰ بپرسید: این چک‌ها پاس شده‌اند؟'),
                ..._due.map((c) => Card(
                      color: const Color(0xFFFFFBEB),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                              color: AppTheme.RubyWarning.withValues(alpha: 0.5))),
                      child: ListTile(
                        onTap: () => _askDue(core, c),
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.RubyWarning.withValues(alpha: 0.15),
                          child: const Icon(Icons.help_outline,
                              color: AppTheme.RubyWarning, size: 22),
                        ),
                        title: Text(
                          '${c.isReceived ? 'دریافتی از' : 'پرداختی به'} ${c.counterpartyName} — ${formatToman(c.amount)}',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          'چک ${c.chequeNumber}${c.bankName.isEmpty ? '' : ' · ${c.bankName}'} · سررسید: ${faDate(c.dueDate)}',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        trailing: const Icon(Icons.touch_app,
                            size: 20, color: AppTheme.RubyWarning),
                      ),
                    )),
              ],
              // ── سربرگ تب‌ها ──
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('در جریان'),
                        selected: _tab == 0,
                        onSelected: (_) {
                          setState(() => _tab = 0);
                          _reload(core);
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('وصول‌شده'),
                        selected: _tab == 1,
                        onSelected: (_) {
                          setState(() => _tab = 1);
                          _reload(core);
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('برگشتی'),
                        selected: _tab == 2,
                        onSelected: (_) {
                          setState(() => _tab = 2);
                          _reload(core);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (_rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('چکی در این دسته نیست',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.RubyTextSecondary)),
                )
              else
                ..._rows.map((c) => Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        onTap: (c.status == ChequeStatus.held)
                            ? () => _askDue(core, c)
                            : null,
                        leading: CircleAvatar(
                          backgroundColor: (c.isReceived
                                  ? AppTheme.RubySuccess
                                  : Colors.indigo)
                              .withValues(alpha: 0.13),
                          child: Icon(
                            c.isReceived
                                ? Icons.south_west
                                : Icons.north_east,
                            color: c.isReceived
                                ? AppTheme.RubySuccess
                                : Colors.indigo,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          '${formatToman(c.amount)} — ${c.isReceived ? 'از' : 'به'} ${c.counterpartyName}',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          'چک ${c.chequeNumber}'
                          '${c.holderName.isEmpty ? '' : ' · ${c.holderName}'}'
                          '${c.bankName.isEmpty ? '' : ' · ${c.bankName}'}'
                          '${c.sayadiNumber.isEmpty ? '' : ' · صیادی ${c.sayadiNumber}'}'
                          ' · ${c.statusLabel}'
                          '${c.status == ChequeStatus.cleared ? ' (${faDate(c.clearedDate)})' : ' · سررسید: ${faDate(c.dueDate)}'}',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                      ),
                    )),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}
