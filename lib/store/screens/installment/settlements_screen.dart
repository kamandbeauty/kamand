import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/store_providers.dart';
import '../../store_core.dart';
import '../store_ui_helpers.dart';

/// تسویه با درگاه‌های اقساطی (§18 + نسخهٔ ۳):
/// - یادآور «۱ تا ۵ هر ماه»: از کاربر می‌پرسد هر درگاه تسویه کرده؟ چند؟
/// - ثبت تسویه قسط‌به‌قسط طبق برنامهٔ هر فروش
/// - پیش‌بینی ماهانهٔ تسویه‌ها به تفکیک درگاه
class SettlementsScreen extends ConsumerStatefulWidget {
  const SettlementsScreen({super.key});

  @override
  ConsumerState<SettlementsScreen> createState() => _SettlementsScreenState();
}

class _SettlementsScreenState extends ConsumerState<SettlementsScreen> {
  bool _loading = true;
  List<Map<String, Object>> _pending = [];
  List<Map<String, Object>> _upcoming = [];
  List<Map<String, Object>> _monthly = [];
  List<Map<String, Object>> _history = [];
  int _totalOutstanding = 0;

  Future<void> _reload(StoreCore core) async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    try {
      final today = DateTime.now();
      final todayStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      // سررسید رسیده/گذشته و هنوز دریافت‌نشده → آماده پرسش از کاربر
      final pending =
          core.installments.pendingSettlementConfirmations(todayStr);
      final upcoming = core.installments.upcomingSettlements(
          from: todayStr, to: '${today.year + 2}-12-31');
      final monthly = core.installments.monthlySettlementForecast();
      final history = core.installments.settlements();
      final totals = core.reports.forecastTotals();
      setState(() {
        _pending = pending;
        _upcoming = upcoming;
        _monthly = monthly;
        _history = history;
        _totalOutstanding = totals['expectedIncoming'] ?? 0;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      showStoreSnack(context, 'خطا: $e', error: true);
    }
  }

  Future<void> _confirmAndSettle(StoreCore core, Map<String, Object> row) async {
    final amount = TextEditingController()
      ..text = '${row['remaining']}';
    final ref = TextEditingController();
    final accounts = core.accounts.list(onlyActive: true);
    String accountId = accounts.isNotEmpty ? accounts.first.id : 'acc-cash';
    final providerName = row['provider_name'] as String? ?? '';
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
              Text('آیا $providerName تسویه کرده است؟',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                'انتظار این قسط: ${formatToman((row['remaining'] as num).toInt())} — ${faDate(row['expected_date'] as String)}'
                '${(row['invoice_number'] as String? ?? '').isNotEmpty ? ' · فاکتور ${row['invoice_number']}' : ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11.5, color: AppTheme.RubyTextSecondary),
              ),
              const SizedBox(height: 14),
              TomanField(controller: amount, label: 'مبلغ دریافتی *'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: accountId,
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setSheet(() => accountId = v ?? accountId),
                decoration: const InputDecoration(labelText: 'واریز به حساب'),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: ref,
                  decoration: const InputDecoration(labelText: 'مرجع (اختیاری)')),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // هنوز تسویه نشده — فقط بستن؛ بعداً دوباره می‌پرسیم
                        Navigator.pop(ctx);
                      },
                      child: const Text('هنوز نه'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        final v = parseToman(amount.text);
                        if (v == null || v <= 0) {
                          showStoreSnack(ctx, 'مبلغ نامعتبر', error: true);
                          return;
                        }
                        try {
                          core.installments.settle(
                            saleId: row['sale_id'] as String,
                            scheduleId: row['id'] as String,
                            amount: v,
                            date:
                                DateTime.now().toIso8601String().substring(0, 10),
                            accountId: accountId,
                            reference: ref.text.trim(),
                          );
                          Navigator.pop(ctx);
                          showStoreSnack(ctx, 'تسویه ثبت شد');
                        } catch (e) {
                          showStoreSnack(ctx, '$e', error: true);
                        }
                      },
                      child: const Text('بله، ثبت تسویه'),
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
      title: 'تسویه با درگاه‌های اقساطی',
      actions: [
        IconButton(onPressed: () async {
          final core = await ref.read(storeCoreProvider.future);
          _reload(core);
        }, icon: const Icon(Icons.refresh)),
      ],
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
                label: 'دریافتی تسویه‌نشدهٔ فروشگاه (همهٔ درگاه‌ها + اقساط فروشگاه)',
                value: formatToman(_totalOutstanding),
                icon: Icons.account_balance_wallet,
                color: Colors.indigo,
              ),

