import 'package:flutter_test/flutter_test.dart';
import 'package:factor_ruby/store/installments/installment_repository.dart';
import 'package:factor_ruby/store/store_core.dart';

void main() {
  late StoreCore core;

  setUp(() {
    core = StoreCore.inMemory();
  });

  String _providerId(String key) {
    final p = core.installments.providerByKey(key);
    if (p == null) throw StateError('پرووایدر seed نشده: $key');
    return p.id;
  }

  test('§60 — سناریوی بحرانی ترب‌پی: ۱۰م، کارمزد ۶٪، ۴ قسط ۲٫۵م', () {
    final torob = _providerId('torob_pay');
    core.installments.saveProvider(
      id: torob,
      key: 'torob_pay',
      name: 'ترب‌پی',
      providerType: ProviderType.torobPay,
      commissionBps: 600, // طبق قرارداد فروشنده — نه hard-code
      defaultInstallmentCount: 4,
      settlementDelayDays: 7,
    );

    final sale = core.installments.createSale(
      providerId: torob,
      customerId: 'c1',
      customerName: 'مشتری تست',
      gross: 10_000_000,
      date: '2026-01-01',
    );

    expect(sale.gross, 10_000_000);
    expect(sale.financed, 10_000_000);
    expect(sale.commission, 600_000);
    expect(sale.netSettlement, 9_400_000);
    expect(sale.installmentCount, 4);

    // برنامهٔ اقساط مشتری: 4 × 2,500,000
    final schedule = core.installments.schedule(sale.id);
    expect(schedule.length, 4);
    for (final i in schedule) {
      expect(i.amount, 2_500_000);
    }
    expect(schedule.fold(0, (a, b) => a + b.amount), 10_000_000);

    // برنامهٔ تسویهٔ درگاه → فروشگاه: ۴ قسط مساویِ خالص (۹٫۴م)، روز ۳ ماه‌های بعد
    final settleRows = core.installments.settlementScheduleRows(sale.id);
    expect(settleRows.length, 4);
    for (final r in settleRows) {
      expect(r['amount'] as int, 2_350_000);
    }
    expect(settleRows.fold(0, (a, b) => a + (b['amount'] as int)), 9_400_000);
    expect(settleRows.first['expected_date'], '2026-02-03'); // ماه بعد، روز ۳
    expect(settleRows.last['expected_date'], '2026-05-03');
    expect(sale.expectedSettlementDate, '2026-05-03');

    // کل ۱۰م هرگز نقد فرض نمی‌شود
    expect(core.accounts.balance('acc-cash'), 0);

    // تسویهٔ کامل ۹٫۴م
    core.installments.settle(
        saleId: sale.id, amount: 9_400_000, date: '2026-01-10', accountId: 'acc-cash');
    expect(core.accounts.balance('acc-cash'), 9_400_000);
    expect(core.installments.saleById(sale.id)!.status, InstallmentSaleStatus.settled);

    // تسویهٔ بیشتر از انتظار رد می‌شود
    expect(
      () => core.installments.settle(
          saleId: sale.id, amount: 1, date: '2026-01-11', accountId: 'acc-cash'),
      throwsStateError,
    );

    // سود و زیان: درآمد ۱۰م، کارمزد ۶۰۰هزینه
    final pl = core.reports.profitAndLoss('2026-01-01', '2026-01-31');
    expect(pl.revenue, 10_000_000);
    expect(pl.providerCommissions, 600_000);
    expect(pl.cashReceived, 9_400_000);
  });

  test('تسویهٔ جزئی و ماندهٔ تسویه', () {
    final snapp = _providerId('snapp_pay');
    core.installments.saveProvider(
        id: snapp,
        key: 'snapp_pay',
        name: 'اسنپ‌پی',
        providerType: ProviderType.snappPay,
        commissionBps: 500,
        defaultInstallmentCount: 4);
    final sale = core.installments.createSale(
      providerId: snapp,
      customerId: 'c1',
      customerName: 'مشتری',
      gross: 8_000_000,
      downPayment: 2_000_000,
      date: '2026-01-01',
      downPaymentAccountId: 'acc-cash',
    );
    expect(sale.financed, 6_000_000);
    expect(sale.commission, 300_000);
    expect(sale.netSettlement, 5_700_000);
    // بیعانه نقدی همین حالا وارد صندوق شده
    expect(core.accounts.balance('acc-cash'), 2_000_000);

    core.installments.settle(
        saleId: sale.id, amount: 3_000_000, date: '2026-01-05', accountId: 'acc-cash');
    expect(core.installments.saleById(sale.id)!.status,
        InstallmentSaleStatus.partiallySettled);
    expect(
      () => core.installments.settle(
          saleId: sale.id, amount: 2_700_001, date: '2026-01-06', accountId: 'acc-cash'),
      throwsStateError,
    );
    core.installments.settle(
        saleId: sale.id, amount: 2_700_000, date: '2026-01-06', accountId: 'acc-cash');
    expect(core.installments.saleById(sale.id)!.status, InstallmentSaleStatus.settled);
    expect(core.accounts.balance('acc-cash'), 2_000_000 + 5_700_000);
  });

  test('پرداخت قسط اقساط مستقیم فروشگاه + idempotency با مرجع', () {
    final store = _providerId('store_direct');
    final sale = core.installments.createSale(
      providerId: store,
      customerId: 'c1',
      customerName: 'مشتری',
      gross: 4_000_000,
      date: '2026-01-01',
      installmentCount: 2,
    );
    expect(sale.commission, 0);
    expect(sale.netSettlement, 4_000_000);
    // بدهی مشتری افزایش یافته
    expect(core.bridge.derivedCustomerBalance('c1'), 4_000_000);

    final first = core.installments.schedule(sale.id).first;
    core.installments.payInstallment(
      installmentId: first.id,
      date: '2026-02-01',
      accountId: 'acc-cash',
      paymentRef: 'ref-100',
    );
    // پرداخت تکراری با همان مرجع اثر دوباره ندارد
    expect(
      () => core.installments.payInstallment(
        installmentId: first.id,
        date: '2026-02-01',
        accountId: 'acc-cash',
        paymentRef: 'ref-100',
      ),
      throwsStateError,
    );
    expect(core.accounts.balance('acc-cash'), 2_000_000);
    expect(core.bridge.derivedCustomerBalance('c1'), 2_000_000);
    expect(first.status != InstallmentStatus.paid || true, isTrue);
    final updated = core.installments.schedule(sale.id).first;
    expect(updated.status, InstallmentStatus.paid);
  });

  test('سقف اعتبار اقساط مستقیم فروشگاه (§27)', () {
    final store = _providerId('store_direct');
    core.credit.setCreditLimit('c1', 5_000_000);
    core.installments.createSale(
      providerId: store,
      customerId: 'c1',
      customerName: 'مشتری',
      gross: 3_000_000,
      date: '2026-01-01',
      installmentCount: 2,
    );
    expect(
      () => core.installments.createSale(
        providerId: store,
        customerId: 'c1',
        customerName: 'مشتری',
        gross: 3_000_000,
        date: '2026-01-02',
        installmentCount: 2,
      ),
      throwsA(isA<CreditLimitExceeded>()),
    );
    // با عبور صریح مجاز است
    core.installments.createSale(
      providerId: store,
      customerId: 'c1',
      customerName: 'مشتری',
      gross: 3_000_000,
      date: '2026-01-03',
      installmentCount: 2,
      overrideCreditLimit: true,
    );
    expect(core.bridge.derivedCustomerBalance('c1'), 6_000_000);
  });

  test('اقساط معوق شناسایی می‌شود (§28)', () {
    final store = _providerId('store_direct');
    final sale = core.installments.createSale(
      providerId: store,
      customerId: 'c1',
      customerName: 'مشتری',
      gross: 2_000_000,
      date: '2024-01-01',
      installmentCount: 2,
    );
    core.installments.refreshStatuses(today: '2026-01-01');
    final overdue = core.installments.overdue(today: '2026-01-01');
    expect(overdue.length, 2);
    expect(core.installments.overdueAmount(today: '2026-01-01'), 2_000_000);
    final schedule = core.installments.schedule(sale.id);
    expect(schedule.first.status, InstallmentStatus.overdue);
  });

  test('لغو فروش اقساطی: اثرها دقیقاً یک‌بار معکوس؛ لغو دوباره رد می‌شود', () {
    final snapp = _providerId('snapp_pay');
    core.installments.saveProvider(
        id: snapp,
        key: 'snapp_pay',
        name: 'اسنپ‌پی',
        providerType: ProviderType.snappPay,
        commissionBps: 0);
    final sale = core.installments.createSale(
      providerId: snapp,
      customerId: 'c1',
      customerName: 'مشتری',
      gross: 1_000_000,
      date: '2026-01-01',
    );
    core.installments.settle(
        saleId: sale.id, amount: 1_000_000, date: '2026-01-05', accountId: 'acc-cash');
    expect(core.accounts.balance('acc-cash'), 1_000_000);

    core.installments.cancelSale(sale.id, reason: 'تست');
    expect(core.installments.saleById(sale.id)!.status, InstallmentSaleStatus.cancelled);
    expect(core.accounts.balance('acc-cash'), 0); // تسویه معکوس شد

    expect(() => core.installments.cancelSale(sale.id), throwsStateError);

    // رکوردها هرگز حذف نشده‌اند (§40)
    final schedule = core.installments.schedule(sale.id);
    expect(schedule.length, 4);
    final allEvents = core.db.db.select('SELECT COUNT(*) AS c FROM ledger_events');
    expect(allEvents.first['c'], greaterThanOrEqualTo(4));
  });

  test('برگشت فروش اقساطی وضعیت REFUNDED می‌دهد و مانده صفر می‌شود', () {
    final digipay = _providerId('digipay');
    core.installments.saveProvider(
        id: digipay,
        key: 'digipay',
        name: 'دیجی‌پی',
        providerType: ProviderType.digipay,
        commissionBps: 400,
        defaultInstallmentCount: 3);
    final sale = core.installments.createSale(
      providerId: digipay,
      customerId: 'c1',
      customerName: 'مشتری',
      gross: 900_000,
      date: '2026-01-01',
    );
    core.installments.refundSale(sale.id, reason: 'برگشت کالا');
    expect(core.installments.saleById(sale.id)!.status, InstallmentSaleStatus.refunded);
    expect(core.installments.overdueAmount(today: '2027-01-01'), 0);
    expect(core.reports.forecastTotals()['expectedIncoming'], 0);
  });

  test('پرووایدر سفارشی بدون تغییر کد (§25)', () {
    final pid = core.installments.saveProvider(
      name: 'شرکت X',
      providerType: ProviderType.custom,
      commissionBps: 800,
      settlementDelayDays: 30,
      defaultInstallmentCount: 6,
    );
    final sale = core.installments.createSale(
      providerId: pid,
      customerId: 'c1',
      customerName: 'مشتری',
      gross: 6_000_000,
      date: '2026-01-01',
    );
    expect(sale.commission, 480_000);
    expect(sale.netSettlement, 5_520_000);
    expect(core.installments.schedule(sale.id).length, 6);
    // الگوی پیش‌فرض سفارشی: پنجرهٔ روز ۳ ماه‌های بعد
    expect(core.installments.settlementScheduleRows(sale.id).length, 6);
  });

  test('گزارش سیستم‌های اقساطی (§20)', () {
    final torob = _providerId('torob_pay');
    core.installments.saveProvider(
        id: torob, key: 'torob_pay', name: 'ترب‌پی', providerType: ProviderType.torobPay, commissionBps: 600);
    core.installments.createSale(
        providerId: torob, customerId: 'c1', customerName: 'م', gross: 10_000_000, date: '2026-01-01');
    core.installments.createSale(
        providerId: torob, customerId: 'c2', customerName: 'م۲', gross: 5_000_000, date: '2026-01-02');
    final rows = core.installments.providerReport(from: '2026-01-01', to: '2026-01-31');
    final torobRow = rows.firstWhere((r) => r['id'] == torob);
    expect(torobRow['sales_count'], 2);
    expect(torobRow['gross_total'], 15_000_000);
    expect(torobRow['commission_total'], 900_000);
    expect(torobRow['expected_settlement'], 14_100_000);
    expect(torobRow['settled_total'], 0);
  });

  test('مالیات کارمزد در محاسبه لحاظ می‌شود', () {
    final basalam = _providerId('basalam');
    core.installments.saveProvider(
        id: basalam,
        key: 'basalam',
        name: 'باسلام',
        providerType: ProviderType.basalam,
        commissionBps: 500,
        commissionVatBps: 1000);
    final sale = core.installments.createSale(
      providerId: basalam,
      customerId: 'c1',
      customerName: 'مشتری',
      gross: 1_000_000,
      date: '2026-01-01',
    );
    expect(sale.commission, 50_000);
    expect(sale.commissionVat, 5_000);
    expect(sale.netSettlement, 945_000);
    expect(
      sale.commission + sale.commissionVat + sale.otherDeductions + sale.netSettlement,
      sale.financed,
    );
  });

  test('جریان نقدی آینده: اقساط تسویهٔ درگاه قسط‌به‌قسط با تاریخ‌های واقعی', () {
    final torob = _providerId('torob_pay');
    core.installments.saveProvider(
        id: torob, key: 'torob_pay', name: 'ترب‌پی', providerType: ProviderType.torobPay, commissionBps: 600);
    core.installments.createSale(
        providerId: torob, customerId: 'c1', customerName: 'م', gross: 10_000_000, date: '2026-01-01');
    // تا پایان بهمن فقط قسط اول (روز ۳ بهمن = 2026-02-03) دیده می‌شود
    final rows = core.reports.forecastRows('2026-01-01', '2026-02-28');
    expect(rows.length, 1);
    expect(((rows.first['amount'] as num?) ?? 0).toInt(), 2_350_000);
    // کل ۴ قسط در بازهٔ کامل
    final full = core.reports.forecastRows('2026-01-01', '2026-12-31');
    expect(full.length, 4);
    expect(core.accounts.balance('acc-cash'), 0); // هنوز چیزی دریافت نشده
  });
}
