import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../core/accounts.dart';
import '../providers/store_providers.dart';
import '../store_core.dart';
import 'store_ui_helpers.dart';

/// صندوق و بانک (§9): حساب‌ها، موجودی مشتق، انتقال وجه، تراکنش‌ها
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _loading = true;
  List<FinancialAccount> _accounts = [];
  List<int> _balances = [];
  int _tabIndex = 0;

  Future<void> _reload(StoreCore core) async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    try {
      final accounts = core.accounts.list();
      final balances = [for (final a in accounts) core.accounts.balance(a.id)];
      setState(() {
        _accounts = accounts;
        _balances = balances;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      showStoreSnack(context, 'خطا: $e', error: true);
    }
  }

  Future<void> _openAccountForm(StoreCore core) async {
    final name = TextEditingController();
    final opening = TextEditingController();
    const types = {'cash': 'صندوق نقدی', 'bank': 'حساب بانکی', 'card': 'کارت‌خوان', 'other': 'سایر'};
    var type = 'bank';
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('حساب جدید',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'نام حساب *')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                items: [
                  for (final e in types.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setSheet(() => type = v ?? type),
                decoration: const InputDecoration(labelText: 'نوع حساب'),
              ),
              const SizedBox(height: 12),
              TomanField(controller: opening, label: 'ماندهٔ آغازین'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (name.text.trim().isEmpty) {
                    showStoreSnack(ctx, 'نام الزامی است', error: true);
                    return;
                  }
                  core.accounts.save(
                    name: name.text.trim(),
                    type: type,
                    openingBalance: parseToman(opening.text) ?? 0,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('ذخیره حساب'),
              ),
            ],
          ),
        ),
      ),
    );
    await _reload(core);
  }

  Future<void> _openTransfer(StoreCore core) async {
    final accounts = core.accounts.list(onlyActive: true);
    if (accounts.length < 2) {
      showStoreSnack(context, 'برای انتقال حداقل دو حساب لازم است', error: true);
      return;
    }
    final amount = TextEditingController();
    final note = TextEditingController();
    var from = accounts.first.id;
    var to = accounts[1].id;
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
              const Text('انتقال وجه',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              Text('انتقال وجه درآمد یا هزینه محسوب نمی‌شود',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10.5, color: AppTheme.RubyTextSecondary)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: from,
                items: [
                  for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setSheet(() => from = v ?? from),
                decoration: const InputDecoration(labelText: 'از حساب'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: to,
                items: [
                  for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setSheet(() => to = v ?? to),
                decoration: const InputDecoration(labelText: 'به حساب'),
              ),
              const SizedBox(height: 12),
              TomanField(controller: amount, label: 'مبلغ *'),
              const SizedBox(height: 10),
              TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'توضیح (اختیاری)')),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final v = parseToman(amount.text);
                  if (v == null || v <= 0) {
                    showStoreSnack(ctx, 'مبلغ نامعتبر', error: true);
                    return;
                  }
                  try {
                    core.accounts.transfer(
                      fromAccountId: from,
                      toAccountId: to,
                      amount: v,
                      date: DateTime.now().toIso8601String().substring(0, 10),
                      note: note.text.trim(),
                    );
                    Navigator.pop(ctx);
                    showStoreSnack(ctx, 'انتقال وجه ثبت شد');
                  } catch (e) {
                    showStoreSnack(ctx, '$e', error: true);
                  }
                },
                child: const Text('ثبت انتقال'),
              ),
            ],
          ),
        ),
      ),
    );
    await _reload(core);
  }

  Future<void> _accountAction(
      StoreCore core, String accountId, String name, String action) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final isDeposit = action == 'deposit';
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
            Text(isDeposit ? 'واریز به $name' : 'برداشت از $name',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const Text('در سود و زیان حساب نمی‌شود (نه درآمد، نه هزینه)',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10.5, color: AppTheme.RubyTextSecondary)),
            const SizedBox(height: 14),
            TomanField(controller: amount, label: 'مبلغ *'),
            const SizedBox(height: 10),
            TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'توضیح')),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                final v = parseToman(amount.text);
                if (v == null || v <= 0) {
                  showStoreSnack(ctx, 'مبلغ نامعتبر', error: true);
                  return;
                }
                try {
                  final date = DateTime.now().toIso8601String().substring(0, 10);
                  if (isDeposit) {
                    core.accounts.deposit(
                        accountId: accountId,
                        amount: v,
                        date: date,
                        note: note.text.trim());
                  } else {
                    core.accounts.withdraw(
                        accountId: accountId,
                        amount: v,
                        date: date,
                        note: note.text.trim());
                  }
                  Navigator.pop(ctx);
                  showStoreSnack(ctx, 'ثبت شد');
                } catch (e) {
                  showStoreSnack(ctx, '$e', error: true);
                }
              },
              child: Text(isDeposit ? 'ثبت واریز' : 'ثبت برداشت'),
            ),
          ],
        ),
      ),
    );
    await _reload(core);
  }

  @override
  Widget build(BuildContext context) {
    return StoreScaffold(
      title: 'صندوق و بانک',
      actions: [
        IconButton(
            onPressed: () async {
              final core = await ref.read(storeCoreProvider.future);
              _openTransfer(core);
            },
            icon: const Icon(Icons.swap_horiz)),
        IconButton(
            onPressed: () async {
              final core = await ref.read(storeCoreProvider.future);
              _openAccountForm(core);
            },
            icon: const Icon(Icons.add)),
      ],
      body: (context, core) {
        if (_loading) {
          _reload(core);
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('حساب‌ها'),
                      selected: _tabIndex == 0,
                      onSelected: (_) => setState(() => _tabIndex = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('تراکنش‌ها'),
                      selected: _tabIndex == 1,
                      onSelected: (_) => setState(() => _tabIndex = 1),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _tabIndex == 1
                  ? _TransactionsTab(core: core)
                  : RefreshIndicator(
                      onRefresh: () => _reload(core),
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          for (var i = 0; i < _accounts.length; i++)
                            Card(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _typeColor(_accounts[i].type)
                                      .withOpacity(0.14),
                                  child: Icon(_typeIcon(_accounts[i].type),
                                      color: _typeColor(_accounts[i].type)),
                                ),
                                title: Text(_accounts[i].name,
                                    style: const TextStyle(
                                        fontSize: 13.5, fontWeight: FontWeight.w900)),
                                subtitle: Text(
                                    '${_accounts[i].typeLabel}${_accounts[i].isActive ? '' : ' · غیرفعال'}',
                                    style: const TextStyle(fontSize: 11)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      formatToman(_balances[i]),
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w900,
                                          color: AppTheme.RubyTextPrimary),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert,
                                          size: 20,
                                          color: AppTheme.RubyTextSecondary),
                                      onSelected: (v) => _accountAction(
                                          core, _accounts[i].id, _accounts[i].name, v),
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                            value: 'deposit',
                                            child: Text('واریز به حساب')),
                                        PopupMenuItem(
                                            value: 'withdraw',
                                            child: Text('برداشت از حساب')),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'موجودی هر حساب = ماندهٔ آغازین + جمع رویدادهای مؤثر دفتر کل (مشتق، نه دستی)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 10.5, color: AppTheme.RubyTextSecondary),
                            ),
                          ),
                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'cash':
        return AppTheme.RubySuccess;
      case 'bank':
        return Colors.indigo;
      case 'card':
        return Colors.purple;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'cash':
        return Icons.payments_outlined;
      case 'bank':
        return Icons.account_balance;
      case 'card':
        return Icons.credit_card;
      default:
        return Icons.account_balance_wallet;
    }
  }
}

