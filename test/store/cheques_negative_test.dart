import 'package:flutter_test/flutter_test.dart';
import 'package:factor_ruby/store/cheques/cheque_repository.dart';
import 'package:factor_ruby/store/core/inventory.dart';
import 'package:factor_ruby/store/core/ledger.dart';
import 'package:factor_ruby/store/suppliers/purchase_repository.dart';
import 'package:factor_ruby/store/store_core.dart';

/// قابلیت‌های نسخهٔ ۴:
/// ۱) موجودی منفی مجاز — فروش ناموجود → منفی؛ خرید بعدی جبران می‌کند
/// ۲) چک در دریافت/پرداخت — وصول، برگشت، یادآور سررسید «پاس شد؟»
void main() {
  late StoreCore core;

  setUp(() {
    core = StoreCore.inMemory();
  });

  group('موجودی منفی (مدل کسب‌وکار کاربر)', () {
    test('فروش ۵ عدد از موجودی صفر → موجودی −۵', () {
      core.inventory.ensureProduct('p1');
      core.inventory.deduct('p1', 5,
          movementType: StockMovementType.sale, date: '2026-01-01');
      expect(core.inventory.currentQty('p1'), -5);
    });

    test('سناریوی دقیق کاربر: فروش ۵ ناموجود، بعد خرید ۶ → موجودی +۱', () {
      core.inventory.ensureProduct('p1');
      // فاکتور فروش ۵ عدد از کالای ناموجود
      core.inventory.deduct('p1', 5,
          movementType: StockMovementType.sale, date: '2026-01-01');
      expect(core.inventory.currentQty('p1'), -5);
      // فاکتور خرید ۶ عدد
      core.inventory.receive('p1', 6,
          movementType: StockMovementType.purchase,
          unitCost: 100_000,
          date: '2026-01-02');
      expect(core.inventory.currentQty('p1'), 1);
    });

    test('حرکت‌ها حتی با موجودی منفی سازگارند (موجودی = جمع حرکت‌ها)', () {
      core.inventory.ensureProduct('p2');
      core.inventory.deduct('p2', 3,
          movementType: StockMovementType.sale, date: '2026-01-01');
      final checks = core.reports.reconciliationChecks();
      final c = checks
          .firstWhere((x) => x['name'] == 'موجودی = جمع حرکت‌های موجودی');
      expect(c['ok'], isTrue);
    });
  });

  group('چک — دریافت، وصول، برگشت، یادآور', () {
    test('دریافت چک از مشتری: بدهی کم می‌شود ولی نقد نیست', () {
      // مشتری بدهکار ۱م
      core.ledger.append(LedgerEntryInput(
        eventType: 'SALE',
        date: '2026-01-01',
        amount: 1_000_000,
        customerId: 'c1',
        customerDelta: 1_000_000,
      ));
      final id = core.cheques.receiveCheque(
        customerId: 'c1',
        customerName: 'مشتری تست',
        amount: 600_000,
        chequeNumber: '12345',
        dueDate: '2026-03-10',
        holderName: 'علی رضایی',
        bankName: 'بانک ملت',
        sayadiNumber: 'SY-999',
      );
      // بدهی مشتری کم شد
      expect(core.bridge.derivedCustomerBalance('c1'), 400_000);
      // ولی هیچ پولی وارد حساب نشده
      expect(core.accounts.balance('acc-cash'), 0);
      final chq = core.cheques.byId(id)!;
      expect(chq.status, ChequeStatus.held);
      expect(chq.isReceived, isTrue);
      expect(chq.holderName, 'علی رضایی');
      expect(chq.bankName, 'بانک ملت');
      expect(chq.sayadiNumber, 'SY-999');
    });

    test('فیلدهای اجباری: شمارهٔ چک و سررسید', () {
      expect(
        () => core.cheques.receiveCheque(
          customerId: 'c1',
          customerName: 'م',
          amount: 100,
          chequeNumber: '  ',
          dueDate: '2026-01-01',
        ),
        throwsArgumentError,
      );
      expect(
        () => core.cheques.receiveCheque(
          customerId: 'c1',
          customerName: 'م',
          amount: 100,
          chequeNumber: '123',
          dueDate: '',
        ),
        throwsArgumentError,
      );
    });

    test('دریافت چک بیشتر از بدهی مشتری رد می‌شود (مانده منفی ممنوع)', () {
      core.ledger.append(LedgerEntryInput(
        eventType: 'SALE',
        date: '2026-01-01',
        amount: 100_000,
        customerId: 'c1',
        customerDelta: 100_000,
      ));
      expect(
        () => core.cheques.receiveCheque(
          customerId: 'c1',
          customerName: 'م',
          amount: 200_000,
          chequeNumber: '1',
          dueDate: '2026-02-01',
        ),
        throwsStateError,
      );
    });

    test('وصول چک (پاس شد): پول وارد حساب — فقط یک‌بار', () {
      core.ledger.append(LedgerEntryInput(
        eventType: 'SALE',
        date: '2026-01-01',
        amount: 1_000_000,
        customerId: 'c1',
        customerDelta: 1_000_000,
      ));
      final id = core.cheques.receiveCheque(
        customerId: 'c1',
        customerName: 'م',
        amount: 500_000,
        chequeNumber: '777',
        dueDate: '2026-02-01',
      );
      core.cheques.clearCheque(id, accountId: 'acc-cash', date: '2026-02-02');
      expect(core.accounts.balance('acc-cash'), 500_000);
      expect(core.cheques.byId(id)!.status, ChequeStatus.cleared);
      // وصول دوباره رد می‌شود
      expect(
        () => core.cheques.clearCheque(id, accountId: 'acc-cash', date: '2026-02-03'),
        throwsStateError,
      );
    });

    test('برگشت چک: بدهی مشتری دقیقاً برمی‌گردد — فقط یک‌بار', () {
      core.ledger.append(LedgerEntryInput(
        eventType: 'SALE',
        date: '2026-01-01',
        amount: 1_000_000,
        customerId: 'c1',
        customerDelta: 1_000_000,
      ));
      final id = core.cheques.receiveCheque(
        customerId: 'c1',
        customerName: 'م',
        amount: 500_000,
        chequeNumber: '888',
        dueDate: '2026-02-01',
      );
      expect(core.bridge.derivedCustomerBalance('c1'), 500_000);
      core.cheques.bounceCheque(id, date: '2026-02-02');
      expect(core.bridge.derivedCustomerBalance('c1'), 1_000_000);
      expect(core.cheques.byId(id)!.status, ChequeStatus.bounced);
      // برگشت دوباره رد می‌شود
      expect(() => core.cheques.bounceCheque(id), throwsStateError);
      // وصول چک برگشتی رد می‌شود
      expect(
        () => core.cheques.clearCheque(id, accountId: 'acc-cash', date: '2026-02-03'),
        throwsStateError,
      );
    });

    test('پرداخت چک به تأمین‌کننده + پاس شدن (خروج از حساب)', () {
      final supplierId = core.suppliers.save(name: 'تأمین‌کننده');
      core.purchases.create(
        supplierId: supplierId,
        date: '2026-01-01',
        items: const [
          PurchaseItemInput(productId: 'p1', title: 'کالا', quantity: 1, unitPrice: 800_000),
        ],
      );
      final id = core.cheques.issueCheque(
        supplierId: supplierId,
        supplierName: 'تأمین‌کننده',
        amount: 800_000,
        chequeNumber: '555',
        dueDate: '2026-02-05',
      );
      expect(core.suppliers.payable(supplierId), 0); // بدهی با چک تسویه شد
      expect(core.accounts.balance('acc-cash'), 0); // هنوز نقد خارج نشده
      core.cheques.clearCheque(id, accountId: 'acc-cash', date: '2026-02-06');
      expect(core.accounts.balance('acc-cash'), -800_000);
    });

    test('یادآور سررسید: «آیا چکی که از فلانی دریافت کردیم پاس شده؟»', () {
      core.ledger.append(LedgerEntryInput(
        eventType: 'SALE',
        date: '2026-01-01',
        amount: 1_000_000,
        customerId: 'c1',
        customerDelta: 1_000_000,
      ));
      final id = core.cheques.receiveCheque(
        customerId: 'c1',
        customerName: 'فلانی',
        amount: 300_000,
        chequeNumber: '111',
        dueDate: '2026-01-20',
      );
      // قبل از سررسید: سؤالی نیست
      expect(core.cheques.dueForConfirmation('2026-01-19').length, 0);
      // در روز سررسید: باید پرسیده شود
      final due = core.cheques.dueForConfirmation('2026-01-20');
      expect(due.length, 1);
      expect(due.first.counterpartyName, 'فلانی');
      expect(due.first.chequeNumber, '111');
      // بعد از پاس شدن دیگر پرسیده نمی‌شود
      core.cheques.clearCheque(id, accountId: 'acc-cash', date: '2026-01-21');
      expect(core.cheques.dueForConfirmation('2026-01-21').length, 0);
    });
  });
}
