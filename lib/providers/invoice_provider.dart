import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice_model.dart';
import '../models/invoice_item_model.dart';
import '../core/utils/prefs_store.dart';
import '../database/app_database.dart';

final invoiceListProvider =
    StateNotifierProvider<InvoiceListNotifier, List<InvoiceModel>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return InvoiceListNotifier(db);
});

final invoiceEditRequestProvider = StateProvider<InvoiceModel?>((ref) => null);

class InvoiceListNotifier extends StateNotifier<List<InvoiceModel>> {
  final AppDatabase? db;
  late final Future<void> _hydrated;

  InvoiceListNotifier([this.db]) : super(const []) {
    _hydrated = _hydrate();
  }

  Future<void> ensureLoaded() => _hydrated;

  Future<void> _hydrate() async {
    state = await PrefsStore.loadInvoices();
  }

  void _persist() {
    PrefsStore.saveInvoices(state);
  }

  Future<void> saveInvoice(InvoiceModel invoice) async {
    await _hydrated;
    final index = state.indexWhere((i) => i.id == invoice.id);
    state = index >= 0
        ? [
            for (int i = 0; i < state.length; i++)
              if (i == index) invoice else state[i],
          ]
        : [...state, invoice];
    await PrefsStore.saveInvoices(state);
    db?.persistInvoiceRecord(
      invoice.id,
      invoice.number,
      invoice.customerName,
      invoice.date,
      invoice.totalAmount,
    );
  }

  Future<void> deleteInvoice(String id) async {
    await _hydrated;
    state = state.where((i) => i.id != id).toList();
    await PrefsStore.saveInvoices(state);
  }

  Future<InvoiceModel> copyInvoice(InvoiceModel source) async {
    await _hydrated;

    // شماره بعدی: max موجود +1، با در نظر گرفتن startingInvoiceNum
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
    // اگر شماره شروع تکراری بود، افزایش بده
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

    state = [...state, copied];
    await PrefsStore.saveInvoices(state);
    db?.persistInvoiceRecord(
      copied.id,
      copied.number,
      copied.customerName,
      copied.date,
      copied.totalAmount,
    );
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

  void convertProformaToInvoice(String id) {
    _hydrated.then((_) {
      state = state.map((item) {
        if (item.id != id) return item;
        return InvoiceModel(
          id: item.id,
          number: item.number,
          customerId: item.customerId,
          customerName: item.customerName,
          customerPhone: item.customerPhone,
          type: 'sale',
          paymentType: item.paymentType,
          status: item.remainingAmount == 0 ? 'paid' : 'unpaid',
          date: item.date,
          items: item.items,
          subtotal: item.subtotal,
          discountPercent: item.discountPercent,
          discountAmount: item.discountAmount,
          shippingFee: item.shippingFee,
          previousDebt: item.previousDebt,
          deposit: item.deposit,
          totalAmount: item.totalAmount,
          paidAmount: item.paidAmount,
          remainingAmount: item.remainingAmount,
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
      }).toList();
      _persist();
    });
    // optimistic
    state = state.map((item) {
      if (item.id != id) return item;
      return InvoiceModel(
        id: item.id,
        number: item.number,
        customerId: item.customerId,
        customerName: item.customerName,
        customerPhone: item.customerPhone,
        type: 'sale',
        paymentType: item.paymentType,
        status: item.remainingAmount == 0 ? 'paid' : 'unpaid',
        date: item.date,
        items: item.items,
        subtotal: item.subtotal,
        discountPercent: item.discountPercent,
        discountAmount: item.discountAmount,
        shippingFee: item.shippingFee,
        previousDebt: item.previousDebt,
        deposit: item.deposit,
        totalAmount: item.totalAmount,
        paidAmount: item.paidAmount,
        remainingAmount: item.remainingAmount,
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
    }).toList();
  }

  void recordPayment(String id, double amount) {
    if (amount <= 0) return;
    _hydrated.then((_) {
      state = state.map((item) {
        if (item.id != id) return item;
        final safeAmount = amount.clamp(0, item.remainingAmount).toDouble();
        final remaining = item.totalAmount - (item.paidAmount + safeAmount);
        return InvoiceModel(
          id: item.id,
          number: item.number,
          customerId: item.customerId,
          customerName: item.customerName,
          customerPhone: item.customerPhone,
          type: item.type,
          paymentType: item.paymentType,
          status: remaining <= 0 ? 'paid' : 'partial',
          date: item.date,
          items: item.items,
          subtotal: item.subtotal,
          discountPercent: item.discountPercent,
          discountAmount: item.discountAmount,
          shippingFee: item.shippingFee,
          previousDebt: item.previousDebt,
          deposit: item.deposit,
          totalAmount: item.totalAmount,
          paidAmount: item.paidAmount + safeAmount,
          remainingAmount: remaining < 0 ? 0 : remaining,
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
      }).toList();
      _persist();
    });
    state = state.map((item) {
      if (item.id != id) return item;
      final safeAmount = amount.clamp(0, item.remainingAmount).toDouble();
      final remaining = item.totalAmount - (item.paidAmount + safeAmount);
      return InvoiceModel(
        id: item.id,
        number: item.number,
        customerId: item.customerId,
        customerName: item.customerName,
        customerPhone: item.customerPhone,
        type: item.type,
        paymentType: item.paymentType,
        status: remaining <= 0 ? 'paid' : 'partial',
        date: item.date,
        items: item.items,
        subtotal: item.subtotal,
        discountPercent: item.discountPercent,
        discountAmount: item.discountAmount,
        shippingFee: item.shippingFee,
        previousDebt: item.previousDebt,
        deposit: item.deposit,
        totalAmount: item.totalAmount,
        paidAmount: item.paidAmount + safeAmount,
        remainingAmount: remaining < 0 ? 0 : remaining,
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
    }).toList();
  }
}
