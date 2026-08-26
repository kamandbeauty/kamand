import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/invoice_model.dart';
import '../../providers/customer_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../bridge/sales_ledger_bridge.dart';
import '../store_core.dart';

/// هستهٔ فروشگاه — با اولین watch باز می‌شود و تا پایان عمر برنامه زنده می‌ماند
final storeCoreProvider = FutureProvider<StoreCore>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  final core = await StoreCore.open(
      p.join(dir.path, 'factor_ruby_store.sqlite'));

  // اتصال پل مالی به جریان‌های موجود (بدون تغییر رفتار قبلی)
  final invoices = ref.read(invoiceListProvider.notifier);
  final products = ref.read(productListProvider.notifier);
  final customers = ref.read(customerListProvider.notifier);

  core.bridge.productMatcher = (title) => products.findProductIdByTitle(title);

  invoices.attachStoreBridge(
    core.bridge,
    onCustomerLedgerChanged: (customerId) {
      final derived = core.bridge.derivedCustomerBalance(customerId);
      customers.setDerivedBalance(customerId, derived.toDouble());
    },
    onStockChanged: () {
      final snapshot = <String, double>{};
      for (final prod in ref.read(productListProvider)) {
        final s = core.inventory.state(prod.id);
        if (s != null) snapshot[prod.id] = s.currentQty;
      }
      products.applyDerivedStock(snapshot);
    },
  );

  products.attachHooks(onProductAdded: (productId) {
    // موجودی اولیهٔ کاتالوگ یک‌بار همگام می‌شود؛ تغییرات بعدی فقط از
    // InventoryRepository انجام می‌شود.
    core.inventory.ensureProduct(productId);
  });

  ref.onDispose(core.close);
  return core;
});

/// یکپارچه‌سازی لایهٔ فروشگاه با جریان‌های قبلی
class StoreIntegration {
  final Ref ref;
  StoreIntegration(this.ref);

  Future<StoreCore?> get core async {
    try {
      return await ref.read(storeCoreProvider.future);
    } catch (_) {
      return null;
    }
  }

  /// پس از ذخیرهٔ فاکتور از UIهای قدیمی — همگام‌سازی مانده و موجودی
  Future<void> afterInvoiceSaved(InvoiceModel invoice) async {
    final c = await core;
    if (c == null) return;
    try {
      await ref.read(invoiceListProvider.notifier).ensureLoaded();
      c.bridge.onInvoiceSaved(invoice);
      _resyncCustomer(c, invoice.customerId);
      _resyncProducts(c);
    } catch (e) {
      c.audit.log('BRIDGE_ERROR', 'invoice', invoice.id, '$e');
    }
  }

  void _resyncCustomer(StoreCore c, String customerId) {
    if (customerId.isEmpty) return;
    final derived = c.bridge.derivedCustomerBalance(customerId);
    ref.read(customerListProvider.notifier).setDerivedBalance(
          customerId,
          derived.toDouble(),
        );
  }

  void _resyncProducts(StoreCore c) {
    final snapshot = <String, double>{};
    for (final prod in ref.read(productListProvider)) {
      final s = c.inventory.state(prod.id);
      if (s != null) snapshot[prod.id] = s.currentQty;
    }
    products.applyDerivedStock(snapshot);
  }

  /// اعتبارسنجی یکتایی شمارهٔ فاکتور فعال (§42)
  Future<bool> isInvoiceNumberTaken(String number, {String? excludeId}) async {
    final c = await core;
    if (c == null) return false;
    return c.bridge.isInvoiceNumberTaken(number, excludeSourceId: excludeId);
  }
}

final storeIntegrationProvider =
    Provider<StoreIntegration>((ref) => StoreIntegration(ref));

/// تاریخ امروز میلادی ISO (برای کوئری‌های مالی)
String todayIso() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

/// فایل دیتابیس فروشگاه برای پشتیبان‌گیری/بازنشانی
Future<File?> storeDatabaseFile() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final f = File(p.join(dir.path, 'factor_ruby_store.sqlite'));
    return f.existsSync() ? f : null;
  } catch (_) {
    return null;
  }
}