              // ── یادآور: آیا درگاه تسویه کرده؟ ──
              if (_pending.isNotEmpty) ...[
                const SectionHeader('⏰ بپرسید: این درگاه‌ها تسویه کرده‌اند؟'),
                ..._pending.map((r) => Card(
                      color: const Color(0xFFFFFBEB),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                              color: AppTheme.RubyWarning.withOpacity(0.5))),
                      child: ListTile(
                        onTap: () => _confirmAndSettle(core, r),
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.RubyWarning.withOpacity(0.15),
                          child: const Icon(Icons.help_outline,
                              color: AppTheme.RubyWarning, size: 22),
                        ),
                        title: Text(
                          '${r['provider_name'] ?? ''} — ${formatToman((r['remaining'] as num).toInt())}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          'سررسید: ${faDate(r['expected_date'] as String)} · ${r['customer_name'] ?? ''}',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        trailing: const Icon(Icons.touch_app,
                            size: 20, color: AppTheme.RubyWarning),
                      ),
                    )),
              ],

              // ── پیش‌بینی ماهانه به تفکیک درگاه ──
              const SectionHeader('پیش‌بینی ماهانهٔ تسویه‌ها'),
              if (_monthly.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('تسویه‌ای در پیش نیست',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.RubyTextSecondary)),
                )
              else
                ..._monthly.map((m) => Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.indigo.withOpacity(0.12),
                          child: Text(
                            m['ym'].toString().substring(5),
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ),
                        title: Text('${m['provider_name']} — ماه ${m['ym']}',
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w800)),
                        subtitle: Text(
                            '${m['cnt']} قسط تسویه',
                            style: const TextStyle(fontSize: 10.5)),
                        trailing: Text(
                          formatToman(m['outstanding'] as int),
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.indigo),
                        ),
                      ),
                    )),

              // ── اقساط تسویهٔ آینده (قسط‌به‌قسط) ──
              const SectionHeader('اقساط تسویهٔ در انتظار'),
              if (_upcoming.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('قسطی در انتظار نیست',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.RubyTextSecondary)),
                )
              else
                ..._upcoming.map((r) => Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        onTap: () => _confirmAndSettle(core, r),
                        title: Text(
                          '${r['provider_name'] ?? ''} — قسط ${r['number']} از ${formatToman((r['outstanding'] as num).toInt())}',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          'انتظار: ${faDate(r['expected_date'] as String)} · ${r['customer_name'] ?? ''}',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        trailing: const Icon(Icons.payments_outlined,
                            size: 20, color: AppTheme.RubySuccess),
                      ),
                    )),

              // ── تاریخچه ──
              const SectionHeader('تاریخچهٔ تسویه‌های ثبت‌شده'),
              if (_history.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('هنوز تسویه‌ای ثبت نشده است',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.RubyTextSecondary)),
                )
              else
                ..._history.map((r) => Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          '${r['provider_name'] ?? ''} — ${formatToman(r['amount'] as int)}',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                            '${faDate(r['settle_date'] as String)} · ${r['customer_name'] ?? ''}',
                            style: const TextStyle(fontSize: 10.5)),
                        trailing: const Icon(Icons.check_circle,
                            size: 18, color: AppTheme.RubySuccess),
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
