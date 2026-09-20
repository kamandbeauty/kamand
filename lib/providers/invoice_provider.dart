import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/persistent_list.dart';
import '../core/utils/prefs_store.dart';
import '../database/app_database.dart';
import '../models/invoice_item_model.dart';
import '../models/invoice_model.dart';

final invoiceListProvider =
    StateNotifierProvider<InvoiceListNotifier, List<InvoiceModel>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return InvoiceListNotifier(db);
});

final invoiceEditRequestProvider = StateProvider<InvoiceModel?>((ref) => null);

class InvoiceListNotifier extends PersistentListNotifier<InvoiceModel> {
  InvoiceListNotifier([this.db]);

  final AppDatabase? db;

  @override
  Future<List<InvoiceModel>> readFromStorage() => PrefsStore.loadInvoices();

  @override
  Future<void> writeToStorage(List<InvoiceModel> items) async {
    await PrefsStore.saveInvoices(items);
    await db?.mirrorInvoices(items);
  }

  Future<void> saveInvoice(InvoiceModel invoice) async {
    await ensureLoaded();
    mutate(
      (invoices) => invoices.any((item) => item.id == invoice.id)
          ? [for (final item in invoices) if (item.id == invoice.id) invoice else item]
          : [...invoices, invoice],
    );
    await flushWrites();
  }

  Future<void> deleteInvoice(String id) async {
    await ensureLoaded();
    mutate((invoices) => invoices.where((item) => item.id != id).toList());
    await flushWrites();
  }

  /// کپی فاکتور با شماره‌ی بعدی آزاد. شماره‌های فاکتورهای قبلی (که کاربر
  /// در نسخه‌های قدیمی ثبت کرده) محفوظ می‌مانند.
  Future<InvoiceModel> copyInvoice(InvoiceModel source) async {
    await ensureLoaded();

    var nextNumber = 1;
    try {
      final settings = await PrefsStore.loadSettings();
      if (settings != null && settings.startingInvoiceNum > nextNumber) {
        nextNumber = settings.startingInvoiceNum;
      }
    } catch (_) {}

    final used = <int>{};
    for (final invoice in state) {
      final n = int.tryParse(_toEnglishDigits(invoice.number).trim());
      if (n != null) used.add(n);
    }
    for (final invoice in state) {
      final number = int.tryParse(_toEnglishDigits(invoice.number).trim());
      if (number != null && number >= nextNumber) nextNumber = number + 1;
    }
    while (used.contains(nextNumber)) {
      nextNumber++;
      if (nextNumber > 999999999) break;
    }

    final copied = InvoiceModel(
      id: 'inv-${DateTime.now().millisecondsSinceEpoch}-copy',
      number: nextNumber.toString(),
      customerId: source.customerId,
      customerName: source.customerName,
      customerPhone: source.customerPhone,
      type: source.type,
      paymentType: source.paymentType,
      status: source.status,
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
              buyPrice: item.buyPrice,
              productId: item.productId,
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
      paidAmount: source.paidAmount,
      remainingAmount: source.remainingAmount,
      notes: source.notes,
      cardNumber: source.cardNumber,
      cardBank: source.cardBank,
      cardOwner: source.cardOwner,
      createdAt: source.createdAt,
      supplierId: source.supplierId,
      supplierName: source.supplierName,
      totalBuyAmount: source.totalBuyAmount,
      profitAmount: source.profitAmount,
      expenseAmount: source.expenseAmount,
      expenseTitle: source.expenseTitle,
    );

    mutate((invoices) => [...invoices, copied]);
    await flushWrites();
    return copied;
  }

  /// تبدیل پیش‌فاکتور به فاکتور فروش.
  void convertProformaToInvoice(String id) {
    mutate(
      (invoices) => [
        for (final item in invoices)
          if (item.id == id)
            _rebuild(
              item,
              type: 'sale',
              status: item.remainingAmount == 0 ? 'paid' : 'unpaid',
            )
          else
            item,
      ],
    );
  }

  /// ثبت دریافت/پرداخت روی فاکتور.
  /// مقدار پرداخت فقط یک بار به فاکتور اضافه می‌شود؛ این ایراد در نسخه‌ی
  /// قبل باعث دو برابر شدن پرداخت‌ها هنگام به‌روزرسانی می‌شد.
  void recordPayment(String id, double amount) {
    if (amount <= 0) return;
    mutate(
      (invoices) => [
        for (final item in invoices)
          if (item.id == id)
            _registerPayment(item, amount)
          else
            item,
      ],
    );
  }

  InvoiceModel _registerPayment(InvoiceModel item, double amount) {
    final safeAmount = amount.clamp(0, item.remainingAmount).toDouble();
    if (safeAmount <= 0 && item.remainingAmount <= 0) return item;
    final paid = item.paidAmount + safeAmount;
    final remaining = item.totalAmount - paid;
    return _rebuild(
      item,
      status: remaining <= 0 ? 'paid' : 'partial',
      paidAmount: paid,
      remainingAmount: remaining < 0 ? 0 : remaining,
    );
  }

  InvoiceModel _rebuild(
    InvoiceModel item, {
    String? type,
    String? status,
    double? paidAmount,
    double? remainingAmount,
  }) {
    return InvoiceModel(
      id: item.id,
      number: item.number,
      customerId: item.customerId,
      customerName: item.customerName,
      customerPhone: item.customerPhone,
      type: type ?? item.type,
      paymentType: item.paymentType,
      status: status ?? item.status,
      date: item.date,
      items: item.items,
      subtotal: item.subtotal,
      discountPercent: item.discountPercent,
      discountAmount: item.discountAmount,
      shippingFee: item.shippingFee,
      previousDebt: item.previousDebt,
      deposit: item.deposit,
      totalAmount: item.totalAmount,
      paidAmount: paidAmount ?? item.paidAmount,
      remainingAmount: remainingAmount ?? item.remainingAmount,
      notes: item.notes,
      cardNumber: item.cardNumber,
      cardBank: item.cardBank,
      cardOwner: item.cardOwner,
      createdAt: item.createdAt,
      supplierId: item.supplierId,
      supplierName: item.supplierName,
      totalBuyAmount: item.totalBuyAmount,
      profitAmount: item.profitAmount,
      expenseAmount: item.expenseAmount,
      expenseTitle: item.expenseTitle,
    );
  }

  String _toEnglishDigits(String value) {
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    var result = value;
    for (var i = 0; i < persian.length; i++) {
      result = result.replaceAll(persian[i], '$i');
    }
    return result;
  }
}
