import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice_model.dart';
import '../models/invoice_item_model.dart';
import '../core/utils/prefs_store.dart';
import '../database/app_database.dart';
import 'customer_provider.dart';

final invoiceListProvider =
    StateNotifierProvider<InvoiceListNotifier, List<InvoiceModel>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final customers = ref.read(customerListProvider.notifier);
  return InvoiceListNotifier(db, customers);
});

final invoiceEditRequestProvider = StateProvider<InvoiceModel?>((ref) => null);

class InvoiceListNotifier extends StateNotifier<List<InvoiceModel>> {
  final AppDatabase? db;
  final CustomerListNotifier? customers;
  late final Future<void> _hydrated;

  InvoiceListNotifier([this.db, this.customers]) : super(const []) {
    _hydrated = _hydrate();
  }

  Future<void> ensureLoaded() => _hydrated;

  Future<void> _hydrate() async {
    state = await PrefsStore.loadInvoices();
  }

  Future<void> saveInvoice(InvoiceModel invoice) async {
    await _hydrated;
    final index = state.indexWhere((item) => item.id == invoice.id);
    final previous = index >= 0 ? state[index] : null;
    state = index >= 0
        ? [
            for (var i = 0; i < state.length; i++)
              if (i == index) invoice else state[i],
          ]
        : [...state, invoice];

    await PrefsStore.saveInvoices(state);
    await customers?.applyInvoiceChange(previous, invoice);
    await db?.persistInvoiceRecord(
      invoice.id,
      invoice.number,
      invoice.customerName,
      invoice.date,
      invoice.totalAmount,
    );
  }

  Future<void> deleteInvoice(String id) async {
    await _hydrated;
    final index = state.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final removed = state[index];
    state = state.where((item) => item.id != id).toList();
    await PrefsStore.saveInvoices(state);
    await customers?.applyInvoiceChange(removed, null);
    await db?.deleteInvoiceRecord(id);
  }

  Future<InvoiceModel> copyInvoice(InvoiceModel source) async {
    await _hydrated;

    var nextNumber = 1;
    for (final invoice in state) {
      final number = int.tryParse(_toEnglishDigits(invoice.number).trim());
      if (number != null && number >= nextNumber) nextNumber = number + 1;
    }

    // پرداخت‌های ثبت‌شده روی فاکتور مبدأ نباید به نسخهٔ کپی منتقل شوند؛
    // فقط بیعانهٔ خود فاکتور می‌ماند.
    final isCredit = source.type != 'proforma' && source.paymentType != 'cash';
    final copyRemaining = isCredit ? source.totalAmount : source.remainingAmount;
    final copyPaid = isCredit ? source.deposit : source.paidAmount;
    final copyStatus = !isCredit
        ? source.status
        : (copyRemaining <= 0
            ? 'paid'
            : (copyPaid > 0 ? 'partial' : 'unpaid'));

    final copied = InvoiceModel(
      id: 'inv-${DateTime.now().microsecondsSinceEpoch}-copy',
      number: nextNumber.toString(),
      customerId: source.customerId,
      customerName: source.customerName,
      customerPhone: source.customerPhone,
      type: source.type,
      paymentType: source.paymentType,
      status: copyStatus,
      date: source.date,
      items: source.items
          .map(
            (item) => InvoiceItemModel(
              id: '${item.id}-copy-${DateTime.now().microsecondsSinceEpoch}',
              title: item.title,
              quantity: item.quantity,
              unit: item.unit,
              unitPrice: item.unitPrice,
              totalPrice: item.totalPrice,
            ),
          )
          .toList(),
      subtotal: source.subtotal,
      discountPercent: source.discountPercent,
      discountAmount: source.discountAmount,
      shippingFee: source.shippingFee,
      previousDebt: source.previousDebt,
      deposit: source.deposit,
      totalAmount: source.totalAmount,
      paidAmount: copyPaid,
      remainingAmount: copyRemaining,
      notes: source.notes,
      cardNumber: source.cardNumber,
      cardBank: source.cardBank,
      cardOwner: source.cardOwner,
      createdAt: source.createdAt,
    );

    await saveInvoice(copied);
    return copied;
  }

