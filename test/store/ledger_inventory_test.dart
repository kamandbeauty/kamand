import 'package:flutter_test/flutter_test.dart';
import 'package:factor_ruby/store/core/accounts.dart';
import 'package:factor_ruby/store/core/inventory.dart';
import 'package:factor_ruby/store/store_core.dart';

void main() {
  late StoreCore core;

  setUp(() {
    core = StoreCore.inMemory();
  });

  group('Ledger — دفتر کل', () {
    test('رویداد idempotent با کلید تکراری فقط یک‌بار ثبت می‌شود', () {
      final id1 = core.ledger.append(LedgerEntryInput(
        eventType: LedgerEventType.expense,
        date: '2026-01-01',
        amount: 1000,
        idempotencyKey: 'test-key-1',
      ));
      final id2 = core.ledger.append(LedgerEntryInput(
        eventType: LedgerEventType.expense,
        date: '2026-01-01',
        amount: 1000,
        idempotencyKey: 'test-key-1',
      ));
      expect(id1, id2);
      final events = core.ledger.effectiveEvents();
      expect(events.length, 1);
    });

    test('اثر معکوس دقیقاً یک‌بار مجاز است', () {
      final id = core.ledger.append(LedgerEntryInput(
        eventType: LedgerEventType.sale,
        date: '2026-01-01',
        amount: 500,
        customerDelta: 500,
        idempotencyKey: 'sale-1',
      ));
      core.ledger.reverse(id, date: '2026-01-02');
      expect(() => core.ledger.reverse(id), throwsStateError);
      // رویداد معکوس‌شده از مجموع مؤثر حذف شده ولی رکوردش موجود است
      expect(core.ledger.sumField('customer_delta', 'v'), 0);
      final all = core.db.db.select('SELECT COUNT(*) AS c FROM ledger_events');
      expect(all.first['c'], 2); // اصلی + معکوس — تاریخ مالی حفظ می‌شود
    });

    test('جمع مشتری از رویدادهای مؤثر مشتق می‌شود', () {
      core.ledger.append(LedgerEntryInput(
        eventType: LedgerEventType.sale,
        date: '2026-01-01',
        amount: 100,
        customerId: 'c1',
        customerDelta: 100,
      ));
      core.ledger.append(LedgerEntryInput(
        eventType: LedgerEventType.paymentReceived,
        date: '2026-01-02',
        amount: 40,
        customerId: 'c1',
        customerDelta: -40,
      ));
      expect(core.bridge.derivedCustomerBalance('c1'), 60);
    });
  });

  group('Inventory — موجودی', () {
    test('ورود خرید بهای میانگین موزون را به‌روز می‌کند', () {
      core.inventory.receive('p1', 10,
          movementType: StockMovementType.purchase,
          unitCost: 1000,
          date: '2026-01-01');
      core.inventory.receive('p1', 10,
          movementType: StockMovementType.purchase,
          unitCost: 3000,
          date: '2026-01-02');
      expect(core.inventory.currentQty('p1'), 20);
      expect(core.inventory.avgCost('p1'), 2000);
      expect(core.inventory.valuation(), 40000);
    });

    test('موجودی منفی مجاز نیست', () {
      core.inventory.receive('p1', 5,
          movementType: StockMovementType.purchase,
          unitCost: 100,
          date: '2026-01-01');
      expect(
        () => core.inventory.deduct('p1', 6,
            movementType: StockMovementType.sale, date: '2026-01-02'),
        throwsStateError,
      );
      expect(core.inventory.currentQty('p1'), 5);
    });

    test('کسر idempotent با کلید تکراری دوبار کم نمی‌کند', () {
      core.inventory.receive('p1', 10,
          movementType: StockMovementType.purchase,
          unitCost: 100,
          date: '2026-01-01');
      core.inventory.deduct('p1', 3,
          movementType: StockMovementType.sale,
          date: '2026-01-02',
          idempotencyKey: 'sale:x:v1');
      core.inventory.deduct('p1', 3,
          movementType: StockMovementType.sale,
          date: '2026-01-02',
          idempotencyKey: 'sale:x:v1');
      expect(core.inventory.currentQty('p1'), 7);
    });

    test('تعدیل موجودی با حرکت شفاف ثبت می‌شود', () {
      core.inventory.ensureProduct('p1', currentQty: 10);
      core.inventory.adjustTo('p1', 8, date: '2026-01-01', note: 'شمارش');
      expect(core.inventory.currentQty('p1'), 8);
      final moves = core.inventory.movements('p1');
      expect(moves.any((m) => m.movementType == StockMovementType.adjustment), isTrue);
    });

    test('موجودی مشتق = جمع حرکت‌ها (تطبیق §51)', () {
      core.inventory.receive('p1', 10,
          movementType: StockMovementType.purchase,
          unitCost: 100,
          date: '2026-01-01');
      core.inventory.deduct('p1', 4,
          movementType: StockMovementType.sale, date: '2026-01-02');
      core.inventory.receive('p1', 1,
          movementType: StockMovementType.saleReturn,
          unitCost: 0,
          date: '2026-01-03');
      expect(core.inventory.currentQty('p1'), 7);
      final checks = core.reports.reconciliationChecks();
      expect(checks.firstWhere((c) => c['name'] == 'موجودی = جمع حرکت‌های موجودی')['ok'],
          isTrue);
    });

    test('کالای کم‌موجودی شناسایی می‌شود', () {
      core.inventory.ensureProduct('p1', currentQty: 2, minQty: 5);
      core.inventory.ensureProduct('p2', currentQty: 10, minQty: 5);
      final low = core.inventory.lowStock();
      expect(low.length, 1);
      expect(low.first.productId, 'p1');
    });
  });

  group('Accounts — حساب‌ها', () {
    test('مانده = آغازین + ورودی − خروجی', () {
      final accId = core.accounts.save(name: 'بانک', type: 'bank', openingBalance: 1_000_000);
      core.ledger.append(LedgerEntryInput(
        eventType: LedgerEventType.paymentReceived,
        date: '2026-01-01',
        amount: 500_000,
        direction: 1,
        accountId: accId,
      ));
      core.ledger.append(LedgerEntryInput(
        eventType: LedgerEventType.expense,
        date: '2026-01-02',
        amount: 200_000,
        direction: -1,
        accountId: accId,
      ));
      expect(core.accounts.balance(accId), 1_300_000);
    });

    test('انتقال وجه بین دو حساب — خالص صفر و در سود و زیان نیست', () {
      final a = core.accounts.save(name: 'صندوق', type: 'cash');
      final b = core.accounts.save(name: 'بانک', type: 'bank');
      core.accounts.transfer(
          fromAccountId: a, toAccountId: b, amount: 400_000, date: '2026-01-01');
      expect(core.accounts.balance(a), -400_000);
      expect(core.accounts.balance(b), 400_000);
      final pl = core.reports.profitAndLoss('2026-01-01', '2026-12-31');
      expect(pl.operatingExpenses, 0);
      expect(pl.revenue, 0);
    });

    test('انتقال به خود حساب رد می‌شود', () {
      final a = core.accounts.save(name: 'صندوق', type: 'cash');
      expect(
        () => core.accounts.transfer(
            fromAccountId: a, toAccountId: a, amount: 100, date: '2026-01-01'),
        throwsArgumentError,
      );
    });

    test('انتقال وجه دو سطر رویداد دارد و هر دو idempotent‌اند', () {
      final a = core.accounts.save(name: 'صندوق', type: 'cash');
      final b = core.accounts.save(name: 'بانک', type: 'bank');
      core.accounts.transfer(
          fromAccountId: a,
          toAccountId: b,
          amount: 400_000,
          date: '2026-01-01',
          transferId: 'tr-1');
      core.accounts.transfer(
          fromAccountId: a,
          toAccountId: b,
          amount: 400_000,
          date: '2026-01-01',
          transferId: 'tr-1');
      final rows = core.db.db.select(
          "SELECT COUNT(*) AS c FROM ledger_events WHERE event_type = 'ACCOUNT_TRANSFER'");
      expect(rows.first['c'], 2);
    });
  });
}
