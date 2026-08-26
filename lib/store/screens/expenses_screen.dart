import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../store_core.dart';
import '../expenses/expense_repository.dart';
import '../providers/store_providers.dart';
import 'store_ui_helpers.dart';

/// مدیریت هزینه‌ها (§8) — ثبت، ابطال ایمن، دسته‌بندی و گزارش دسته‌ای
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  bool _loading = true;
  List<ExpenseRecord> _expenses = [];
  List<ExpenseCategory> _categories = [];
  List<Map<String, Object?>> _totals = [];
  int? _filterCategoryId;
  final _monthStart = ValueNotifier<String>('');

  Future<void> _reload(StoreCore core) async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    try {
      final now = DateTime.now();
      final monthStart =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-01';
      _monthStart.value = monthStart;
      final expenses = core.expenses.list(
        categoryId: _filterCategoryId,
        from: monthStart,
      );
      final categories = core.expenses.categories();
      final totals = core.expenses.totalsByCategory(from: monthStart);
      setState(() {
        _expenses = expenses;
        _categories = categories;
        _totals = totals;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      showStoreSnack(context, 'خطا: $e', error: true);
    }
  }

  Future<void> _openFormAsync() async {
    final core = await ref.read(storeCoreProvider.future);
    await _openForm(core);
  }

  Future<void> _openForm(StoreCore core) async {
    final amount = TextEditingController();
    final desc = TextEditingController();
    final ref = TextEditingController();
    final categories = core.expenses.categories();
    final suppliers = core.suppliers.list(onlyActive: true);
    final accounts = core.accounts.list(onlyActive: true);
    if (categories.isEmpty) {
      showStoreSnack(context, 'دستهٔ هزینه موجود نیست', error: true);
      return;
    }
    var categoryId = categories.first.id;
    String? supplierId;
    String? accountId;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('ثبت هزینه',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: categoryId,
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(value: c.id, child: Text(c.title)),
                  ],
                  onChanged: (v) => setSheet(() => categoryId = v ?? categoryId),
                  decoration: const InputDecoration(labelText: 'دستهٔ هزینه *'),
                ),
                const SizedBox(height: 12),
                TomanField(controller: amount, label: 'مبلغ *'),
                const SizedBox(height: 12),
                TextField(
                    controller: desc,
                    decoration: const InputDecoration(labelText: 'توضیحات')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: accountId,
                  items: [
                    const DropdownMenuItem(value: '', child: Text('بدون تخلیه از حساب (نسیه)')),
                    for (final a in accounts)
                      DropdownMenuItem(value: a.id, child: Text('پرداخت از ${a.name}')),
                  ],
                  onChanged: (v) => setSheet(() => accountId = v),
                  decoration: const InputDecoration(labelText: 'حساب پرداخت'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: supplierId,
                  items: [
                    const DropdownMenuItem(value: '', child: Text('—')),
                    for (final s in suppliers)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => setSheet(() => supplierId = v),
                  decoration: const InputDecoration(labelText: 'تأمین‌کننده (اختیاری)'),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: ref,
                    decoration: const InputDecoration(labelText: 'مرجع/شماره سند')),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final v = parseToman(amount.text);
                    if (v == null || v <= 0) {
                      showStoreSnack(ctx, 'مبلغ نامعتبر', error: true);
                      return;
                    }
                    try {
                      core.expenses.add(
                        categoryId: categoryId,
                        amount: v,
                        date: DateTime.now().toIso8601String().substring(0, 10),
                        description: desc.text.trim(),
                        supplierId:
                            (supplierId == null || supplierId!.isEmpty) ? null : supplierId,
                        accountId: (accountId == null || accountId!.isEmpty) ? null : accountId,
                        reference: ref.text.trim(),
                      );
                      Navigator.pop(ctx);
                      showStoreSnack(ctx, 'هزینه ثبت شد');
                    } catch (e) {
                      showStoreSnack(ctx, '$e', error: true);
                    }
                  },
                  child: const Text('ثبت هزینه'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await _reload(core);
  }

  @override
  Widget build(BuildContext context) {
    return StoreScaffold(
      title: 'هزینه‌ها',
      fab: FloatingActionButton.extended(
        onPressed: _openFormAsync,
        icon: const Icon(Icons.add),
        label: const Text('هزینهٔ جدید'),
      ),
      body: (core) {
        if (_loading) {
          _reload(core);
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: DropdownButtonFormField<int?>(
                value: _filterCategoryId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('همهٔ دسته‌ها')),
                  for (final c in _categories)
                    DropdownMenuItem(value: c.id, child: Text(c.title)),
                ],
                onChanged: (v) {
                  setState(() {
                    _filterCategoryId = v;
                    _loading = true;
                  });
                  _reload(core);
                },
                decoration: const InputDecoration(labelText: 'فیلتر دسته', isDense: true),
              ),
            ),
            if (_totals.isNotEmpty)
              SizedBox(
                height: 86,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(10),
                  children: [
                    for (final t in _totals)
                      Container(
                        width: 150,
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(t['cat_title'] as String,
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.RubyTextSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              formatToman(t['total'] as int),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.RubyError),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: _expenses.isEmpty
                  ? const Center(
                      child: Text('این ماه هزینه‌ای ثبت نشده است',
                          style: TextStyle(color: AppTheme.RubyTextSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _expenses.length,
                      itemBuilder: (_, i) {
                        final e = _expenses[i];
                        final cat = _categories
                            .cast<ExpenseCategory?>()
                            .firstWhere((c) => c?.id == e.categoryId,
                                orElse: () => null);
                        return Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppTheme.RubyError.withOpacity(0.12),
                              child: const Icon(Icons.trending_down,
                                  color: AppTheme.RubyError, size: 20),
                            ),
                            title: Text(
                                '${cat?.title ?? 'هزینه'} — ${formatToman(e.amount)}',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w900)),
                            subtitle: Text(
                                '${faDate(e.date)}${e.description.isEmpty ? '' : ' · ${e.description}'}',
                                style: const TextStyle(fontSize: 11)),
                            trailing: e.voidedAt != null
                                ? const Text('ابطال‌شده',
                                    style: TextStyle(
                                        color: AppTheme.RubyTextSecondary,
                                        fontSize: 10))
                                : IconButton(
                                    icon: const Icon(Icons.undo,
                                        size: 20, color: AppTheme.RubyWarning),
                                    tooltip: 'ابطال هزینه',
                                    onPressed: () async {
                                      final ok = await confirmDialog(context,
                                          title: 'ابطال هزینه',
                                          message:
                                              'هزینهٔ ${formatToman(e.amount)} ابطال شود؟ اثر مالی آن معکوس می‌شود ولی تاریخچه حذف نمی‌شود.');
                                      if (ok) {
                                        try {
                                          core.expenses.voidExpense(e.id);
                                          showStoreSnack(
                                              context, 'هزینه ابطال شد');
                                          _reload(core);
                                        } catch (err) {
                                          showStoreSnack(context, '$err',
                                              error: true);
                                        }
                                      }
                                    },
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
