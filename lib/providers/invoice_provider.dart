import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice_model.dart';
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
    // اگر کاربر خیلی سریع ذخیره کند، hydrate نباید فهرست تازه را با لیست قدیمی
    // جایگزین کند و باعث ناپدید شدن فاکتور شود.
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

  void deleteInvoice(String id) {
    state = state.where((i) => i.id != id).toList();
    _persist();
  }

  void convertProformaToInvoice(String id) {
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
      );
    }).toList();
    _persist();
  }

  void recordPayment(String id, double amount) {
    state = state.map((item) {
      if (item.id != id) return item;
      final remaining = item.totalAmount - (item.paidAmount + amount);
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
        paidAmount: item.paidAmount + amount,
        remainingAmount: remaining < 0 ? 0 : remaining,
        notes: item.notes,
        cardNumber: item.cardNumber,
        cardBank: item.cardBank,
        cardOwner: item.cardOwner,
        createdAt: item.createdAt,
      );
    }).toList();
    _persist();
  }
}