/// صفحهٔ تراکنش‌های دفتر کل
class _TransactionsTab extends StatelessWidget {
  final StoreCore core;
  const _TransactionsTab({required this.core});

  static const _labels = {
    'SALE': 'فروش',
    'PAYMENT_RECEIVED': 'دریافت وجه',
    'REFUND': 'برگشت وجه',
    'EXPENSE': 'هزینه',
    'SHIPPING_EXPENSE': 'هزینهٔ ارسال',
    'PACKAGING_EXPENSE': 'هزینهٔ بسته‌بندی',
    'PACKAGING_CHARGE': 'دریافت بسته‌بندی',
    'SHIPPING_CHARGE': 'دریافت ارسال',
    'PURCHASE': 'خرید',
    'PURCHASE_PAYMENT': 'پرداخت خرید',
    'SUPPLIER_PAYMENT': 'پرداخت به تأمین‌کننده',
    'PURCHASE_RETURN': 'برگشت خرید',
    'SALE_RETURN': 'برگشت فروش',
    'REVENUE_REVERSED': 'اصلاح درآمد',
    'INSTALLMENT_CREATED': 'فروش اقساطی',
    'INSTALLMENT_PAID': 'دریافت قسط',
    'PROVIDER_SETTLEMENT': 'تسویهٔ اقساطی',
    'PROVIDER_COMMISSION': 'کارمزد اقساطی',
    'ACCOUNT_TRANSFER': 'انتقال وجه',
    'DEPOSIT': 'واریز',
    'WITHDRAWAL': 'برداشت',
    'ADJUSTMENT': 'تعدیل',
  };

  @override
  Widget build(BuildContext context) {
    final events = core.reports.recentTransactions(limit: 150);
    if (events.isEmpty) {
      return const Center(
          child: Text('هنوز تراکنشی ثبت نشده است',
              style: TextStyle(color: AppTheme.RubyTextSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: events.length,
      itemBuilder: (_, i) {
        final e = events[i];
        final inflow = e.direction == 1;
        final outflow = e.direction == -1;
        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            dense: true,
            title: Text(
              _labels[e.eventType] ?? e.eventType,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${faDate(e.eventDate)}${e.description.isEmpty ? '' : ' · ${e.description}'}',
              style: const TextStyle(fontSize: 10.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              inflow
                  ? '+${formatToman(e.amount)}'
                  : outflow
                      ? '−${formatToman(e.amount)}'
                      : formatToman(e.amount),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: inflow
                    ? AppTheme.RubySuccess
                    : outflow
                        ? AppTheme.RubyError
                        : AppTheme.RubyTextSecondary,
              ),
            ),
          ),
        );
      },
    );
  }
}
