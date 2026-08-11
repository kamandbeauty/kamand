import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/jalali_helper.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../models/invoice_model.dart';
import '../../models/invoice_item_model.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/app_providers.dart';
import 'invoice_preview_screen.dart';

class InvoiceCreateScreen extends ConsumerStatefulWidget {
  final InvoiceModel? editInvoice;
  const InvoiceCreateScreen({super.key, this.editInvoice});

  @override
  ConsumerState<InvoiceCreateScreen> createState() => _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends ConsumerState<InvoiceCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _number;
  late String _customerName;
  late String _customerPhone;
  late String _date;
  late String _type;
  late String _paymentType;
  String? _editId;

  @override
  void initState() {
    super.initState();
    final e = widget.editInvoice;
    if (e != null) {
      _editId = e.id;
      _number = e.number;
      _customerName = e.customerName;
      _customerPhone = e.customerPhone;
      _date = e.date;
      _type = e.type;
      _paymentType = e.paymentType;
      _items = List.from(e.items.isEmpty ? _items : e.items);
      _discountAmount = e.discountAmount;
      _shippingFee = e.shippingFee;
      _notes = e.notes;
    } else {
      _number = '1004';
      _customerName = 'رضا محمدی';
      _customerPhone = '09121112233';
      _date = JalaliHelper.getTodayJalali();
      _type = 'sale';
      _paymentType = 'cash';
    }
  }

  List<InvoiceItemModel> _items = [
    InvoiceItemModel(
      id: '1',
      title: 'دان قهوه برزیل',
      quantity: 1,
      unit: 'بسته',
      unitPrice: 520000,
      totalPrice: 520000,
    ),
  ];

  double _discountAmount = 0;
  double _shippingFee = 0;
  String _notes = 'با تشکر از خرید شما';

  double get _subtotal => _items.fold(0, (sum, i) => sum + i.totalPrice);
  double get _totalAmount => (_subtotal - _discountAmount + _shippingFee).clamp(0, double.infinity);

  void _addItem() {
    setState(() {
      _items.add(
        InvoiceItemModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'آیتم جدید',
          quantity: 1,
          unit: 'عدد',
          unitPrice: 100000,
          totalPrice: 100000,
        ),
      );
    });
  }

  void _saveInvoice() {
    final cleanItems = _items
        .where((e) => e.title.trim().isNotEmpty || e.unitPrice > 0)
        .toList();
    if (cleanItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حداقل یک قلم کالا اضافه کنید')),
      );
      return;
    }

    final customers = ref.read(customerListProvider);
    String? existingId;
    for (final c in customers) {
      if (c.name == _customerName) {
        existingId = c.id;
        break;
      }
    }
    final custId = widget.editInvoice?.customerId ??
        existingId ??
        'c-${DateTime.now().millisecondsSinceEpoch}';
    final business = ref.read(businessProvider);
    final cardNum = business.bankCards.isNotEmpty ? business.bankCards.first : '';

    final isEdit = _editId != null;
    final newInv = InvoiceModel(
      id: isEdit ? _editId! : 'inv-${DateTime.now().millisecondsSinceEpoch}',
      number: _number,
      customerId: custId,
      customerName: _customerName.trim().isEmpty ? 'مشتری عمومی' : _customerName.trim(),
      customerPhone: _customerPhone,
      type: _type,
      paymentType: _paymentType,
      status: _type == 'proforma'
          ? 'proforma'
          : (_paymentType == 'cash' ? 'paid' : 'unpaid'),
      date: _date,
      items: cleanItems,
      subtotal: _subtotal,
      discountPercent: 0,
      discountAmount: _discountAmount,
      shippingFee: _shippingFee,
      previousDebt: 0,
      deposit: 0,
      totalAmount: _totalAmount,
      paidAmount: _paymentType == 'cash' ? _totalAmount : 0,
      remainingAmount: _paymentType == 'cash' ? 0 : _totalAmount,
      notes: _notes,
      cardNumber: cardNum,
      createdAt: _date,
    );

    ref.read(invoiceListProvider.notifier).saveInvoice(newInv);
    if (_type == 'sale' && _paymentType != 'cash' && newInv.remainingAmount > 0) {
      ref.read(customerListProvider.notifier).updateBalance(custId, newInv.remainingAmount);
    }

    // بعد از ذخیره → صفحه نمایش فاکتور
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => InvoicePreviewScreen(invoice: newInv)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _editId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'ویرایش فاکتور' : 'ایجاد فاکتور جدید'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer & Invoice Metadata
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: _customerName,
                        decoration: const InputDecoration(labelText: 'نام مشتری'),
                        onChanged: (v) => _customerName = v,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: _number,
                              decoration: const InputDecoration(labelText: 'شماره فاکتور'),
                              onChanged: (v) => _number = v,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: _date,
                              decoration: const InputDecoration(labelText: 'تاریخ شمسی'),
                              onChanged: (v) => _date = v,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Items Table
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('جدول اقلام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('افزودن آیتم'),
                  ),
                ],
              ),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                itemBuilder: (ctx, idx) {
                  final item = _items[idx];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          TextFormField(
                            initialValue: item.title,
                            decoration: const InputDecoration(labelText: 'عنوان کالا / خدمت'),
                            onChanged: (v) {
                              _items[idx] = InvoiceItemModel(
                                id: item.id,
                                title: v,
                                quantity: item.quantity,
                                unit: item.unit,
                                unitPrice: item.unitPrice,
                                totalPrice: item.quantity * item.unitPrice,
                              );
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: item.quantity.toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'مقدار'),
                                  onChanged: (v) {
                                    final q = double.tryParse(v) ?? 1;
                                    _items[idx] = InvoiceItemModel(
                                      id: item.id,
                                      title: item.title,
                                      quantity: q,
                                      unit: item.unit,
                                      unitPrice: item.unitPrice,
                                      totalPrice: q * item.unitPrice,
                                    );
                                    setState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: item.unitPrice.toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'قیمت واحد'),
                                  onChanged: (v) {
                                    final p = double.tryParse(v) ?? 0;
                                    _items[idx] = InvoiceItemModel(
                                      id: item.id,
                                      title: item.title,
                                      quantity: item.quantity,
                                      unit: item.unit,
                                      unitPrice: p,
                                      totalPrice: item.quantity * p,
                                    );
                                    setState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Summary
              Card(
                color: AppTheme.primaryBlue,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('جمع کل نهایی:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            PersianNumberFormatter.formatCurrency(_totalAmount),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveInvoice,
                  icon: Icon(isEdit ? Icons.check : Icons.save),
                  label: Text(isEdit ? 'ذخیره تغییرات' : 'ذخیره فاکتور'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
