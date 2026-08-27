import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/customer_model.dart';
import '../../providers/customer_provider.dart';
import '../../core/utils/jalali_helper.dart' as jh;
import '../orders/order_repository.dart';
import '../providers/store_providers.dart';
import '../store_core.dart';
import 'store_ui_helpers.dart';

/// سفارشات ارسال‌نشده — فهرست + جزئیات کامل + ویرایش
/// نام و شمارهٔ مشتری هنگام ثبت/ویرایش در بانک مشتریان ذخیره می‌شود
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  bool _showAll = false; // false = فقط ارسال‌نشده
  List<OrderEntity> _orders = [];

  Future<void> _reload(StoreCore core) async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    try {
      setState(() {
        _orders = core.orders.list(status: _showAll ? null : 'PENDING');
      });
    } catch (e) {
      showStoreSnack(context, 'خطا: $e', error: true);
    }
  }

  /// ذخیرهٔ نام و شماره در بانک مشتریان (اگر جدید باشد)
  void _upsertCustomer(String name, String phone) {
    final notifier = ref.read(customerListProvider.notifier);
    final existing = ref.read(customerListProvider);
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    for (final c in existing) {
      if (c.name.trim() == cleanName) {
        if (phone.trim().isNotEmpty && c.mobile.trim() != phone.trim()) {
          notifier.updateCustomer(CustomerModel(
            id: c.id,
            name: c.name,
            mobile: phone.trim(),
            phone: c.phone,
            address: c.address,
            notes: c.notes,
            balance: c.balance,
            createdAt: c.createdAt,
          ));
        }
        return; // موجود بود
      }
      if (phone.trim().isNotEmpty &&
          c.mobile.trim() == phone.trim() &&
          c.mobile.trim().isNotEmpty) {
        return; // با شماره موجود است
      }
    }
    notifier.addCustomer(CustomerModel(
      id: 'customer-${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      mobile: phone.trim(),
      phone: '',
      address: '',
      notes: 'ایجاد‌شده خودکار از سفارش',
      balance: 0,
      createdAt: jh.JalaliHelper.getTodayJalali(),
    ));
  }

  Future<void> _openEditor(StoreCore core, {OrderEntity? edit}) async {
    final name = TextEditingController(text: edit?.customerName ?? '');
    final phone = TextEditingController(text: edit?.customerPhone ?? '');
    final address = TextEditingController(text: edit?.address ?? '');
    final number = TextEditingController(text: edit?.number ?? '');
    final notesCtrl = TextEditingController(text: edit?.notes ?? '');
    final discount = TextEditingController(
        text: edit == null || edit.discount == 0 ? '' : edit.discount.toString());
    final shipping = TextEditingController(
        text: edit == null || edit.shipping == 0 ? '' : edit.shipping.toString());

    final titles = <TextEditingController>[
      for (final i in edit?.items ?? const []) TextEditingController(text: i.title)
    ];
    final qtys = <TextEditingController>[
      for (final i in edit?.items ?? const [])
        TextEditingController(text: i.quantity.toString())
    ];
    final prices = <TextEditingController>[
      for (final i in edit?.items ?? const [])
        TextEditingController(text: i.unitPrice.toString())
    ];
    if (titles.isEmpty) {
      titles.add(TextEditingController());
      qtys.add(TextEditingController(text: '1'));
      prices.add(TextEditingController());
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 18, 16, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.85,
            child: Column(
              children: [
                Text(edit == null ? 'ثبت سفارش جدید' : 'ویرایش سفارش',
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                                controller: name,
                                decoration: const InputDecoration(
                                    labelText: 'نام مشتری *', isDense: true)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                                controller: phone,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                    labelText: 'شماره مشتری', isDense: true)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                          controller: address,
                          decoration: const InputDecoration(
                              labelText: 'آدرس ارسال', isDense: true)),
                      const SizedBox(height: 8),
                      TextField(
                          controller: number,
                          decoration: const InputDecoration(
                              labelText: 'شماره سفارش', isDense: true)),
                      const SizedBox(height: 10),
                      const Text('اقلام سفارش',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w900)),
                      for (var i = 0; i < titles.length; i++)
                        Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                      controller: titles[i],
                                      decoration: const InputDecoration(
                                          labelText: 'کالا', isDense: true)),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextField(
                                      controller: qtys[i],
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                          labelText: 'تعداد', isDense: true)),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                      controller: prices[i],
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                          labelText: 'قیمت', isDense: true)),
                                ),
                                IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 20, color: AppTheme.RubyError),
                                    onPressed: () => setSheet(() {
                                          titles.removeAt(i).dispose();
                                          qtys.removeAt(i).dispose();
                                          prices.removeAt(i).dispose();
                                        })),
                              ],
                            ),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('افزودن قلم'),
                          onPressed: () => setSheet(() {
                            titles.add(TextEditingController());
                            qtys.add(TextEditingController(text: '1'));
                            prices.add(TextEditingController());
                          }),
                        ),
                      ),
                      TomanField(controller: discount, label: 'تخفیف'),
                      const SizedBox(height: 8),
                      TomanField(controller: shipping, label: 'هزینهٔ ارسال'),
                      const SizedBox(height: 8),
                      TextField(
                          controller: notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              labelText: 'توضیحات (اختیاری)')),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final items = <OrderItem>[];
                          for (var i = 0; i < titles.length; i++) {
                            final t = titles[i].text.trim();
                            final q = double.tryParse(
                                    qtys[i].text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                                1;
                            final p = parseToman(prices[i].text) ?? 0;
                            if (t.isNotEmpty && q > 0) {
                              items.add(OrderItem(
                                  title: t, quantity: q, unitPrice: p));
                            }
                          }
                          if (name.text.trim().isEmpty || items.isEmpty) {
                            showStoreSnack(
                                ctx, 'نام مشتری و حداقل یک قلم الزامی است',
                                error: true);
                            return;
                          }
                          try {
                            final existing = ref.read(customerListProvider);
                            String cid = edit?.customerId ?? '';
                            for (final c in existing) {
                              if (c.name.trim() == name.text.trim()) {
                                cid = c.id;
                                break;
                              }
                            }
                            final oid = core.orders.save(
                              id: edit?.id,
                              number: number.text.trim(),
                              customerId: cid,
                              customerName: name.text.trim(),
                              customerPhone: phone.text.trim(),
                              address: address.text.trim(),
                              orderDate:
                                  DateTime.now().toIso8601String().substring(0, 10),
                              items: items,
                              discount: parseToman(discount.text) ?? 0,
                              shipping: parseToman(shipping.text) ?? 0,
                              notes: notesCtrl.text.trim(),
                              status: edit?.status ?? 'PENDING',
                            );
                            _upsertCustomer(name.text, phone.text);
                            Navigator.pop(ctx);
                            showStoreSnack(ctx, 'سفارش ذخیره شد');
                            _reload(core);
                          } catch (e) {
                            showStoreSnack(ctx, '$e', error: true);
                          }
                        },
                        child: const Text('ذخیره سفارش'),
                      ),
                    ),
                    if (edit != null && edit.isPending) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.RubySuccess),
                          onPressed: () async {
                            final ok = await confirmDialog(ctx,
                                title: 'علامت‌گذاری ارسال',
                                message:
                                    'سفارش ${edit.customerName} ارسال شد؟ از فهرست ارسال‌نشده‌ها خارج می‌شود.');
                            if (!ok) return;
                            core.orders.markShipped(edit.id);
                            Navigator.pop(ctx);
                            showStoreSnack(ctx, 'ارسال ثبت شد');
                            _reload(core);
                          },
                          child: const Text('ارسال شد'),
                        ),
                      ),
                    ],
                  ],
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
      title: _showAll ? 'همهٔ سفارشات' : 'سفارشات ارسال‌نشده',
      actions: [
        TextButton(
          onPressed: () {
            setState(() => _showAll = !_showAll);
          },
          child: Text(_showAll ? 'ارسال‌نشده‌ها' : 'همه',
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ],
      fab: FloatingActionButton.extended(
        onPressed: () async {
          final core = await ref.read(storeCoreProvider.future);
          _openEditor(core);
        },
        icon: const Icon(Icons.add),
        label: const Text('سفارش جدید'),
      ),
      body: (context, core) {
        if (_orders.isEmpty &&
            !_showAll) {
          // بارگذاری اولیه
          _reload(core);
        }
        return RefreshIndicator(
          onRefresh: () => _reload(core),
          child: _orders.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 90),
                  Icon(Icons.local_shipping_outlined,
                      size: 54, color: AppTheme.RubyTextSecondary),
                  SizedBox(height: 12),
                  Center(
                      child: Text('سفارش ارسال‌نشده‌ای نیست',
                          style:
                              TextStyle(color: AppTheme.RubyTextSecondary))),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _orders.length,
                  itemBuilder: (_, i) {
                    final o = _orders[i];
                    return Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        onTap: () => _openEditor(core, edit: o),
                        leading: CircleAvatar(
                          backgroundColor: o.isPending
                              ? AppTheme.RubyWarning.withValues(alpha: 0.13)
                              : AppTheme.RubySuccess.withValues(alpha: 0.13),
                          child: Icon(
                              o.isPending
                                  ? Icons.schedule
                                  : Icons.local_shipping,
                              color: o.isPending
                                  ? AppTheme.RubyWarning
                                  : AppTheme.RubySuccess,
                              size: 20),
                        ),
                        title: Text('${o.customerName} — ${formatToman(o.total)}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w900)),
                        subtitle: Text(
                          '${o.items.length} قلم${o.customerPhone.isEmpty ? '' : ' · ${o.customerPhone}'} · ${faDate(o.orderDate)}'
                          '${o.status != 'PENDING' ? ' · ${o.statusLabel}' : ''}',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        trailing: o.isPending
                            ? const Icon(Icons.edit, size: 18,
                                color: AppTheme.RubyPrimary)
                            : const Icon(Icons.check_circle,
                                size: 18, color: AppTheme.RubySuccess),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
