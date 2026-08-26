import 'package:flutter_test/flutter_test.dart';
import 'package:factor_ruby/store/core/ledger.dart';
import 'package:factor_ruby/store/store_core.dart';
import 'package:factor_ruby/store/suppliers/purchase_repository.dart';

void main() {
  late StoreCore core;
  late String supplierId;

  setUp(() {
    core = StoreCore.inMemory();
    supplierId = core.suppliers.save(name: 'تأمین‌کنندهٔ تست');
  });

  test('خرید: موجودی + بدهی + وضعیت تسویه', () {
    final purchase = core.purchases.create(
      supplierId: supplierId,
      date: '2026-01-01',
      items: const [
        PurchaseItemInput(productId: 'p1', title: 'کالا ۱', quantity: 10, unitPrice: 100_000),
        PurchaseItemInput(productId: 'p2', title: 'کالا ۲', quantity: 5, unitPrice: 200_000),
      ],
      discount: 50_000,
      shipping: 100_000,
    );
    expect(purchase.total, 2_050_000); // 2,000,000 - 50,000 + 100,000
    expect(core.inventory.currentQty('p1'), 10);
    expect(core.inventory.currentQty('p2'), 5);
    expect(core.suppliers.payable(supplierId), 2_050_000);

    core.suppliers.pay(
        supplierId: supplierId, amount: 1_000_000, date: '2026-01-02', accountId: 'acc-cash');
    expect(core.suppliers.payable(supplierId), 1_050_000);
    final updated = core.purchases.byId(purchase.id)!;
    expect(updated.paid, 1_000_000);
    expect(updated.status, 'partial');

    core.suppliers.pay(
        supplierId: supplierId, amount: 1_050_000, date: '2026-01-03', accountId: 'acc-cash');
    expect(core.suppliers.payable(supplierId), 0);
    expect(core.purchases.byId(purchase.id)!.status, 'paid');
  });

  test('توزیع هزینه‌های جانبی در بهای تمام‌شده', () {
    core.purchases.create(
      supplierId: supplierId,
      date: '2026-01-01',
      items: const [
        PurchaseItemInput(productId: 'p1', title: 'کالا', quantity: 10, unitPrice: 100_000),
      ],
      shipping: 100_000,
      discount: 0,
    );
    // (10×100,000 + 100,000) / 10 = 110,000
    expect(core.inventory.avgCost('p1'), 110_000);
  });

  test('خرید با پرداخت نقدی هم‌زمان', () {
    final purchase = core.purchases.create(
      supplierId: supplierId,
      date: '2026-01-01',
      items: const [
        PurchaseItemInput(productId: 'p1', title: 'کالا', quantity: 1, unitPrice: 500_000),
      ],
      paidAmount: 500_000,
      accountId: 'acc-cash',
    );
    expect(purchase.status, 'paid');
    expect(core.suppliers.payable(supplierId), 0);
    expect(core.accounts.balance('acc-cash'), -500_000);
  });

  test('پرداخت بیشتر از جمع فاکتور رد می‌شود', () {
    core.purchases.create(
      supplierId: supplierId,
      date: '2026-01-01',
      items: const [
        PurchaseItemInput(productId: 'p1', title: 'کالا', quantity: 1, unitPrice: 100),
      ],
      paidAmount: 100,
      accountId: 'acc-cash',
    );
    expect(
      () => core.purchases.create(
        supplierId: supplierId,
        date: '2026-01-02',
        items: const [
          PurchaseItemInput(productId: 'p1', title: 'کالا', quantity: 1, unitPrice: 100),
        ],
        paidAmount: 200,
        accountId: 'acc-cash',
      ),
      throwsArgumentError,
    );
  });

  test('برگشت خرید: کاهش موجودی و بدهی؛ بیشتر از خرید مجاز نیست', () {
    final purchase = core.purchases.create(
      supplierId: supplierId,
      date: '2026-01-01',
      items: const [
        PurchaseItemInput(productId: 'p1', title: 'کالا', quantity: 10, unitPrice: 100_000),
      ],
    );
    final items = core.purchases.items(purchase.id);
    final itemId = items.first['id'] as String;

    core.purchases.returnPurchase(
      purchaseId: purchase.id,
      returnItems: [PurchaseReturnInput(purchaseItemId: itemId, quantity: 3)],
      date: '2026-01-02',
      reducePayable: true,
    );
    expect(core.inventory.currentQty('p1'), 7);
    expect(core.suppliers.payable(supplierId), 700_000);

    // برگشت بیشتر از باقی‌مانده رد می‌شود
    expect(
      () => core.purchases.returnPurchase(
        purchaseId: purchase.id,
        returnItems: [PurchaseReturnInput(purchaseItemId: itemId, quantity: 8)],
        date: '2026-01-03',
        reducePayable: true,
      ),
      throwsStateError,
    );

    // برگشت دوم تا سقف مجاز
    core.purchases.returnPurchase(
      purchaseId: purchase.id,
      returnItems: [PurchaseReturnInput(purchaseItemId: itemId, quantity: 7)],
      date: '2026-01-04',
      reducePayable: true,
    );
    expect(core.inventory.currentQty('p1'), 0);
    expect(core.suppliers.payable(supplierId), 0);
  });

  test('برگشت خرید با دریافت نقدی (بدون کاهش بدهی)', () {
    final purchase = core.purchases.create(
      supplierId: supplierId,
      date: '2026-01-01',
      items: const [
        PurchaseItemInput(productId: 'p1', title: 'کالا', quantity: 10, unitPrice: 100_000),
      ],
      paidAmount: 1_000_000,
      accountId: 'acc-cash',
    );
    final itemId = core.purchases.items(purchase.id).first['id'] as String;
    core.purchases.returnPurchase(
      purchaseId: purchase.id,
      returnItems: [PurchaseReturnInput(purchaseItemId: itemId, quantity: 2)],
      date: '2026-01-02',
      reducePayable: false,
      refundAccountId: 'acc-cash',
    );
    // بدهی همچنان 0 (چون خرید تسویه‌شده بود) و وجه برگشتی به صندوق آمده
    expect(core.suppliers.payable(supplierId), 0);
    expect(core.accounts.balance('acc-cash'), -1_000_000 + 200_000);
  });

  test('گزارش تأمین‌کنندگان سازگار است', () {
    core.purchases.create(
      supplierId: supplierId,
      date: '2026-01-01',
      items: const [
        PurchaseItemInput(productId: 'p1', title: 'کالا', quantity: 1, unitPrice: 1_000_000),
      ],
      paidAmount: 400_000,
      accountId: 'acc-cash',
    );
    final rows = core.reports.supplierReport();
    expect(rows.length, 1);
    expect(rows.first['purchases'], 1_000_000);
    expect(rows.first['payments'], 400_000);
    expect(rows.first['payable'], 600_000);
  });

  test('رویداد PURCHASE با کلید idempotent فقط یک‌بار اثر دارد', () {
    core.purchases.create(
      supplierId: supplierId,
      date: '2026-01-01',
      items: const [
        PurchaseItemInput(productId: 'p1', title: 'کالا', quantity: 2, unitPrice: 100),
      ],
    );
    final events = core.ledger.effectiveEvents(
        types: {LedgerEventType.purchase});
    expect(events.length, 1);
  });
}
