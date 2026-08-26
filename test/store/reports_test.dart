import 'package:flutter_test/flutter_test.dart';
import 'package:factor_ruby/models/invoice_model.dart';
import 'package:factor_ruby/models/invoice_item_model.dart';
import 'package:factor_ruby/store/store_core.dart';
import 'package:factor_ruby/store/suppliers/purchase_repository.dart';

void main() {
  late StoreCore core;

  InvoiceModel sale({
    required String id,
    double subtotal = 10_000_000,
    double discount = 0,
    double shipping = 0,
    double paid = 0,
    List<InvoiceItemModel> items = const [],
  }) {
    final total = subtotal - discount + shipping;
    return InvoiceModel(
      id: id,
      number: 'N-$id',
      customerId: 'c1',
      customerName: 'مشتری',
      customerPhone: '',
      type: 'sale',
      paymentType: total <= paid ? 'cash' : 'non_cash',
      status: total <= paid ? 'paid' : 'unpaid',
      date: '1404/10/12',
      items: items,
      subtotal: subtotal,
      discountPercent: 0,
      discountAmount: discount,
      shippingFee: shipping,
      previousDebt: 0,
      deposit: 0,
      totalAmount: total,
      paidAmount: paid,
      remainingAmount: (total - paid) < 0 ? 0 : total - paid,
      notes: '',
      cardNumber: '',
      createdAt: '',
    );
  }

  setUp(() {
    core = StoreCore.inMemory();
    core.bridge.productMatcher = (title) => title.startsWith('p:') ? title.substring(2) : null;
    core.inventory.ensureProduct('p1', currentQty: 100, avgCost: 6_000_000);
  });

  test('§31/§37 — سود و زیان با جریان نقدی اشتباه نمی‌شود', () {
    core.bridge.onInvoiceSaved(sale(id: 's1', subtotal: 10_000_000, paid: 0));
    core.expenses.add(
      categoryId: core.expenses.categories().firstWhere((c) => c.key == 'RENT').id,
      amount: 500_000,
      date: '2026-01-01',
      accountId: 'acc-cash',
    );
    final pl = core.reports.profitAndLoss('2026-01-01', '2026-01-31');
    expect(pl.revenue, 10_000_000);
    expect(pl.cogs, 0); // اقلام بدون تطبیق کاتالوگ → بهای صفر (مستند در محدودیت‌ها)
    expect(pl.grossProfit, 10_000_000);
    expect(pl.operatingExpenses, 500_000);
    expect(pl.netProfit, 9_500_000);
    // نقد: هیچ فروشی نقدی نبوده؛ فقط اجاره پرداخت شده
    expect(pl.cashReceived, 0);
    expect(pl.cashPaidOut, 500_000);

    final cf = core.reports.cashflow('2026-01-01', '2026-01-31');
    expect(cf['incoming'], 0);
    expect(cf['outgoing'], 500_000);
  });

  test('COGS با تطبیق کاتالوگ محاسبه می‌شود و سود کالا گزارش می‌شود', () {
    core.bridge.onInvoiceSaved(sale(
      id: 's2',
      subtotal: 10_000_000,
      items: [
        InvoiceItemModel(
            id: 'i1', title: 'p:p1', quantity: 1, unit: 'عدد', unitPrice: 10_000_000, totalPrice: 10_000_000),
      ],
    ));
    final pl = core.reports.profitAndLoss('2026-01-01', '2026-01-31');
    expect(pl.cogs, 6_000_000);
    expect(pl.grossProfit, 4_000_000);

    final rows = core.reports.productProfit('2026-01-01', '2026-01-31');
    expect(rows.length, 1);
    expect(((rows.first['revenue'] as num?) ?? 0).toInt(), 10_000_000);
    expect(((rows.first['gross_profit'] as num?) ?? 0).toInt(), 4_000_000);
    expect(core.reports.marginBps(10_000_000, 6_000_000), 4000); // ۴۰٪
  });

  test('§37 — جریان نقدی: افتتاحیه + ورودی − خروجی = اختتامیه', () {
    core.accounts.save(name: 'بانک', type: 'bank', openingBalance: 2_000_000);
    core.bridge.onInvoiceSaved(sale(id: 's3', subtotal: 1_000_000, paid: 1_000_000));
    core.expenses.add(
      categoryId: core.expenses.categories().firstWhere((c) => c.key == 'UTILITIES').id,
      amount: 200_000,
      date: '2026-01-02',
      accountId: 'acc-cash',
    );
    final cf = core.reports.cashflow('2026-01-01', '2026-01-31');
    expect(cf['opening'], 2_000_000);
    expect(cf['incoming'], 1_000_000);
    expect(cf['outgoing'], 200_000);
    expect(cf['closing'], 2_800_000);
  });

  test('انتقال وجه در خروجی/ورودی دفتر کل هست ولی سود و زیان را تغییر نمی‌دهد', () {
    final bank = core.accounts.save(name: 'بانک', type: 'bank');
    core.accounts.transfer(
        fromAccountId: 'acc-cash',
        toAccountId: bank,
        amount: 500_000,
        date: '2026-01-01');
    final pl = core.reports.profitAndLoss('2026-01-01', '2026-01-31');
    expect(pl.netProfit, 0);
    expect(pl.operatingExpenses, 0);
    final cf = core.reports.cashflow('2026-01-01', '2026-01-31');
    // در سطح کل حساب‌ها انتقال خالص صفر است
    expect((cf['incoming'] as int) - (cf['outgoing'] as int), 0);
  });

  test('§33/§32 — گزارش فروش روزانه و جمع discount', () {
    core.bridge.onInvoiceSaved(sale(id: 's4', subtotal: 1_000_000, discount: 100_000, paid: 900_000));
    core.bridge.onInvoiceSaved(sale(id: 's5', subtotal: 2_000_000));
    final rows = core.reports.salesReport('2026-01-01', '2026-01-31');
    expect(rows.length, 1); // هر دو در یک روز
    expect(rows.first['cnt'], 2);
    expect(rows.first['sales'], 2_900_000);
    expect(rows.first['discounts'], 100_000);
    expect(rows.first['credit'], 2_000_000);
  });

  test('§51 — همهٔ بررسی‌های سازگاری سبزند در سناریوی کامل', () {
    // خرید → موجودی
    final supplierId = core.suppliers.save(name: 'تأمین‌کننده');
    core.purchases.create(
      supplierId: supplierId,
      date: '2026-01-01',
      items: const [
        PurchaseItemInput(productId: 'p1', title: 'p:p1', quantity: 50, unitPrice: 6_000_000),
      ],
      paidAmount: 100_000_000,
      accountId: 'acc-cash',
    );
    // فروش نسیه با کاتالوگ
    core.bridge.onInvoiceSaved(sale(
      id: 's-full',
      subtotal: 10_000_000,
      items: [
        InvoiceItemModel(
            id: 'i1', title: 'p:p1', quantity: 1, unit: 'عدد', unitPrice: 10_000_000, totalPrice: 10_000_000),
      ],
    ));
    core.bridge.onInvoicePayment('s-full', 2_000_000);
    // فروش اقساطی ترب‌پی با کارمزد پیکربندی‌شده
    final torob = core.installments.providerByKey('torob_pay')!;
    core.installments.saveProvider(
        id: torob.id, key: torob.key, name: torob.name, providerType: torob.providerType, commissionBps: 600);
    final isale = core.installments.createSale(
        providerId: torob.id, customerId: 'c2', customerName: 'م۲', gross: 8_000_000, date: '2026-01-02');
    core.installments.settle(
        saleId: isale.id, amount: isale.netSettlement, date: '2026-01-10', accountId: 'acc-cash');
    // اقساط مستقیم فروشگاه + پرداخت قسط
    final store = core.installments.providerByKey('store_direct')!;
    final direct = core.installments.createSale(
        providerId: store.id, customerId: 'c1', customerName: 'م', gross: 4_000_000, date: '2026-01-02', installmentCount: 2);
    final firstInst = core.installments.schedule(direct.id).first;
    core.installments.payInstallment(
        installmentId: firstInst.id, date: '2026-02-01', accountId: 'acc-cash', paymentRef: 'r1');
    // هزینه
    core.expenses.add(
      categoryId: core.expenses.categories().firstWhere((c) => c.key == 'PACKAGING').id,
      amount: 5_000_000,
      date: '2026-01-03',
      accountId: 'acc-cash',
    );

    final checks = core.reports.reconciliationChecks();
    for (final c in checks) {
      expect(c['ok'], isTrue, reason: '${c['name']} — ${c['detail']}');
    }
    // مانده‌ها معنادارند
    expect(core.bridge.derivedCustomerBalance('c1'), 8_000_000 + 2_000_000);
    expect(core.bridge.derivedCustomerBalance('c2'), 0); // بدهی c2 نزد ترب‌پی است
    expect(core.suppliers.payable(supplierId), 300_000_000 - 100_000_000);
  });

  test('موتور تطبیق ناسازگاری مصنوعی را می‌گیرد', () {
    // دستکاری مستقیم دیتابیس برای ایجاد ناسازگاری موجودی
    core.inventory.ensureProduct('px', currentQty: 5);
    core.db.db.execute('BEGIN');
    core.db.db
        .execute("UPDATE product_stock SET current_qty = 99 WHERE product_id = 'px'");
    core.db.db.execute('COMMIT');
    final checks = core.reports.reconciliationChecks();
    expect(
      checks.firstWhere((c) => c['name'] == 'موجودی = جمع حرکت‌های موجودی')['ok'],
      isFalse,
    );
  });

  test('بستن روز و تاریخچه (§38)', () {
    core.reports.saveDailyClosing(
        date: '2026-01-01', actualCash: 100_000, actualBank: 50_000, notes: 'تست');
    final history = core.reports.closingHistory();
    expect(history.length, 1);
    expect(history.first['actual_cash'], 100_000);
    // ثبت دوباره همان روز → به‌روزرسانی، نه رکورد تکراری
    core.reports.saveDailyClosing(date: '2026-01-01', actualCash: 120_000, actualBank: 50_000);
    expect(core.reports.closingHistory().length, 1);
    expect(core.reports.closingHistory().first['actual_cash'], 120_000);
  });

  test('audit log برای عملیات مهم ثبت می‌شود (§40)', () {
    core.bridge.onInvoiceSaved(sale(id: 's6'));
    core.bridge.onInvoiceDeleted('s6');
    final rows = core.audit.recent(limit: 50);
    final actions = rows.map((r) => r['action']).toList();
    expect(actions.contains('INVOICE_SALE_CREATE'), isTrue);
    expect(actions.contains('INVOICE_SALE_DELETE'), isTrue);
  });
}
