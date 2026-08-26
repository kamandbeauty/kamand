import 'package:flutter_test/flutter_test.dart';
import 'package:factor_ruby/store/installments/installment_repository.dart';
import 'package:factor_ruby/store/store_core.dart';

/// الگوهای زمان‌بندی تسویهٔ درگاه‌ها (نسخهٔ ۳) — طبق مدل کسب‌وکار کاربر:
/// - ترب‌پی: N قسط مساوی خالص، روز D ماه‌های بعدِ فروش
/// - تارا: ۲ قسط ۵۰/۵۰ با فاصلهٔ ۳۰ روزه (۳۰ و ۶۰ روز بعد)
/// - باسلام: کارمزد اول کسر؛ قسط اول X٪ + اقساط بعدی مساوی از باقیمانده؛
///   قسط اول ~۱۰ روز بعد از تحویل؛ اقساط بعدی روز D ماه‌های بعد
void main() {
  late StoreCore core;

  setUp(() {
    core = StoreCore.inMemory();
  });

  String _id(String key) => core.installments.providerByKey(key)!.id;

  test('ترب‌پی: ۴ قسط مساوی خالص در روز ۳ ماه‌های بعدِ فروش', () {
    final torob = _id('torob_pay');
    core.installments.saveProvider(
        id: torob,
        key: 'torob_pay',
        name: 'ترب‌پی',
        providerType: ProviderType.torobPay,
        commissionBps: 600,
        defaultInstallmentCount: 4,
        scheduleType: ScheduleType.monthlyWindow,
        settlementDay: 3);
    final sale = core.installments.createSale(
        providerId: torob,
        customerId: 'c1',
        customerName: 'م',
        gross: 8_000_000,
        date: '2026-01-15');
    // کارمزد ۴۸۰هزار؛ خالص ۷٬۵۲۰٬۰۰۰ → ۴ × ۱٬۸۸۰٬۰۰۰
    final rows = core.installments.settlementScheduleRows(sale.id);
    expect(rows.length, 4);
    for (final r in rows) {
      expect(r['amount'] as int, 1_880_000);
    }
    expect(rows[0]['expected_date'], '2026-02-03');
    expect(rows[1]['expected_date'], '2026-03-03');
    expect(rows[2]['expected_date'], '2026-04-03');
    expect(rows[3]['expected_date'], '2026-05-03');
    // فروش نیمهٔ ماه هم به «ماه بعد» می‌رود نه همان ماه
    expect(sale.expectedSettlementDate, '2026-05-03');
  });

  test('تارا: ۲ قسط ۵۰/۵۰ با فاصلهٔ ۳۰ روزه (۳۰ و ۶۰ روز بعد)', () {
    final tara = _id('tara');
    core.installments.saveProvider(
        id: tara,
        key: 'tara',
        name: 'تارا',
        providerType: ProviderType.tara,
        commissionBps: 200,
        defaultInstallmentCount: 2,
        scheduleType: ScheduleType.fixedInterval,
        intervalDays: 30);
    final sale = core.installments.createSale(
        providerId: tara,
        customerId: 'c1',
        customerName: 'م',
        gross: 5_000_000,
        date: '2026-01-10');
    // کارمزد ۱۰۰هزار؛ خالص ۴٬۹۰۰٬۰۰۰ → ۲ قسط (باقیمانده روی قسط اول)
    final rows = core.installments.settlementScheduleRows(sale.id);
    expect(rows.length, 2);
    expect(rows[0]['amount'] as int, 2_450_000);
    expect(rows[1]['amount'] as int, 2_450_000);
    expect(rows[0]['expected_date'], '2026-02-09'); // +۳۰ روز
    expect(rows[1]['expected_date'], '2026-03-11'); // +۶۰ روز
  });

  test('باسلام (پیش‌فرض ۵۰٪ + ۴ قسط): کارمزد اول، بعد درصد اول و بقیه مساوی', () {
    final basalam = _id('basalam');
    core.installments.saveProvider(
        id: basalam,
        key: 'basalam',
        name: 'باسلام',
        providerType: ProviderType.basalam,
        commissionBps: 400,
        scheduleType: ScheduleType.basalam,
        firstPercentBps: 5000,
        subsequentCount: 4,
        settlementDelayDays: 10,
        settlementDay: 3);
    // فاکتور ۱۰م: کارمزد ۴۰۰هزار → خالص ۹٬۶۰۰٬۰۰۰
    // قسط اول ۵۰٪ = ۴٬۸۰۰٬۰۰۰ (۱۰ روز بعد) + ۴ قسط ۱٬۲۰۰٬۰۰۰ (روز ۳ ماه‌های بعد)
    final sale = core.installments.createSale(
        providerId: basalam,
        customerId: 'c1',
        customerName: 'م',
        gross: 10_000_000,
        date: '2026-01-20');
    final rows = core.installments.settlementScheduleRows(sale.id);
    expect(rows.length, 5); // ۱ + ۴ = ۵ قسط
    expect(rows[0]['amount'] as int, 4_800_000);
    expect(rows[0]['expected_date'], '2026-01-30'); // ۱۰ روز بعد از فروش
    for (var i = 1; i <= 4; i++) {
      expect(rows[i]['amount'] as int, 1_200_000);
    }
    expect(rows[1]['expected_date'], '2026-02-03'); // روز ۳ بهمن (ماه بعدِ قسط اول)
    expect(rows[2]['expected_date'], '2026-03-03');
    // جمع برنامه دقیقاً خالص است
    expect(rows.fold(0, (a, b) => a + (b['amount'] as int)), 9_600_000);
    expect(sale.installmentCount, 5);
  });

  test('باسلام (انتخاب هنگام فروش: ۲۵٪ + ۲ قسط بعدی)', () {
    final basalam = _id('basalam');
    core.installments.saveProvider(
        id: basalam,
        key: 'basalam',
        name: 'باسلام',
        providerType: ProviderType.basalam,
        commissionBps: 400,
        scheduleType: ScheduleType.basalam,
        firstPercentBps: 5000,
        subsequentCount: 4,
        settlementDelayDays: 10);
    final sale = core.installments.createSale(
      providerId: basalam,
      customerId: 'c1',
      customerName: 'م',
      gross: 10_000_000,
      date: '2026-01-20',
      firstInstallmentPercentBps: 2500, // ۲۵٪
      subsequentCountOverride: 2,
    );
    final rows = core.installments.settlementScheduleRows(sale.id);
    expect(rows.length, 3);
    // خالص ۹٫۶م: اول ۲۵٪ = ۲٬۴۰۰٬۰۰۰؛ بقیه ۷٬۲۰۰٬۰۰۰ → ۲ × ۳٬۶۰۰٬۰۰۰
    expect(rows[0]['amount'] as int, 2_400_000);
    expect(rows[1]['amount'] as int, 3_600_000);
    expect(rows[2]['amount'] as int, 3_600_000);
  });

  test('تسویهٔ قسط‌به‌قسط: ثبت جزئی، سقف، و وضعیت تسویهٔ کامل', () {
    final torob = _id('torob_pay');
    core.installments.saveProvider(
        id: torob,
        key: 'torob_pay',
        name: 'ترب‌پی',
        providerType: ProviderType.torobPay,
        commissionBps: 600);
    final sale = core.installments.createSale(
        providerId: torob,
        customerId: 'c1',
        customerName: 'م',
        gross: 10_000_000,
        date: '2026-01-01');
    final rows = core.installments.settlementScheduleRows(sale.id);
    final first = rows.first;

    // فقط قسط اول (۲٬۳۵۰٬۰۰۰)
    core.installments.settle(
        saleId: sale.id,
        scheduleId: first['id'] as String,
        amount: 2_350_000,
        date: '2026-02-05',
        accountId: 'acc-cash');
    expect(core.accounts.balance('acc-cash'), 2_350_000);
    expect(
        core.installments.saleById(sale.id)!.status, InstallmentSaleStatus.partiallySettled);
    // بیشتر از ماندهٔ همان قسط نمی‌شود گرفت
    expect(
      () => core.installments.settle(
          saleId: sale.id,
          scheduleId: first['id'] as String,
          amount: 1,
          date: '2026-02-06',
          accountId: 'acc-cash'),
      throwsStateError,
    );
    // کل باقیمانده (۳ قسط بعدی) یک‌جا
    core.installments.settle(
        saleId: sale.id,
        amount: 2_350_000 * 3,
        date: '2026-05-05',
        accountId: 'acc-cash');
    expect(core.accounts.balance('acc-cash'), 9_400_000);
    expect(
        core.installments.saleById(sale.id)!.status, InstallmentSaleStatus.settled);
    // بیشتر از برنامه هیچ‌وقت نمی‌شود
    expect(
      () => core.installments.settle(
          saleId: sale.id, amount: 1, date: '2026-05-06', accountId: 'acc-cash'),
      throwsStateError,
    );
  });

  test('یادآور ماهانه: اقساط سررسیدرسیده برای پرسش «تسویه کرد؟»', () {
    final torob = _id('torob_pay');
    core.installments.saveProvider(
        id: torob,
        key: 'torob_pay',
        name: 'ترب‌پی',
        providerType: ProviderType.torobPay,
        commissionBps: 600);
    core.installments.createSale(
        providerId: torob,
        customerId: 'c1',
        customerName: 'م',
        gross: 10_000_000,
        date: '2026-01-01');
    // تا ۴ بهمن: هیچ قسطی سررسید نرسیده (اولین = ۳ بهمن)
    expect(core.installments.pendingSettlementConfirmations('2026-02-02').length, 0);
    // روز ۳ بهمن: قسط اول باید پرسیده شود
    final pending = core.installments.pendingSettlementConfirmations('2026-02-03');
    expect(pending.length, 1);
    expect(pending.first['provider_name'], 'ترب‌پی');
    expect((pending.first['remaining'] as num).toInt(), 2_350_000);
    // پس از ثبت تسویهٔ آن قسط، دیگر پرسیده نمی‌شود
    core.installments.settle(
        saleId: pending.first['sale_id'] as String,
        scheduleId: pending.first['id'] as String,
        amount: 2_350_000,
        date: '2026-02-05',
        accountId: 'acc-cash');
    expect(core.installments.pendingSettlementConfirmations('2026-02-05').length, 0);
  });

  test('گزارش ماهانهٔ تسویه‌ها به تفکیک درگاه + طلب تسویه‌نشده', () {
    final torob = _id('torob_pay');
    final tara = _id('tara');
    core.installments.saveProvider(
        id: torob,
        key: 'torob_pay',
        name: 'ترب‌پی',
        providerType: ProviderType.torobPay,
        commissionBps: 600);
    core.installments.saveProvider(
        id: tara,
        key: 'tara',
        name: 'تارا',
        providerType: ProviderType.tara,
        commissionBps: 200,
        scheduleType: ScheduleType.fixedInterval,
        intervalDays: 30);
    core.installments.createSale(
        providerId: torob,
        customerId: 'c1',
        customerName: 'م',
        gross: 10_000_000,
        date: '2026-01-01'); // ۴×۲٫۳۵م: بهمن/اسفند/فروردین/اردیبهشت
    core.installments.createSale(
        providerId: tara,
        customerId: 'c2',
        customerName: 'م۲',
        gross: 5_000_000,
        date: '2026-01-20'); // ۲×۲٫۴۵م: ۱۹ بهمن + ۱۹ اسفند

    final monthly = core.installments.monthlySettlementForecast();
    final feb = monthly
        .where((m) => m['ym'] == '2026-02')
        .fold<int>(0, (a, m) => a + (m['outstanding'] as int));
    expect(feb, 2_350_000 + 2_450_000); // ترب‌پی + تارا در بهمن
    expect(core.installments.providerOutstanding(torob), 9_400_000);
    expect(core.installments.providerOutstanding(tara), 4_900_000);
    // طلب کل تسویه‌نشدهٔ فروشگاه در پیش‌بینی
    final totals = core.reports.forecastTotals();
    expect(totals['expectedIncoming'], 9_400_000 + 4_900_000);
  });

  test('لغو فروش: برنامهٔ تسویه هم CANCELLED و از پیش‌بینی حذف می‌شود', () {
    final torob = _id('torob_pay');
    core.installments.saveProvider(
        id: torob,
        key: 'torob_pay',
        name: 'ترب‌پی',
        providerType: ProviderType.torobPay,
        commissionBps: 600);
    final sale = core.installments.createSale(
        providerId: torob,
        customerId: 'c1',
        customerName: 'م',
        gross: 10_000_000,
        date: '2026-01-01');
    expect(core.installments.providerOutstanding(torob), 9_400_000);
    core.installments.cancelSale(sale.id);
    expect(core.installments.providerOutstanding(torob), 0);
    expect(core.installments.pendingSettlementConfirmations('2027-01-01').length, 0);
    final rows = core.installments.settlementScheduleRows(sale.id);
    expect(rows.every((r) => r['status'] == 'CANCELLED'), isTrue);
    // رکوردها حذف فیزیکی نشده‌اند
    expect(rows.length, 4);
  });

  test('تطبیق §51: جمع برنامهٔ تسویه = خالص پس از کارمزد (هر سه الگو)', () {
    for (final key in ['torob_pay', 'tara', 'basalam']) {
      final p = core.installments.providerByKey(key)!;
      core.installments.saveProvider(
          id: p.id,
          key: p.key,
          name: p.name,
          providerType: p.providerType,
          commissionBps: 500,
          scheduleType: p.providerType == 'tara'
              ? ScheduleType.fixedInterval
              : (p.providerType == 'basalam'
                  ? ScheduleType.basalam
                  : ScheduleType.monthlyWindow),
          firstPercentBps: p.providerType == 'basalam' ? 2500 : 0,
          subsequentCount: p.providerType == 'basalam' ? 2 : 0,
          settlementDelayDays: p.providerType == 'basalam' ? 10 : 0);
      core.installments.createSale(
          providerId: p.id,
          customerId: 'c9',
          customerName: 'م',
          gross: 1_000_001, // مبلغ عمداً نامساوی برای تست تقسیم دقیق
          date: '2026-01-05');
    }
    final checks = core.reports.reconciliationChecks();
    final check = checks.firstWhere(
        (c) => c['name'] == 'جمع برنامهٔ تسویه = خالص پس از کارمزد');
    expect(check['ok'], isTrue, reason: check['detail'] as String?);
  });
}