  String _toEnglishDigits(String value) {
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    var result = value;
    for (var i = 0; i < persian.length; i++) {
      result = result.replaceAll(persian[i], '$i');
    }
    return result;
  }

  Future<void> convertProformaToInvoice(
    String id, {
    required String paymentType,
  }) async {
    await _hydrated;
    if (paymentType != 'cash' && paymentType != 'non_cash') {
      throw ArgumentError.value(paymentType, 'paymentType');
    }

    final index = state.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final previous = state[index];

    // پیش‌فاکتور ممکن است قبلاً با هر نوع پرداختی ذخیره شده باشد. انتخابی که
    // کاربر هنگام تبدیل انجام می‌دهد مرجع نهایی است و مبالغ باید از نو و بدون
    // باقی‌ماندن وضعیت پرداخت قبلی محاسبه شوند.
    final isCash = paymentType == 'cash';
    final paidAmount = isCash ? previous.totalAmount : previous.deposit;
    final remainingAmount = isCash ? 0.0 : previous.totalAmount;
    final status = isCash
        ? 'paid'
        : (previous.deposit > 0 ? 'partial' : 'unpaid');

    final updated = InvoiceModel(
      id: previous.id,
      number: previous.number,
      customerId: previous.customerId,
      customerName: previous.customerName,
      customerPhone: previous.customerPhone,
      type: 'sale',
      paymentType: paymentType,
      status: status,
      date: previous.date,
      items: previous.items,
      subtotal: previous.subtotal,
      discountPercent: previous.discountPercent,
      discountAmount: previous.discountAmount,
      shippingFee: previous.shippingFee,
      previousDebt: previous.previousDebt,
      deposit: previous.deposit,
      totalAmount: previous.totalAmount,
      paidAmount: paidAmount,
      remainingAmount: remainingAmount,
      notes: previous.notes,
      cardNumber: previous.cardNumber,
      cardBank: previous.cardBank,
      cardOwner: previous.cardOwner,
      createdAt: previous.createdAt,
    );
    await saveInvoice(updated);
  }

  Future<void> recordPayment(String id, double amount) async {
    await _hydrated;
    if (amount <= 0) return;
    final index = state.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final previous = state[index];
    // `totalAmount` in dashboard invoices is already net of the deposit, while
    // `paidAmount` also records that deposit. Recomputing remaining as
    // total-minus-paid would therefore subtract the deposit twice. Payments
    // must reduce the persisted remaining amount directly.
    final appliedAmount = amount.clamp(0, previous.remainingAmount).toDouble();
    final paidAmount = previous.paidAmount + appliedAmount;
    final remaining = (previous.remainingAmount - appliedAmount)
        .clamp(0, double.infinity)
        .toDouble();
    final updated = InvoiceModel(
      id: previous.id,
      number: previous.number,
      customerId: previous.customerId,
      customerName: previous.customerName,
      customerPhone: previous.customerPhone,
      type: previous.type,
      paymentType: previous.paymentType,
      status: remaining <= 0 ? 'paid' : 'partial',
      date: previous.date,
      items: previous.items,
      subtotal: previous.subtotal,
      discountPercent: previous.discountPercent,
      discountAmount: previous.discountAmount,
      shippingFee: previous.shippingFee,
      previousDebt: previous.previousDebt,
      deposit: previous.deposit,
      totalAmount: previous.totalAmount,
      paidAmount: paidAmount,
      remainingAmount: remaining,
      notes: previous.notes,
      cardNumber: previous.cardNumber,
      cardBank: previous.cardBank,
      cardOwner: previous.cardOwner,
      createdAt: previous.createdAt,
    );
    await saveInvoice(updated);
  }
}
