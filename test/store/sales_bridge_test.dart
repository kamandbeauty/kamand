import 'package:flutter_test/flutter_test.dart';
import 'package:factor_ruby/models/invoice_model.dart';
import 'package:factor_ruby/models/invoice_item_model.dart';
import 'package:factor_ruby/store/store_core.dart';

InvoiceModel _invoice({
  required String id,
  String number = '1001',
  String date = '1404/10/12', // = 2026-01-01
  double subtotal = 1_000_000,
  double discount = 0,
  double shipping = 0,
  double paid = 0,
  String customerId = 'c1',
  List<InvoiceItemModel> items = const [],
}) {
  final remaining = subtotal - discount + shipping - paid;
  return InvoiceModel(
    id: id,
    number: number,
    customerId: customerId,
    customerName: 'مشتری تست',
    customerPhone: '',
    type: 'sale',
    paymentType: paid >= subtotal - discount + shipping ? 'cash' : 'non_cash',
    status: remaining <= 0 ? 'paid' : (paid > 0 ? 'partial' : 'unpaid'),
    date: date,
    items: items,
    subtotal: subtotal,
    discountPercent: 0,
    discountAmount: discount,
    shippingFee: shipping,
    previousDebt: 0,
    deposit: 0,
    totalAmount: subtotal - discount + shipping,
    paidAmount: paid,
    remainingAmount: remaining < 0 ? 0 : remaining,
    notes: '',
    cardNumber: '',
    createdAt: '1404/10/12',
  );
}

