import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice_model.dart';
import '../models/invoice_item_model.dart';
import '../core/utils/prefs_store.dart';
import '../database/app_database.dart';
import '../store/bridge/sales_ledger_bridge.dart';

final invoiceListProvider =
    StateNotifierProvider<InvoiceListNotifier, List<InvoiceModel>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return InvoiceListNotifier(db);
});

final invoiceEditRequestProvider = StateProvider<InvoiceModel?>((ref) => null);

class InvoiceListNotifier extends StateNotifier<List<InvoiceModel>> {
  final AppDatabase? db;
  late final Future<void> _hydrated;

  // پل مالی فروشگاه — با آماده‌شدن هستهٔ حسابداری متصل می‌شود (اختیاری)
  SalesLedgerBridge? _storeBridge;
  void Function(String customerId)? _onCustomerLedgerChanged;
  void Function()? _onStockChanged;

  InvoiceListNotifier([this.db]) : super(const []) {
    _hydrated = _hydrate();
  }

  void attachStoreBridge(
    SalesLedgerBridge? bridge, {
    void Function(String customerId)? onCustomerLedgerChanged,
    void Function()? onStockChanged,
  }) {
    _storeBridge = bridge;
    _onCustomerLedgerChanged = onCustomerLedgerChanged;
    _onStockChanged = onStockChanged;
  }

  void _bridgeNotifyCustomer(String customerId) {
    if (customerId.isEmpty) return;
    _onCustomerLedgerChanged?.call(customerId);
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
    // آینهٔ مالی: دفتر کل + موجودی + ماندهٔ مشتق مشتری (در صورت اتصال هسته)
    try {
      _storeBridge?.onInvoiceSaved(invoice);
      if (invoice.type == 'sale') {
        _bridgeNotifyCustomer(invoice.customerId);
        _onStockChanged?.call();
      }
    } catch (_) {
      // خطای پل هرگز ذخیرهٔ سند قبلی را متوقف نمی‌کند؛ ردیابی از audit log
    }
  }

  Future<void> deleteInvoice(String id) async {
    await _hydrated;
    InvoiceModel? removed;
    for (final i in state) {
      if (i.id == id) {
        removed = i;
        break;
      }
    }
    state = state.where((i) => i.id != id).toList();
    await PrefsStore.saveInvoices(state);
    try {
      _storeBridge?.onInvoiceDeleted(id);
      if (removed != null && removed.type == 'sale') {
        _bridgeNotifyCustomer(removed.customerId);
        _onStockChanged?.call();
      }
    } catch (_) {}
  }

  Future<InvoiceModel> copyInvoice(InvoiceModel source) async {
    await _hydrated;

    var nextNumber = 1;
    for (final invoice in state) {
      final number = int.tryParse(_toEnglishDigits(invoice.number).trim());
      if (number != null && number >= nextNumber) nextNumber = number + 1;
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
    InvoiceModel? converted;
    state = state.map((item) {
      if (item.id != id) return item;
      final updated = InvoiceModel(
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
      converted = updated;
      return updated;
    }).toList();
    _persist();
    try {
      if (converted != null) {
        _storeBridge?.onInvoiceSaved(converted!);
        _bridgeNotifyCustomer(converted!.customerId);
        _onStockChanged?.call();
      }
    } catch (_) {}
  }

  void recordPayment(String id, double amount) {
    InvoiceModel? target;
    state = state.map((item) {
      if (item.id != id) return item;
      final remaining = item.totalAmount - (item.paidAmount + amount);
      final updated = InvoiceModel(
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
      target = updated;
      return updated;
    }).toList();
    _persist();
    try {
      _storeBridge?.onInvoicePayment(id, amount);
      if (target != null) {
        _bridgeNotifyCustomer(target!.customerId);
      }
    } catch (_) {}
  }
}
