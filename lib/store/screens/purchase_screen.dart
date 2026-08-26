import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../store_core.dart';
import '../providers/store_providers.dart';
import 'store_ui_helpers.dart';
import '../suppliers/purchase_repository.dart';
import '../suppliers/supplier_repository.dart';

/// فاکتورهای خرید (§7): ثبت خرید + افزایش موجودی + پرداخت + برگشت
class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({super.key});

  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen> {
  bool _loading = true;
  List<PurchaseInvoice> _purchases = [];
  List<Supplier> _suppliers = [];

  Future<void> _reload(StoreCore core) async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    try {
      final purchases = core.purchases.list();
      final suppliers = core.suppliers.list();
      setState(() {
        _purchases = purchases;
        _suppliers = suppliers;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      showStoreSnack(context, 'خطا: $e', error: true);
    }
  }

  Future<void> _openCreateAsync() async {
    final core = await ref.read(storeCoreProvider.future);
    await _openCreate(core);
  }

  Future<void> _openCreate(StoreCore core) async {
    if (_suppliers.isEmpty) {
      showStoreSnack(context, 'اول یک تأمین‌کننده ثبت کنید', error: true);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _PurchaseCreateScreen(core: core)),
    );
    await _reload(core);
  }

  Future<void> _openReturn(StoreCore core, PurchaseInvoice p) async {
    final items = core.purchases.items(p.id);
    if (items.isEmpty) {
      showStoreSnack(context, 'قلمی برای برگشت نیست', error: true);
      return;
    }
    final qtyControllers = <TextEditingController>[];
    var selected = <String, bool>{}; // purchaseItemId → انتخاب
    for (final it in items) {
      selected[it['id'] as String] = false;
      qtyControllers.add(TextEditingController());
    }
    final reduce = ValueNotifier<bool>(true);
    await showModalBottomSheet(
      context: context,
      isScrollControled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('برگشت از خرید',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 4),
              Text('برگشت، موجودی را کم و بدهی تأمین‌کننده را کاهش می‌دهد',
                  style: const TextStyle(fontSize: 11, color: AppTheme.RubyTextSecondary)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      CheckboxListTile(
                        dense: true,
                        value: selected[items[i]['id']],
                        title: Text(
                            '${items[i]['title']} — خرید ${items[i]['quantity']} × ${formatToman(items[i]['unit_price'] as int)}'),
                        subtitle: Text(
                            'برگشتی قبلی: ${core.purchases.returnedQty(items[i]['id'] as String)}'),
                        onChanged: (v) => setSheet(() => selected[items[i]['id'] as String] = v ?? false),
                        secondary: SizedBox(
                          width: 90,
                          child: TextField(
                            controller: qtyControllers[i],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                hintText: 'تعداد', isDense: true),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SwitchListTile(
                dense: true,
                title: const Text('کاهش بدهی تأمین‌کننده', style: TextStyle(fontSize: 13)),
                subtitle: const Text('خاموش = دریافت نقدی وجه برگشتی',
                    style: TextStyle(fontSize: 10.5)),
                value: reduce.value,
                onChanged: (v) => setSheet(() => reduce.value = v),
              ),
              FilledButton(
                onPressed: () {
                  try {
                    final inputs = <PurchaseReturnInput>[];
                    for (var i = 0; i < items.length; i++) {
                      if (selected[items[i]['id']] != true) continue;
                      final raw =
                          qtyControllers[i].text.replaceAll(RegExp(r'[^0-9.]'), '');
                      final qty = double.tryParse(raw);
                      if (qty == null || qty <= 0) continue;
                      inputs.add(PurchaseReturnInput(
                          purchaseItemId: items[i]['id'] as String, quantity: qty));
                    }
                    if (inputs.isEmpty) {
                      showStoreSnack(ctx, 'حداقل یک قلم با تعداد انتخاب کنید', error: true);
                      return;
                    }
                    core.purchases.returnPurchase(
                      purchaseId: p.id,
                      returnItems: inputs,
                      date: DateTime.now().toIso8601String().substring(0, 10),
                      reducePayable: reduce.value,
                    );
                    Navigator.pop(ctx);
                    showStoreSnack(ctx, 'برگشت خرید ثبت شد');
                  } catch (e) {
                    showStoreSnack(ctx, '$e', error: true);
                  }
                },
                child: const Text('ثبت برگشت'),
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
      title: 'فاکتورهای خرید',
      fab: FloatingActionButton.extended(
        onPressed: _openCreateAsync,
        icon: const Icon(Icons.add),
        label: const Text('خرید جدید'),
      ),
      body: (core) {
        if (_loading) {
          _reload(core);
          return const Center(child: CircularProgressIndicator());
        }
        if (_purchases.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_cart_outlined,
                    size: 54, color: AppTheme.RubyTextSecondary),
                const SizedBox(height: 12),
                const Text('هنوز خریدی ثبت نشده است',
                    style: TextStyle(color: AppTheme.RubyTextSecondary)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _openCreate(core),
                  icon: const Icon(Icons.add),
                  label: const Text('ثبت اولین خرید'),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => _reload(core),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _purchases.length,
            itemBuilder: (_, i) {
              final p = _purchases[i];
              final supplierName = _suppliers
                  .cast<Supplier?>()
                  .firstWhere((s) => s?.id == p.supplierId, orElse: () => null)
                  ?.name;
              return Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  title: Text(
                      'خرید ${p.number.isEmpty ? '' : '${p.number} · '}${supplierName ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  subtitle: Text(
                      'جمع: ${formatToman(p.total)} · پرداخت: ${formatToman(p.paid)} · ${faDate(p.date)}',
                      style: const TextStyle(fontSize: 11)),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'return') _openReturn(core, p);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'return', child: Text('برگشت از خرید')),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PurchaseCreateScreen extends ConsumerStatefulWidget {
  final StoreCore core;
  const _PurchaseCreateScreen({required this.core});

  @override
  ConsumerState<_PurchaseCreateScreen> createState() =>
      _PurchaseCreateScreenState();
}

class _PurchaseCreateScreenState extends ConsumerState<_PurchaseCreateScreen> {
  final _supplierId = ValueNotifier<String>('');
  final _number = TextEditingController();
  final _discount = TextEditingController();
  final _shipping = TextEditingController();
  final _other = TextEditingController();
  final _tax = TextEditingController();
  final _paid = TextEditingController();

  final _titles = <TextEditingController>[];
  final _qtys = <TextEditingController>[];
  final _prices = <TextEditingController>[];
  final _productIds = <String?>[];

  StoreCore get core => widget.core;

  @override
  void initState() {
    super.initState();
    _supplierId.value =
        core.suppliers.list().isNotEmpty ? core.suppliers.list().first.id : '';
    _addRow();
  }

  void _addRow() {
    setState(() {
      _titles.add(TextEditingController());
      _qtys.add(TextEditingController(text: '1'));
      _prices.add(TextEditingController());
      _productIds.add(null);
    });
  }

  void _removeRow(int i) {
    setState(() {
      _titles.removeAt(i).dispose();
      _qtys.removeAt(i).dispose();
      _prices.removeAt(i).dispose();
      _productIds.removeAt(i);
    });
  }

  int get _subtotal {
    var sum = 0;
    for (var i = 0; i < _titles.length; i++) {
      final qty = double.tryParse(_qtys[i].text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      final price = parseToman(_prices[i].text) ?? 0;
      sum += (qty * price).round();
    }
    return sum;
  }

  int get _total =>
      _subtotal -
      (parseToman(_discount.text) ?? 0) +
      (parseToman(_shipping.text) ?? 0) +
      (parseToman(_other.text) ?? 0) +
      (parseToman(_tax.text) ?? 0);

  Future<void> _save() async {
    final suppliers = core.suppliers.list();
    if (suppliers.isEmpty || _supplierId.value.isEmpty) {
      showStoreSnack(context, 'تأمین‌کننده لازم است', error: true);
      return;
    }
    final products = ref.read(productListProvider);
    final items = <PurchaseItemInput>[];
    for (var i = 0; i < _titles.length; i++) {
      final title = _titles[i].text.trim();
      final qty =
          double.tryParse(_qtys[i].text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      final price = parseToman(_prices[i].text) ?? 0;
      if (title.isEmpty || qty <= 0) continue;
      // تطبیق با کاتالوگ (برای اثر موجودی)
      String productId = _productIds[i] ?? '';
      if (productId.isEmpty) {
        for (final p in products) {
          if (p.name.trim() == title) {
            productId = p.id;
            break;
          }
        }
      }
      items.add(PurchaseItemInput(
        productId: productId,
        title: title,
        quantity: qty,
        unitPrice: price,
      ));
    }
    if (items.isEmpty) {
      showStoreSnack(context, 'حداقل یک قلم معتبر وارد کنید', error: true);
      return;
    }
    try {
      core.purchases.create(
        supplierId: _supplierId.value,
        date: DateTime.now().toIso8601String().substring(0, 10),
        items: items,
        discount: parseToman(_discount.text) ?? 0,
        shipping: parseToman(_shipping.text) ?? 0,
        otherCosts: parseToman(_other.text) ?? 0,
        tax: parseToman(_tax.text) ?? 0,
        paidAmount: parseToman(_paid.text) ?? 0,
        accountId: 'acc-cash',
        number: _number.text.trim(),
      );
      if (mounted) {
        showStoreSnack(context, 'فاکتور خرید ثبت و موجودی به‌روز شد');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showStoreSnack(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = core.suppliers.list();
    final accounts = core.accounts.list(onlyActive: true);
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('خرید جدید')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('جمع فاکتور:', style: TextStyle(fontWeight: FontWeight.w800)),
                  Text(formatToman(_total),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.RubyPrimary)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('ثبت خرید و ورود موجودی'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          DropdownButtonFormField<String>(
            value: _supplierId.value.isEmpty ? null : _supplierId.value,
            items: [
              for (final s in suppliers) DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) => setState(() => _supplierId.value = v ?? ''),
            decoration: const InputDecoration(labelText: 'تأمین‌کننده *'),
          ),
          const SizedBox(height: 10),
          TextField(
              controller: _number,
              decoration: const InputDecoration(labelText: 'شمارهٔ فاکتور خرید')),
          const SectionHeader('اقلام خرید'),
          for (var i = 0; i < _titles.length; i++)
            Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _titles[i],
                            decoration: const InputDecoration(labelText: 'نام کالا', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _qtys[i],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'تعداد', isDense: true),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppTheme.RubyError, size: 20),
                          onPressed: () => _removeRow(i),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TomanField(controller: _prices[i], label: 'قیمت واحد خرید'),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _addRow,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('افزودن قلم'),
            ),
          ),
          const SectionHeader('هزینه‌ها و تخفیف'),
          TomanField(controller: _discount, label: 'تخفیف'),
          const SizedBox(height: 8),
          TomanField(controller: _shipping, label: 'هزینهٔ حمل'),
          const SizedBox(height: 8),
          TomanField(controller: _other, label: 'سایر هزینه‌ها'),
          const SizedBox(height: 8),
          TomanField(controller: _tax, label: 'مالیات (در صورت فعال بودن)'),
          const SizedBox(height: 8),
          TomanField(controller: _paid, label: 'پرداخت نقدی الان (۰ = نسیه)'),
          const SizedBox(height: 6),
          Text(
            accounts.isEmpty
                ? 'پرداخت از «صندوق فروشگاه» ثبت می‌شود'
                : 'پرداخت از حساب «${accounts.first.name}» ثبت می‌شود',
            style: const TextStyle(fontSize: 10.5, color: AppTheme.RubyTextSecondary),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}