void main() {
  late StoreCore core;

  setUp(() {
    core = StoreCore.inMemory();
    core.bridge.productMatcher = (title) => title.startsWith('کاتالوگ:') ? 'p1' : null;
    // موجودی اولیه
    core.inventory.ensureProduct('p1', currentQty: 100, avgCost: 400_000);
  });

  test('تاریخ جلالی فاکتور به میلادی درست تبدیل می‌شود', () {
    expect(core.bridge.toIsoDate('1404/10/12'), '2026-01-02'); // فروردین ۱۴۰۴ = ۲۱ مارس ۲۰۲۵
    expect(core.bridge.toIsoDate('2024-05-15'), '2024-05-15');
  });

  test('فروش نسیه: رویداد فروش + کاهش موجودی + ماندهٔ مشتری', () {
    core.bridge.onInvoiceSaved(_invoice(
      id: 'inv-1',
      items: [InvoiceItemModel(id: 'i1', title: 'کاتالوگ: گوشی', quantity: 2, unit: 'عدد', unitPrice: 1_000_000, totalPrice: 2_000_000)],
      subtotal: 2_000_000,
    ));
    expect(core.inventory.currentQty('p1'), 98);
    expect(core.bridge.derivedCustomerBalance('c1'), 2_000_000);
    // بهای تمام‌شده ثبت شده (2 × 400,000)
    final doc = core.db.db.select('SELECT * FROM sales_documents').first;
    expect(doc['cost'], 800_000);
    expect(doc['revenue'], 2_000_000);
  });

  test('فروش نقدی: وجه بلافاصله وارد صندوق می‌شود', () {
    core.bridge.onInvoiceSaved(_invoice(id: 'inv-2', paid: 1_000_000));
    expect(core.accounts.balance('acc-cash'), 1_000_000);
    expect(core.bridge.derivedCustomerBalance('c1'), 0);
  });

  test('ذخیرهٔ دوبارهٔ بدون تغییر، رویداد تکراری نمی‌سازد (idempotent)', () {
    final inv = _invoice(id: 'inv-3');
    core.bridge.onInvoiceSaved(inv);
    core.bridge.onInvoiceSaved(inv);
    final events = core.ledger.effectiveEvents();
    expect(events.length, 1);
    expect(core.inventory.currentQty('p1'), 100); // آیتم بدون تطبیق کاتالوگ
  });

  test('ویرایش فاکتور: نسخهٔ قبل دقیقاً یک‌بار معکوس + نسخهٔ جدید ثبت', () {
    core.bridge.onInvoiceSaved(_invoice(id: 'inv-4', subtotal: 1_000_000));
    expect(core.bridge.derivedCustomerBalance('c1'), 1_000_000);
    core.bridge.onInvoiceSaved(_invoice(id: 'inv-4', subtotal: 3_000_000));
    expect(core.bridge.derivedCustomerBalance('c1'), 3_000_000);
    final saleEvents = core.ledger.effectiveEvents(
        types: {'SALE', 'REVENUE_REVERSED'});
    // فقط SALE نسخهٔ ۲ مؤثر است؛ v1 و معکوس آن از وضعیت فعال خارج شده‌اند
    final allSale = core.db.db.select(
        "SELECT COUNT(*) AS c FROM ledger_events WHERE event_type IN ('SALE','REVENUE_REVERSED')");
    expect(allSale.first['c'], 3); // v1 sale + reversal + v2 sale (تاریخ کامل)
    expect(saleEvents.length, 1);
    final doc = core.db.db.select('SELECT * FROM sales_documents').first;
    expect(doc['ledger_version'], 2);
    expect(doc['revenue'], 3_000_000);
  });

  test('ویرایش با کالا: موجودی نسخهٔ قدیمی برمی‌گردد و جدید کم می‌شود', () {
    final item = InvoiceItemModel(id: 'i1', title: 'کاتالوگ: گوشی', quantity: 5, unit: 'عدد', unitPrice: 100, totalPrice: 500);
    core.bridge.onInvoiceSaved(_invoice(id: 'inv-5', subtotal: 500, items: [item]));
    expect(core.inventory.currentQty('p1'), 95);
    final item2 = InvoiceItemModel(id: 'i1', title: 'کاتالوگ: گوشی', quantity: 3, unit: 'عدد', unitPrice: 100, totalPrice: 300);
    core.bridge.onInvoiceSaved(_invoice(id: 'inv-5', subtotal: 300, items: [item2]));
    expect(core.inventory.currentQty('p1'), 97); // 100 - 5 + 5 - 3
  });

  test('حذف نرم فاکتور: اثر معکوس + سند deleted با تاریخ حفظ‌شده (§40)', () {
    core.bridge.onInvoiceSaved(_invoice(id: 'inv-6', subtotal: 1_000_000));
    core.bridge.onInvoiceDeleted('inv-6');
    expect(core.bridge.derivedCustomerBalance('c1'), 0);
    final doc = core.db.db.select('SELECT * FROM sales_documents').first;
    expect(doc['status'], 'deleted');
    expect(doc['deleted_at'], isNotNull);
    // در فروش فعال هیچ ردی نیست ولی رویداد تاریخی هست
    final active = core.reports.salesReport('2026-01-01', '2026-12-31');
    expect(active.isEmpty, isTrue);
    final events = core.db.db.select('SELECT COUNT(*) AS c FROM ledger_events');
    expect(events.first['c'], greaterThanOrEqualTo(2));
    // حذف دوباره بی‌اثر است
    core.bridge.onInvoiceDeleted('inv-6');
    expect(core.bridge.derivedCustomerBalance('c1'), 0);
  });

  test('§42 — شمارهٔ فاکتور فعال یکتا است؛ پس از حذف آزاد می‌شود', () {
    core.bridge.onInvoiceSaved(_invoice(id: 'inv-7', number: '2001'));
    expect(core.bridge.isInvoiceNumberTaken('2001'), isTrue);
    expect(core.bridge.isInvoiceNumberTaken('2001', excludeSourceId: 'inv-7'), isFalse);
    core.bridge.onInvoiceSaved(_invoice(id: 'inv-8', number: '2002'));
    core.bridge.onInvoiceDeleted('inv-8');
    expect(core.bridge.isInvoiceNumberTaken('2002'), isFalse);
    // سند تاریخی حذف‌شده با همان شماره قابل بازیابی است
    expect(core.bridge.isInvoiceNumberTaken('2001'), isTrue);
  });

  test('دریافت فاکتور: بدهی مشتری کم می‌شود و idempotent است', () {
    core.bridge.onInvoiceSaved(_invoice(id: 'inv-9', subtotal: 1_000_000));
    core.bridge.onInvoicePayment('inv-9', 400_000);
    core.bridge.onInvoicePayment('inv-9', 400_000); // تکراری
    expect(core.accounts.balance('acc-cash'), 400_000);
    expect(core.bridge.derivedCustomerBalance('c1'), 600_000);
    final doc = core.db.db.select('SELECT * FROM sales_documents').first;
    expect(doc['paid'], 400_000);
    expect(doc['remaining'], 600_000);
  });

  test('پیش‌فاکتور وارد دفتر مالی نمی‌شود', () {
    final proforma = _invoice(id: 'inv-10');
    final asProforma = InvoiceModel(
      id: proforma.id,
      number: proforma.number,
      customerId: 'c1',
      customerName: 'مشتری',
      customerPhone: '',
      type: 'proforma',
      paymentType: 'cash',
      status: 'proforma',
      date: proforma.date,
      items: [],
      subtotal: 1,
      discountPercent: 0,
      discountAmount: 0,
      shippingFee: 0,
      previousDebt: 0,
      deposit: 0,
      totalAmount: 1,
      paidAmount: 0,
      remainingAmount: 1,
      notes: '',
      cardNumber: '',
      createdAt: '',
    );
    core.bridge.onInvoiceSaved(asProforma);
    expect(core.ledger.effectiveEvents().isEmpty, isTrue);
  });

  test('مالی مشتری: دریافت تا سقف بدهی؛ برگشت؛ صورت‌حساب (§5، §10، §11)', () {
    core.bridge.onInvoiceSaved(_invoice(id: 'inv-11', subtotal: 1_000_000));
    // دریافت بیشتر از بدهی رد می‌شود (ماندهٔ منفی ممنوع)
    expect(
      () => core.customerFinance.receivePayment(
          customerId: 'c1',
          amount: 1_100_000,
          date: '2026-01-02',
          accountId: 'acc-cash'),
      throwsStateError,
    );
    core.customerFinance.receivePayment(
        customerId: 'c1', amount: 300_000, date: '2026-01-02', accountId: 'acc-cash');
    expect(core.bridge.derivedCustomerBalance('c1'), 700_000);

    // برگشت وجه به مشتری
    core.customerFinance.refund(
        customerId: 'c1', amount: 100_000, date: '2026-01-03', accountId: 'acc-cash');
    expect(core.accounts.balance('acc-cash'), 300_000 - 100_000);

    // برگشت کالا: کاهش بدهی تا کف صفر
    core.customerFinance.recordReturn(customerId: 'c1', amount: 250_000, date: '2026-01-04');
    expect(core.bridge.derivedCustomerBalance('c1'), 450_000);

    final summary = core.customerFinance.summary('c1');
    expect(summary.receivable, 450_000);
    expect(summary.totalPaid, 300_000);
    expect(summary.totalRefunded, 100_000);
    expect(summary.totalReturned, 250_000);
    expect(summary.lastTransactionDate, isNotNull);
    final statement = core.customerFinance.statement('c1');
    expect(statement.length, 4); // SALE + PAYMENT + REFUND + RETURN
  });

  test('داشبورد با فروش خالی کرش نمی‌کند (§3)', () {
    final d = core.reports.dashboard('2026-01-01');
    expect(d.todaySales, 0);
    expect(d.todayInvoiceCount, 0);
    expect(d.receivables, 0);
    expect(d.payables, 0);
    expect(d.todayExpenses, 0);
    expect(d.overdueCount, 0);
  });

  test('داشبورد فروش امروز را درست جمع می‌زند', () {
    core.bridge.onInvoiceSaved(_invoice(id: 'inv-12', paid: 1_000_000));
    core.bridge.onInvoiceSaved(_invoice(id: 'inv-13', subtotal: 500_000, number: '1002'));
    final d = core.reports.dashboard('2026-01-02');
    expect(d.todaySales, 1_500_000);
    expect(d.todayInvoiceCount, 2);
    expect(d.todayCashSales, 1_000_000);
    expect(d.todayCreditSales, 500_000);
    expect(d.receivables, 500_000);
  });
}
