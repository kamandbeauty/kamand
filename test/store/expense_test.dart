import 'package:flutter_test/flutter_test.dart';
import 'package:factor_ruby/store/core/ledger.dart';
import 'package:factor_ruby/store/store_core.dart';

void main() {
  late StoreCore core;
  late int packagingId;
  late int shippingId;

  setUp(() {
    core = StoreCore.inMemory();
    final cats = core.expenses.categories();
    packagingId =
        cats.firstWhere((c) => c.key == 'PACKAGING').id;
    shippingId =
        cats.firstWhere((c) => c.key == 'SHIPPING').id;
  });

  test('هزینه ثبت و در گزارش دسته‌ای دیده می‌شود', () {
    core.expenses.add(
        categoryId: packagingId,
        amount: 5_000_000,
        date: '2026-01-01',
        description: 'خرید عمدهٔ ۵۰۰۰ کارتن',
        accountId: 'acc-cash');
    expect(core.accounts.balance('acc-cash'), -5_000_000);
    final totals = core.expenses.totalsByCategory(from: '2026-01-01', to: '2026-12-31');
    expect(totals.first['total'], 5_000_000);
  });

  test('§43 — خرید عمدهٔ بسته‌بندی به‌طور خودکار بین فاکتورها توزیع نمی‌شود', () {
    // خرید عمدهٔ ۵م بسته‌بندی
    core.expenses.add(
        categoryId: packagingId,
        amount: 5_000_000,
        date: '2026-01-01',
        accountId: 'acc-cash');
    // دریافت بسته‌بندی از دو مشتری (بازیافت هزینه)
    core.customerFinance.packagingCharge(
        customerId: 'c1', amount: 100_000, date: '2026-01-02', accountId: 'acc-cash');
    core.customerFinance.packagingCharge(
        customerId: 'c2', amount: 50_000, date: '2026-01-02', accountId: 'acc-cash');

    final pl = core.reports.profitAndLoss('2026-01-01', '2026-01-31');
    // هزینهٔ بسته‌بندی کامل ۵م است؛ هیچ توزیع خودکاری روی فاکتورها نبوده
    expect(pl.expensesByCategory['بسته‌بندی'], 5_000_000);
    // درآمد بسته‌بندی جداگانه و قابل مقایسه است
    expect(pl.revenue, 150_000);
    // خروجی نقدی
    expect(pl.cashPaidOut, 5_000_000);
  });

  test('ابطال هزینه فقط یک‌بار و بدون حذف تاریخ', () {
    final id = core.expenses.add(
        categoryId: shippingId, amount: 300_000, date: '2026-01-01', accountId: 'acc-cash');
    core.expenses.voidExpense(id, reason: 'ثبت اشتباه');
    expect(core.accounts.balance('acc-cash'), 0);
    expect(core.expenses.list(includeVoided: true).length, 1);
    expect(core.expenses.list().length, 0);
    expect(() => core.expenses.voidExpense(id), throwsStateError);
    final totals = core.expenses.totalsByCategory();
    expect(totals.isEmpty, isTrue);
  });

  test('هزینهٔ ارسال جدا از هزینهٔ بسته‌بندی گزارش می‌شود', () {
    core.expenses.add(categoryId: shippingId, amount: 100, date: '2026-01-01');
    core.expenses.add(categoryId: packagingId, amount: 200, date: '2026-01-01');
    final pl = core.reports.profitAndLoss('2026-01-01', '2026-12-31');
    expect(pl.expensesByCategory['حمل و ارسال'], 100);
    expect(pl.expensesByCategory['بسته‌بندی'], 200);
  });

  test('دستهٔ هزینهٔ سفارشی قابل افزودن است', () {
    final id = core.expenses.addCategory('MARKETING', 'تبلیغات');
    core.expenses.add(categoryId: id, amount: 500_000, date: '2026-01-01');
    final cats = core.expenses.categories();
    expect(cats.any((c) => c.key == 'MARKETING'), isTrue);
    final pl = core.reports.profitAndLoss('2026-01-01', '2026-12-31');
    expect(pl.expensesByCategory['تبلیغات'], 500_000);
  });

  test('رویدادهای هزینه با نوع درست دفتر کل ثبت می‌شوند', () {
    core.expenses.add(categoryId: packagingId, amount: 1, date: '2026-01-01');
    core.expenses.add(categoryId: shippingId, amount: 1, date: '2026-01-01');
    final types = core.ledger.effectiveEvents().map((e) => e.eventType).toSet();
    expect(types.contains(LedgerEventType.packagingExpense), isTrue);
    expect(types.contains(LedgerEventType.shippingExpense), isTrue);
  });
}
