import '../core/accounts.dart';
import '../core/audit.dart';
import '../core/money.dart';
import '../db/store_database.dart';

/// انواع سیستم اقساطی: هیچ‌کدام API واقعی ندارند؛ همه MANUAL/قابل‌پیکربندی هستند (§54، §55)
class ProviderType {
  static const snappPay = 'snapp_pay';
  static const torobPay = 'torob_pay';
  static const digipay = 'digipay';
  static const tara = 'tara'; // تارا: ۲ قسط با فاصلهٔ ۳۰ روزه
  static const basalam = 'basalam';
  static const store = 'store'; // اقساط مستقیم فروشگاه (§26)
  static const custom = 'custom';
}

/// الگوی زمان‌بندی تسویهٔ درگاه → فروشگاه
class ScheduleType {
  /// پنجرهٔ روزهای ماه (مثل ترب‌پی): روز N از ماه‌های بعدِ فروش، تعداد قسط مساوی
  static const monthlyWindow = 'monthly_window';
  /// فاصلهٔ ثابت (مثل تارا): هر قسط X روز بعد (۳۰/۶۰ روز)
  static const fixedInterval = 'fixed_interval';
  /// باسلام: درصد اول (مثلاً ۲۵٪/۵۰٪) + N قسط بعدی مساوی از باقیمانده
  static const basalam = 'basalam';
}

/// وضعیت فروش اقساطی (§14)
class InstallmentSaleStatus {
  static const created = 'CREATED';
  static const authorized = 'AUTHORIZED';
  static const settled = 'SETTLED';
  static const partiallySettled = 'PARTIALLY_SETTLED';
  static const cancelled = 'CANCELLED';
  static const failed = 'FAILED';
  static const refunded = 'REFUNDED';
}

/// وضعیت هر قسط (§16)
class InstallmentStatus {
  static const pending = 'PENDING';
  static const due = 'DUE';
  static const paid = 'PAID';
  static const overdue = 'OVERDUE';
  static const cancelled = 'CANCELLED';
  static const waived = 'WAIVED';
}

class InstallmentProviderEntity {
  final String id;
  final String key;
  final String name;
  final String providerType;
  final int commissionBps; // ×۱۰۰ (۶٪ = ۶۰۰) — قابل‌پیکربندی، هرگز hard-code نیست
  final int commissionFixed;
  final int commissionVatBps;
  final int otherDeductions;
  final int settlementDelayDays;
  final int defaultInstallmentCount;
  final String settlementFrequency;
  final String customerPaymentModel;
  final String notes;
  final String contractRef;
  final bool isEnabled;
  // الگوی تسویه (نسخهٔ ۳)
  final String scheduleType;
  final int settlementDay; // روز مرجع پنجرهٔ «۱ تا ۵ ماه» (پیش‌فرض ۳)
  final int intervalDays; // فاصلهٔ اقساط الگوی fixed_interval (تارا: ۳۰)
  final int firstPercentBps; // باسلام: درصد قسط اول ×۱۰۰ (۵۰٪ = ۵۰۰۰)
  final int subsequentCount; // باسلام: تعداد اقساط بعد از قسط اول

  const InstallmentProviderEntity({
    required this.id,
    required this.key,
    required this.name,
    required this.providerType,
    this.commissionBps = 0,
    this.commissionFixed = 0,
    this.commissionVatBps = 0,
    this.otherDeductions = 0,
    this.settlementDelayDays = 0,
    this.defaultInstallmentCount = 4,
    this.settlementFrequency = 'per_sale',
    this.customerPaymentModel = '',
    this.notes = '',
    this.contractRef = '',
    this.isEnabled = true,
    this.scheduleType = ScheduleType.monthlyWindow,
    this.settlementDay = 3,
    this.intervalDays = 30,
    this.firstPercentBps = 0,
    this.subsequentCount = 0,
  });

  bool get isStore => providerType == ProviderType.store;

  factory InstallmentProviderEntity.fromRow(Map<String, Object?> r) =>
      InstallmentProviderEntity(
        id: r['id'] as String,
        key: r['key'] as String,
        name: r['name'] as String,
        providerType: r['provider_type'] as String,
        commissionBps: r['commission_bps'] as int,
        commissionFixed: r['commission_fixed'] as int,
        commissionVatBps: r['commission_vat_bps'] as int,
        otherDeductions: r['other_deductions'] as int,
        settlementDelayDays: r['settlement_delay_days'] as int,
        defaultInstallmentCount: r['default_installment_count'] as int,
        settlementFrequency: r['settlement_frequency'] as String,
        customerPaymentModel: (r['customer_payment_model'] ?? '') as String,
        notes: (r['notes'] ?? '') as String,
        contractRef: (r['contract_ref'] ?? '') as String,
        isEnabled: (r['is_enabled'] as int) == 1,
        scheduleType: (r['schedule_type'] ?? ScheduleType.monthlyWindow) as String,
        settlementDay: (r['settlement_day'] ?? 3) as int,
        intervalDays: (r['interval_days'] ?? 30) as int,
        firstPercentBps: (r['first_percent_bps'] ?? 0) as int,
        subsequentCount: (r['subsequent_count'] ?? 0) as int,
      );
}

class InstallmentSaleEntity {
  final String id;
  final String? invoiceId;
  final String invoiceNumber;
  final String customerId;
  final String customerName;
  final String providerId;
  final String saleDate;
  final int gross;
  final int downPayment;
  final int financed;
  final int commission;
  final int commissionVat;
  final int otherDeductions;
  final int netSettlement;
  final String? expectedSettlementDate;
  final int installmentCount;
  final String firstDueDate;
  final int frequencyDays;
  final String status;

  const InstallmentSaleEntity({
    required this.id,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.customerId,
    required this.customerName,
    required this.providerId,
    required this.saleDate,
    required this.gross,
    required this.downPayment,
    required this.financed,
    required this.commission,
    required this.commissionVat,
    required this.otherDeductions,
    required this.netSettlement,
    required this.expectedSettlementDate,
    required this.installmentCount,
    required this.firstDueDate,
    required this.frequencyDays,
    required this.status,
  });

  factory InstallmentSaleEntity.fromRow(Map<String, Object?> r) =>
      InstallmentSaleEntity(
        id: r['id'] as String,
        invoiceId: r['invoice_id'] as String?,
        invoiceNumber: (r['invoice_number'] ?? '') as String,
        customerId: r['customer_id'] as String,
        customerName: (r['customer_name'] ?? '') as String,
        providerId: r['provider_id'] as String,
        saleDate: r['sale_date'] as String,
        gross: r['gross'] as int,
        downPayment: r['down_payment'] as int,
        financed: r['financed'] as int,
        commission: r['commission'] as int,
        commissionVat: r['commission_vat'] as int,
        otherDeductions: r['other_deductions'] as int,
        netSettlement: r['net_settlement'] as int,
        expectedSettlementDate: r['expected_settlement_date'] as String?,
        installmentCount: r['installment_count'] as int,
        firstDueDate: r['first_due_date'] as String,
        frequencyDays: r['frequency_days'] as int,
        status: r['status'] as String,
      );
}

class InstallmentEntity {
  final String id;
  final String saleId;
  final int number;
  final int amount;
  final String dueDate;
  final String? paidDate;
  final int paidAmount;
  final String status;
  final String paymentRef;
  final String? accountId;

  const InstallmentEntity({
    required this.id,
    required this.saleId,
    required this.number,
    required this.amount,
    required this.dueDate,
    this.paidDate,
    required this.paidAmount,
    required this.status,
    this.paymentRef = '',
    this.accountId,
  });

  int get remaining => amount - paidAmount;
  bool get isOpen =>
      status == InstallmentStatus.pending ||
      status == InstallmentStatus.due ||
      status == InstallmentStatus.overdue;
}

class CreditLimitExceeded implements Exception {
  final String message;
  const CreditLimitExceeded(this.message);
  @override
  String toString() => message;
}

/// موتور عمومی اقساط — برای هر سیستم اقساطی (اسنپ‌پی، ترب‌پی، دیجی‌پی، باسلام،
/// فروشگاه، سفارشی) با شرایط قراردادی قابل‌پیکربندی کار می‌کند.
class InstallmentRepository {
  final StoreDatabase store;
  final LedgerRepository ledger;
  final AuditLog audit;
  final CustomerCreditRepository credit;
  InstallmentRepository(this.store, this.ledger, this.audit, this.credit);

  // ---------------------------------------------------------------------
  // پیکربندی سیستم‌های اقساطی (§21–§25)
  // ---------------------------------------------------------------------

  List<InstallmentProviderEntity> providers({bool onlyEnabled = false}) {
    final rows = onlyEnabled
        ? store.db
            .select('SELECT * FROM installment_providers WHERE is_enabled = 1 ORDER BY created_at')
        : store.db.select('SELECT * FROM installment_providers ORDER BY created_at');
    return rows.map(InstallmentProviderEntity.fromRow).toList();
  }

  InstallmentProviderEntity? providerById(String id) {
    final rows =
        store.db.select('SELECT * FROM installment_providers WHERE id = ?', [id]);
    return rows.isEmpty ? null : InstallmentProviderEntity.fromRow(rows.first);
  }

  InstallmentProviderEntity? providerByKey(String key) {
    final rows =
        store.db.select('SELECT * FROM installment_providers WHERE key = ?', [key]);
    return rows.isEmpty ? null : InstallmentProviderEntity.fromRow(rows.first);
  }

  String saveProvider({
    required String name,
    required String providerType,
    String? id,
    String? key,
    int commissionBps = 0,
    int commissionFixed = 0,
    int commissionVatBps = 0,
    int otherDeductions = 0,
    int settlementDelayDays = 0,
    int defaultInstallmentCount = 4,
    String settlementFrequency = 'per_sale',
    String customerPaymentModel = '',
    String notes = '',
    String contractRef = '',
    bool isEnabled = true,
    String scheduleType = ScheduleType.monthlyWindow,
    int settlementDay = 3,
    int intervalDays = 30,
    int firstPercentBps = 0,
    int subsequentCount = 0,
  }) {
    final pid = id ?? 'prov-${newId()}';
    final pkey = key ?? 'custom-${newId()}';
    store.db.execute(
      'INSERT INTO installment_providers (id, key, name, provider_type, commission_bps, commission_fixed, commission_vat_bps, other_deductions, settlement_delay_days, default_installment_count, settlement_frequency, customer_payment_model, notes, contract_ref, is_enabled, created_at, schedule_type, settlement_day, interval_days, first_percent_bps, subsequent_count) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) '
      'ON CONFLICT(id) DO UPDATE SET name = excluded.name, provider_type = excluded.provider_type, '
      'commission_bps = excluded.commission_bps, commission_fixed = excluded.commission_fixed, '
      'commission_vat_bps = excluded.commission_vat_bps, other_deductions = excluded.other_deductions, '
      'settlement_delay_days = excluded.settlement_delay_days, default_installment_count = excluded.default_installment_count, '
      'settlement_frequency = excluded.settlement_frequency, customer_payment_model = excluded.customer_payment_model, '
      'notes = excluded.notes, contract_ref = excluded.contract_ref, is_enabled = excluded.is_enabled, '
      'schedule_type = excluded.schedule_type, settlement_day = excluded.settlement_day, '
      'interval_days = excluded.interval_days, first_percent_bps = excluded.first_percent_bps, '
      'subsequent_count = excluded.subsequent_count',
      [
        pid,
        pkey,
        name,
        providerType,
        commissionBps,
        commissionFixed,
        commissionVatBps,
        otherDeductions,
        settlementDelayDays,
        defaultInstallmentCount,
        settlementFrequency,
        customerPaymentModel,
        notes,
        contractRef,
        isEnabled ? 1 : 0,
        DateTime.now().toIso8601String(),
        scheduleType,
        settlementDay,
        intervalDays,
        firstPercentBps,
        subsequentCount,
      ],
    );
    audit.log(id == null ? 'PROVIDER_CREATE' : 'PROVIDER_UPDATE',
        'installment_provider', pid, name);
    return pid;
  }

  // ---------------------------------------------------------------------
  // ایجاد فروش اقساطی (§14، §15)
  // ---------------------------------------------------------------------

  /// ایجاد فروش اقساطی با محاسبهٔ شفاف کارمزد بر اساس قرارداد پیکربندی‌شده.
  ///
  /// برای سیستم‌های خارجی: بدهی مشتری نزد سیستم است، نه فروشگاه؛ بنابراین
  /// customer_delta فقط برای اقساط مستقیم فروشگاه ثبت می‌شود.
  InstallmentSaleEntity createSale({
    required String providerId,
    required String customerId,
    required String customerName,
    required int gross,
    required String date,
    int downPayment = 0,
    int? installmentCount,
    String? firstDueDate,
    int? frequencyDays,
    String? invoiceId,
    String invoiceNumber = '',
    String downPaymentAccountId = '',
    String notes = '',
    bool overrideCreditLimit = false,
    int? firstInstallmentPercentBps,
    int? subsequentCountOverride,
  }) {
    final provider = providerById(providerId);
    if (provider == null) throw StateError('سیستم اقساطی پیدا نشد');
    if (!provider.isEnabled) throw StateError('این سیستم اقساطی غیرفعال است');
    if (gross <= 0) throw ArgumentError('مبلغ فروش باید مثبت باشد');
    if (downPayment < 0 || downPayment > gross) {
      throw ArgumentError('بیعانه باید بین صفر تا کل مبلغ باشد');
    }
    final financed = gross - downPayment;
    if (financed <= 0) throw ArgumentError('مبلغ تأمین‌شده باید مثبت باشد');
    final count = installmentCount ?? provider.defaultInstallmentCount;
    if (count < 1) throw ArgumentError('تعداد اقساط باید حداقل ۱ باشد');

    // محاسبهٔ کارمزد فقط برای سیستم‌های خارجی؛ اقساط مستقیم فروشگاه کارمزدی ندارد
    int commission = 0;
    int commissionVat = 0;
    int otherDeductions = 0;
    int netSettlement = financed;
    if (!provider.isStore) {
      final breakdown = CommissionCalculator.calculate(
        grossFinanced: financed,
        commissionBps: provider.commissionBps,
        commissionFixed: provider.commissionFixed,
        commissionVatBps: provider.commissionVatBps,
        otherDeductions: provider.otherDeductions,
      );
      commission = breakdown.commission;
      commissionVat = breakdown.commissionVat;
      otherDeductions = breakdown.otherDeductions;
      netSettlement = breakdown.netSettlement;
    }

    // اعتبارسنجی سقف اعتبار برای اقساط مستقیم فروشگاه (§27)
    if (provider.isStore && !overrideCreditLimit) {
      final used = outstandingStoreDebt(customerId);
      final limit = credit.creditLimit(customerId);
      if (limit > 0 && used + financed > limit) {
        throw CreditLimitExceeded(
            'سقف اعتبار تکمیل است: سقف $limit، استفاده‌شده $used، درخواست $financed');
      }
    }

    final saleId = 'isal-${newId()}';
    final due = firstDueDate ?? _addDays(date, 30);
    final freq = frequencyDays ?? 30;

    // ── برنامهٔ تسویهٔ درگاه → فروشگاه (نسخهٔ ۳) ──
    // تاریخ‌ها و مبلغ‌ها طبق الگوی پیکربندی‌شدهٔ هر درگاه؛
    // غیر از باسلام: خالص (پس از کارمزد) به‌تساوی بین همهٔ اقساط؛
    // باسلام: درصد اول + بقیه مساوی از باقیمانده.
    final planDates = <String>[];
    var planCount = count;
    var firstPct = provider.firstPercentBps;
    var restCount = provider.subsequentCount;
    if (provider.isStore) {
      planDates.addAll([
        for (var i = 0; i < count; i++) _addDays(due, freq * i),
      ]);
    } else if (provider.scheduleType == ScheduleType.fixedInterval) {
      planDates.addAll([
        for (var i = 1; i <= count; i++)
          _addDays(date, provider.intervalDays * i),
      ]);
    } else if (provider.scheduleType == ScheduleType.basalam) {
      if (firstInstallmentPercentBps != null) firstPct = firstInstallmentPercentBps;
      if (subsequentCountOverride != null && subsequentCountOverride > 0) {
        restCount = subsequentCountOverride;
      }
      if (restCount <= 0) restCount = 1;
      if (firstPct <= 0) firstPct = 5000;
      if (firstPct > 10000) firstPct = 10000;
      planCount = 1 + restCount;
      final firstDate = _addDays(date, provider.settlementDelayDays);
      planDates.add(firstDate);
      for (var i = 1; i <= restCount; i++) {
        planDates.add(_dayOfMonth(firstDate, i, provider.settlementDay));
      }
    } else {
      // پنجرهٔ روزهای ماه (ترب‌پی و مانند آن): روز مرجعِ ماه‌های بعدِ فروش
      planDates.addAll([
        for (var i = 1; i <= count; i++)
          _dayOfMonth(date, i, provider.settlementDay),
      ]);
    }

    // مبلغ‌ها: الگوی تسهیم روی هر پایه (financed برای مشتری، net برای درگاه)
    List<int> _split(int total) {
      if (provider.scheduleType == ScheduleType.basalam && !provider.isStore) {
        final first = Money.percentOf(total, firstPct);
        return [
          first,
          ...Money.splitEvenly(total - first, planCount - 1),
        ];
      }
      return Money.splitEvenly(total, planCount);
    }

    final customerAmounts = _split(financed);
    final settlementAmounts = provider.isStore
        ? const <int>[]
        : _split(netSettlement);

    store.txn(() {
      store.db.execute(
        'INSERT INTO installment_sales (id, invoice_id, invoice_number, customer_id, customer_name, provider_id, sale_date, gross, down_payment, financed, commission, commission_vat, other_deductions, net_settlement, expected_settlement_date, installment_count, first_due_date, frequency_days, status, notes, created_at) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          saleId,
          invoiceId,
          invoiceNumber,
          customerId,
          customerName,
          providerId,
          date,
          gross,
          downPayment,
          financed,
          commission,
          commissionVat,
          otherDeductions,
          netSettlement,
          planDates.isEmpty
              ? null
              : (provider.isStore ? planDates[0] : planDates.last),
          planCount,
          due,
          freq,
          InstallmentSaleStatus.created,
          notes,
          DateTime.now().toIso8601String(),
        ],
      );
      // برنامهٔ اقساط مشتری: جمع دقیقاً برابر مبلغ تأمین‌شده (§50)
      for (var i = 0; i < planCount; i++) {
        store.db.execute(
          'INSERT INTO installments (id, sale_id, number, amount, due_date, paid_amount, status, created_at) '
          'VALUES (?,?,?,?,?,0,?,?)',
          [
            'ist-${newId()}',
            saleId,
            i + 1,
            customerAmounts[i],
            planDates[i],
            InstallmentStatus.pending,
            DateTime.now().toIso8601String(),
          ],
        );
      }
      // برنامهٔ تسویهٔ درگاه: جمع دقیقاً برابر خالص پس از کارمزد
      for (var i = 0; i < settlementAmounts.length; i++) {
        store.db.execute(
          'INSERT INTO settlement_schedule (id, sale_id, provider_id, number, amount, expected_date, received_amount, status, created_at) '
          'VALUES (?,?,?,?,?,?,0,?,?)',
          [
            'ssch-${newId()}',
            saleId,
            providerId,
            i + 1,
            settlementAmounts[i],
            planDates[i],
            'PENDING',
            DateTime.now().toIso8601String(),
          ],
        );
      }

      // رویدادهای مالی:
      // ۱) ایجاد اقساط — فقط برای فروشگاه، بدهی مشتری ایجاد می‌کند
      ledger.append(LedgerEntryInput(
        eventType: LedgerEventType.installmentCreated,
        date: date,
        amount: financed,
        customerId: provider.isStore ? customerId : null,
        providerId: providerId,
        installmentId: saleId,
        customerDelta: provider.isStore ? financed : 0,
        description: 'فروش اقساطی ${provider.name} — $customerName',
        idempotencyKey: 'installment-sale:$saleId',
      ));
      // ۲) بیعانه نقدی دریافت‌شده
      if (downPayment > 0 && downPaymentAccountId.isNotEmpty) {
        ledger.append(LedgerEntryInput(
          eventType: LedgerEventType.paymentReceived,
          date: date,
          amount: downPayment,
          direction: 1,
          accountId: downPaymentAccountId,
          customerId: customerId,
          installmentId: saleId,
          customerDelta: provider.isStore ? -downPayment : 0,
          reference: 'بیعانه فروش اقساطی',
          idempotencyKey: 'installment-down:$saleId',
        ));
      }
      // ۳) کارمزد سیستم اقساطی — هزینهٔ دوره (نه وجه دریافتی)
      if (commission + commissionVat > 0) {
        ledger.append(LedgerEntryInput(
          eventType: LedgerEventType.providerCommission,
          date: date,
          amount: commission + commissionVat,
          providerId: providerId,
          installmentId: saleId,
          description: 'کارمزد ${provider.name} (+ مالیات)',
          idempotencyKey: 'installment-commission:$saleId',
        ));
      }
    });
    audit.log('INSTALLMENT_CREATE', 'installment_sale', saleId,
        '${provider.name} — $gross تومان — $planCount قسط');
    return saleById(saleId)!;
  }

  String _dayOfMonth(String baseDate, int monthOffset, int day) {
    final base = DateTime.parse(baseDate);
    final d = DateTime(base.year, base.month + monthOffset, day);
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  InstallmentSaleEntity? saleById(String id) {
    final rows =
        store.db.select('SELECT * FROM installment_sales WHERE id = ?', [id]);
    return rows.isEmpty ? null : InstallmentSaleEntity.fromRow(rows.first);
  }

  List<InstallmentSaleEntity> sales({
    String? customerId,
    String? providerId,
    String? from,
    String? to,
    String? status,
    int limit = 200,
  }) {
    final where = <String>['1=1'];
    final args = <Object?>[];
    if (customerId != null) {
      where.add('customer_id = ?');
      args.add(customerId);
    }
    if (providerId != null) {
      where.add('provider_id = ?');
      args.add(providerId);
    }
    if (from != null) {
      where.add('sale_date >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('sale_date <= ?');
      args.add(to);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    args.add(limit);
    return store.db
        .select(
            'SELECT * FROM installment_sales WHERE ${where.join(' AND ')} ORDER BY created_at DESC LIMIT ?',
            args)
        .map(InstallmentSaleEntity.fromRow)
        .toList();
  }

  List<InstallmentEntity> schedule(String saleId) {
    final rows = store.db.select(
        'SELECT * FROM installments WHERE sale_id = ? ORDER BY number', [saleId]);
    return rows
        .map((r) => InstallmentEntity(
              id: r['id'] as String,
              saleId: r['sale_id'] as String,
              number: r['number'] as int,
              amount: r['amount'] as int,
              dueDate: r['due_date'] as String,
              paidDate: r['paid_date'] as String?,
              paidAmount: r['paid_amount'] as int,
              status: r['status'] as String,
              paymentRef: (r['payment_ref'] ?? '') as String,
              accountId: r['account_id'] as String?,
            ))
        .toList();
  }

  InstallmentEntity? installmentById(String id) {
    final rows = store.db.select('SELECT * FROM installments WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return InstallmentEntity(
      id: r['id'] as String,
      saleId: r['sale_id'] as String,
      number: r['number'] as int,
      amount: r['amount'] as int,
      dueDate: r['due_date'] as String,
      paidDate: r['paid_date'] as String?,
      paidAmount: r['paid_amount'] as int,
      status: r['status'] as String,
      paymentRef: (r['payment_ref'] ?? '') as String,
      accountId: r['account_id'] as String?,
    );
  }

  /// به‌روزرسانی وضعیت اقساط: DUE / OVERDUE (§28)
  /// نیمه‌پرداخت‌شده‌ها هم مشمول سررسید/معوق می‌شوند (پرداخت < مبلغ)
  void refreshStatuses({String? today}) {
    final t = today ?? _todayStr();
    store.db.execute(
      "UPDATE installments SET status = 'OVERDUE' WHERE status IN ('PENDING','DUE','OVERDUE') AND due_date < ? AND paid_amount < amount",
      [t],
    );
    store.db.execute(
      "UPDATE installments SET status = 'DUE' WHERE status = 'PENDING' AND due_date = ? AND paid_amount < amount",
      [t],
    );
  }

  List<Map<String, Object>> joinInstallments(String whereSql, List<Object?> args,
      {int limit = 200}) {
    final rows = store.db.select(
      'SELECT i.*, s.customer_id, s.customer_name, s.provider_id, s.invoice_number, p.name AS provider_name '
      'FROM installments i JOIN installment_sales s ON s.id = i.sale_id '
      'LEFT JOIN installment_providers p ON p.id = s.provider_id '
      'WHERE $whereSql ORDER BY i.due_date LIMIT ?',
      [...args, limit],
    );
    return rows.map((r) {
      final map = <String, Object>{};
      r.forEach((k, v) {
        if (v != null) map[k] = v as Object;
      });
      return map;
    }).toList();
  }

  List<Map<String, Object>> dueToday({String? today}) {
    final t = today ?? _todayStr();
    return joinInstallments(
        "i.status IN ('PENDING','DUE') AND i.due_date = ? AND i.paid_amount < i.amount", [t]);
  }

  List<Map<String, Object>> overdue({String? today}) {
    final t = today ?? _todayStr();
    return joinInstallments(
        "i.status IN ('PENDING','DUE','OVERDUE') AND i.due_date < ? AND i.paid_amount = 0",
        [t]);
  }

  List<Map<String, Object>> upcoming(String from, String to) {
    return joinInstallments(
        "i.paid_amount = 0 AND i.status NOT IN ('CANCELLED','WAIVED') AND i.due_date >= ? AND i.due_date <= ?",
        [from, to]);
  }

  int overdueAmount({String? today}) {
    final t = today ?? _todayStr();
    final row = store.db.select(
      "SELECT COALESCE(SUM(amount - paid_amount), 0) AS v FROM installments i "
      "JOIN installment_sales s ON s.id = i.sale_id "
      "WHERE s.status NOT IN ('CANCELLED','REFUNDED') AND i.status NOT IN ('CANCELLED','WAIVED') "
      "AND i.due_date < ? AND i.paid_amount < i.amount",
      [t],
    ).first;
    return row['v'] as int;
  }

  /// ماندهٔ بدهی اقساط مستقیم فروشگاهِ مشتری (برای سقف اعتبار)
  int outstandingStoreDebt(String customerId) {
    final row = store.db.select(
      "SELECT COALESCE(SUM(i.amount - i.paid_amount), 0) AS v "
      "FROM installments i JOIN installment_sales s ON s.id = i.sale_id "
      "JOIN installment_providers p ON p.id = s.provider_id "
      "WHERE s.customer_id = ? AND p.provider_type = 'store' "
      "AND s.status NOT IN ('CANCELLED','REFUNDED') AND i.status NOT IN ('CANCELLED','WAIVED') "
      "AND i.paid_amount < i.amount",
      [customerId],
    ).first;
    return row['v'] as int;
  }

  // ---------------------------------------------------------------------
  // پرداخت قسط (§16)
  // ---------------------------------------------------------------------

  /// پرداخت/دریافت قسط — idempotent با مرجع پرداخت
  void payInstallment({
    required String installmentId,
    required String date,
    String? accountId,
    int? amount,
    String paymentRef = '',
  }) {
    final inst = installmentById(installmentId);
    if (inst == null) throw StateError('قسط پیدا نشد');
    if (inst.status == InstallmentStatus.cancelled ||
        inst.status == InstallmentStatus.waived) {
      throw StateError('قسط لغو/بخشیده قابل پرداخت نیست');
    }
    final remaining = inst.remaining;
    if (remaining <= 0) throw StateError('این قسط قبلاً کامل پرداخت شده است');
    final payAmount = amount ?? remaining;
    if (payAmount <= 0 || payAmount > remaining) {
      throw ArgumentError('مبلغ پرداخت باید بین ۱ تا مانده قسط باشد');
    }
    final sale = saleById(inst.saleId)!;
    final provider = providerById(sale.providerId);
    final isStore = provider?.isStore ?? false;

    store.txn(() {
      final newPaid = inst.paidAmount + payAmount;
      final newStatus = newPaid >= inst.amount ? InstallmentStatus.paid : inst.status;
      store.db.execute(
        'UPDATE installments SET paid_amount = ?, paid_date = ?, status = ?, payment_ref = ?, account_id = ? WHERE id = ?',
        [
          newPaid,
          newPaid >= inst.amount ? date : inst.paidDate,
          newStatus,
          paymentRef,
          accountId,
          installmentId,
        ],
      );
      ledger.append(LedgerEntryInput(
        eventType: LedgerEventType.installmentPaid,
        date: date,
        amount: payAmount,
        direction: accountId == null ? 0 : 1,
        accountId: accountId,
        customerId: isStore ? sale.customerId : null,
        installmentId: installmentId,
        installmentNo: inst.number,
        providerId: sale.providerId,
        customerDelta: isStore ? -payAmount : 0,
        reference: paymentRef,
        description: 'پرداخت قسط ${inst.number} از ${sale.invoiceNumber.isEmpty ? sale.id : sale.invoiceNumber}',
        idempotencyKey: paymentRef.isNotEmpty
            ? 'instpay:$installmentId:$paymentRef'
            : 'instpay:$installmentId:${newId()}',
      ));
    });
    audit.log('INSTALLMENT_PAY', 'installment', installmentId, '$payAmount تومان');
  }

  // ---------------------------------------------------------------------
  // تسویهٔ سیستم اقساطی (§18)
  // ---------------------------------------------------------------------

  int settledAmount(String saleId) {
    final row = store.db.select(
      "SELECT COALESCE(SUM(amount), 0) AS v FROM provider_settlements WHERE sale_id = ? AND reversed_at IS NULL",
      [saleId],
    ).first;
    return row['v'] as int;
  }

  /// برنامهٔ تسویهٔ درگاه برای این فروش (ستون‌های مستقیم دیتابیس)
  List<Map<String, Object?>> settlementScheduleRows(String saleId) => store.db.select(
      'SELECT * FROM settlement_schedule WHERE sale_id = ? ORDER BY number', [saleId]);

  /// ثبت تسویهٔ درگاه — پول قسط‌به‌قسط طبق برنامه وارد حساب می‌شود.
  /// [scheduleId] اگر داده شود فقط همان قسط تسویه می‌شود؛ وگرنه از اولین قسط
  /// بازمانده به ترتیب پر می‌شود. سقف همیشه مجموع ماندهٔ برنامه است؛
  /// کل مبلغ فروش هرگز نقد فرض نمی‌شود.
  String settle({
    required String saleId,
    required int amount,
    required String date,
    required String accountId,
    String reference = '',
    String? scheduleId,
  }) {
    final sale = saleById(saleId);
    if (sale == null) throw StateError('فروش اقساطی پیدا نشد');
    if (sale.status == InstallmentSaleStatus.cancelled ||
        sale.status == InstallmentSaleStatus.refunded) {
      throw StateError('فروش لغو/برگشتی قابل تسویه نیست');
    }
    if (amount <= 0) throw ArgumentError('مبلغ تسویه باید مثبت باشد');

    final rows = store.db.select(
      scheduleId == null
          ? "SELECT * FROM settlement_schedule WHERE sale_id = ? AND status != 'CANCELLED' ORDER BY number"
          : "SELECT * FROM settlement_schedule WHERE sale_id = ? AND id = ? AND status != 'CANCELLED' ORDER BY number",
      scheduleId == null ? [saleId] : [saleId, scheduleId]);
    if (rows.isEmpty) {
      throw StateError('برنامهٔ تسویه‌ای برای این فروش ثبت نشده است');
    }
    var remainingTotal = 0;
    for (final r in rows) {
      remainingTotal += (r['amount'] as int) - (r['received_amount'] as int);
    }
    if (amount > remainingTotal) {
      throw StateError(
          'تسویه بیشتر از مورد انتظار مجاز نیست: ماندهٔ برنامه $remainingTotal، درخواست $amount');
    }

    var left = amount;
    final sid = 'pset-${newId()}';
    store.txn(() {
      for (final r in rows) {
        if (left <= 0) break;
        final rowId = r['id'] as String;
        final rowAmount = r['amount'] as int;
        final received = r['received_amount'] as int;
        final rowRemaining = rowAmount - received;
        if (rowRemaining <= 0) continue;
        final take = left < rowRemaining ? left : rowRemaining;
        store.db.execute(
          'INSERT INTO provider_settlements (id, sale_id, provider_id, amount, settle_date, account_id, reference, schedule_id, created_at) '
          'VALUES (?,?,?,?,?,?,?,?,?)',
          [
            'pset-${newId()}',
            saleId,
            sale.providerId,
            take,
            date,
            accountId,
            reference,
            rowId,
            DateTime.now().toIso8601String(),
          ],
        );
        ledger.append(LedgerEntryInput(
          eventType: LedgerEventType.providerSettlement,
          date: date,
          amount: take,
          direction: 1,
          accountId: accountId,
          providerId: sale.providerId,
          installmentId: saleId,
          reference: reference,
          description:
              'تسویهٔ قسط ${r['number']} از ${sale.invoiceNumber.isEmpty ? sale.id : sale.invoiceNumber}',
          idempotencyKey: 'settlement:${newId()}',
        ));
        final newReceived = received + take;
        store.db.execute(
          'UPDATE settlement_schedule SET received_amount = ?, received_date = ?, status = ? WHERE id = ?',
          [
            newReceived,
            date,
            newReceived >= rowAmount ? 'RECEIVED' : 'PARTIAL',
            rowId,
          ],
        );
        left -= take;
      }
      // وضعیت فروش: تسویه کامل وقتی همهٔ اقساط برنامه کامل دریافت شده باشند
      final allDone = store.db.select(
        "SELECT COUNT(*) AS c FROM settlement_schedule WHERE sale_id = ? AND received_amount < amount AND status != 'CANCELLED'",
        [saleId],
      ).first['c'] as int;
      store.db.execute(
        'UPDATE installment_sales SET status = ? WHERE id = ?',
        [
          allDone == 0
              ? InstallmentSaleStatus.settled
              : InstallmentSaleStatus.partiallySettled,
          saleId,
        ],
      );
    });
    audit.log('PROVIDER_SETTLE', 'installment_sale', saleId, '$amount تومان ($sid)');
    return sid;
  }

  /// طلب تسویه‌نشدهٔ فروشگاه از یک درگاه (مجموع ماندهٔ برنامهٔ تسویه)
  int providerOutstanding(String providerId) {
    final row = store.db.select(
      "SELECT COALESCE(SUM(sc.amount - sc.received_amount), 0) AS v "
      "FROM settlement_schedule sc JOIN installment_sales s ON s.id = sc.sale_id "
      "WHERE sc.provider_id = ? AND sc.status != 'CANCELLED' "
      "AND s.status NOT IN ('CANCELLED','REFUNDED') AND sc.received_amount < sc.amount",
      [providerId],
    ).first;
    return row['v'] as int;
  }

  /// پیش‌بینی ماهانهٔ تسویه‌ها به تفکیک درگاه — «دریافتی تسویه‌نشدهٔ فروشگاه»
  List<Map<String, Object?>> monthlySettlementForecast({String? from, String? to}) {
    final where = <String>[
      "sc.status != 'CANCELLED'",
      "s.status NOT IN ('CANCELLED','REFUNDED')",
      'sc.received_amount < sc.amount',
    ];
    final args = <Object?>[];
    if (from != null) {
      where.add('sc.expected_date >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('sc.expected_date <= ?');
      args.add(to);
    }
    return store.db.select(
      'SELECT p.id AS provider_id, p.name AS provider_name, substr(sc.expected_date, 1, 7) AS ym, '
      'COALESCE(SUM(sc.amount - sc.received_amount), 0) AS outstanding, COUNT(*) AS cnt '
      'FROM settlement_schedule sc '
      'JOIN installment_sales s ON s.id = sc.sale_id '
      'JOIN installment_providers p ON p.id = sc.provider_id '
      'WHERE ${where.join(' AND ')} '
      'GROUP BY p.id, ym ORDER BY ym, p.name',
      args,
    );
  }

  /// اقساط تسویه‌ای که باید از کاربر درباره‌شان پرسید: «درگاه تسویه کرد؟ چند؟»
  /// (مثلاً روزهای ۱ تا ۵ ماه) — سررسیدِ رسیده/گذشته و هنوز کامل دریافت‌نشده
  List<Map<String, Object?>> pendingSettlementConfirmations(String today,
      {int lookaheadDays = 0}) {
    return store.db.select(
      "SELECT sc.*, s.customer_name, s.invoice_number, s.sale_date, p.name AS provider_name, "
      "(sc.amount - sc.received_amount) AS remaining "
      "FROM settlement_schedule sc "
      "JOIN installment_sales s ON s.id = sc.sale_id "
      "JOIN installment_providers p ON p.id = sc.provider_id "
      "WHERE sc.status != 'CANCELLED' AND s.status NOT IN ('CANCELLED','REFUNDED') "
      "AND sc.received_amount < sc.amount AND sc.expected_date <= date(?, '+$lookaheadDays day') "
      "ORDER BY sc.expected_date",
      [today],
    );
  }

  List<Map<String, Object>> settlements({String? providerId, String? saleId}) {
    final where = <String>['ps.reversed_at IS NULL'];
    final args = <Object?>[];
    if (providerId != null) {
      where.add('ps.provider_id = ?');
      args.add(providerId);
    }
    if (saleId != null) {
      where.add('ps.sale_id = ?');
      args.add(saleId);
    }
    return store.db.select(
      'SELECT ps.*, p.name AS provider_name, s.customer_name, s.invoice_number, s.net_settlement '
      'FROM provider_settlements ps '
      'JOIN installment_sales s ON s.id = ps.sale_id '
      'LEFT JOIN installment_providers p ON p.id = ps.provider_id '
      'WHERE ${where.join(' AND ')} ORDER BY ps.created_at DESC',
      args,
    );
  }

  List<Map<String, Object>> upcomingSettlements({String? from, String? to}) {
    final where = <String>[
      "s.status IN ('CREATED','AUTHORIZED','PARTIALLY_SETTLED')",
      "sc.received_amount < sc.amount",
      "sc.status != 'CANCELLED'",
    ];
    final args = <Object?>[];
    if (from != null) {
      where.add('sc.expected_date >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('sc.expected_date <= ?');
      args.add(to);
    }
    return store.db.select(
      'SELECT sc.id, sc.number, sc.amount, sc.received_amount, sc.expected_date, '
      '(sc.amount - sc.received_amount) AS outstanding, s.id AS sale_id, s.customer_name, s.invoice_number, '
      'p.name AS provider_name '
      'FROM settlement_schedule sc '
      'JOIN installment_sales s ON s.id = sc.sale_id '
      'JOIN installment_providers p ON p.id = sc.provider_id '
      'WHERE ${where.join(' AND ')} '
      'ORDER BY sc.expected_date',
      args,
    );
  }

  // ---------------------------------------------------------------------
  // لغو و برگشت (§29)
  // ---------------------------------------------------------------------

  /// لغو فروش اقساطی: هرگز رکورد حذف نمی‌شود؛ همهٔ اثرها دقیقاً یک‌بار معکوس می‌شوند.
  void cancelSale(String saleId, {String reason = '', String? date}) {
    final sale = saleById(saleId);
    if (sale == null) throw StateError('فروش اقساطی پیدا نشد');
    if (sale.status == InstallmentSaleStatus.cancelled) {
      throw StateError('این فروش قبلاً لغو شده است');
    }
    final d = date ?? _todayStr();
    store.txn(() {
      // معکوس‌سازی رویدادهای مالی سطح فروش (ایجاد/بیعانه/کارمزد/تسویه) که
      // هنوز معکوس نشده‌اند. پرداخت‌های قسطِ مشتری جداگانه از مسیر برگشت
      // وجه (REFUND) تصفیه می‌شوند.
      final events = store.db.select(
        'SELECT id FROM ledger_events WHERE installment_id = ? AND reversal_of IS NULL',
        [saleId],
      );
      for (final e in events) {
        if (!ledger.isReversed(e['id'] as String)) {
          ledger.reverse(e['id'] as String, date: d, description: 'لغو فروش اقساطی — $reason');
        }
      }
      store.db.execute(
        'UPDATE installment_sales SET status = ?, cancelled_at = ? WHERE id = ?',
        [InstallmentSaleStatus.cancelled, DateTime.now().toIso8601String(), saleId],
      );
      store.db.execute(
        "UPDATE installments SET status = 'CANCELLED' WHERE sale_id = ? AND paid_amount = 0",
        [saleId],
      );
      store.db.execute(
        "UPDATE settlement_schedule SET status = 'CANCELLED' WHERE sale_id = ? AND received_amount = 0",
        [saleId],
      );
      store.db.execute(
        'UPDATE provider_settlements SET reversed_at = ? WHERE sale_id = ? AND reversed_at IS NULL',
        [DateTime.now().toIso8601String(), saleId],
      );
    });
    audit.log('INSTALLMENT_CANCEL', 'installment_sale', saleId, reason);
  }

  /// برگشت فروش اقساطی (§29): برگشت کالا/مبلغ با رویداد تصحیح — بدون حذف تاریخ
  void refundSale(String saleId, {String reason = '', String? date}) {
    final sale = saleById(saleId);
    if (sale == null) throw StateError('فروش اقساطی پیدا نشد');
    if (sale.status == InstallmentSaleStatus.refunded) {
      throw StateError('این فروش قبلاً برگشت خورده است');
    }
    cancelSale(saleId, reason: 'برگشت — $reason', date: date);
    store.db.execute(
      'UPDATE installment_sales SET status = ? WHERE id = ?',
      [InstallmentSaleStatus.refunded, saleId],
    );
    audit.log('INSTALLMENT_REFUND', 'installment_sale', saleId, reason);
  }

  // ---------------------------------------------------------------------
  // گزارش هر سیستم اقساطی (§20)
  // ---------------------------------------------------------------------

  List<Map<String, Object>> providerReport({String? from, String? to}) {
    final where = <String>['1=1'];
    final args = <Object?>[];
    if (from != null) {
      where.add('s.sale_date >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('s.sale_date <= ?');
      args.add(to);
    }
    return store.db.select(
      "SELECT p.id, p.name, p.provider_type, COUNT(s.id) AS sales_count, "
      "COALESCE(SUM(s.gross), 0) AS gross_total, "
      "COALESCE(SUM(s.down_payment), 0) AS down_total, "
      "COALESCE(SUM(s.financed), 0) AS financed_total, "
      "COALESCE(SUM(s.commission), 0) AS commission_total, "
      "COALESCE(SUM(s.commission_vat), 0) AS commission_vat_total, "
      "COALESCE(SUM(s.net_settlement), 0) AS expected_settlement, "
      "COALESCE(SUM((SELECT COALESCE(SUM(ps.amount), 0) FROM provider_settlements ps WHERE ps.sale_id = s.id AND ps.reversed_at IS NULL)), 0) AS settled_total, "
      "COALESCE(SUM((SELECT COALESCE(SUM(sc.amount - sc.received_amount), 0) FROM settlement_schedule sc WHERE sc.sale_id = s.id AND sc.status != 'CANCELLED')), 0) AS outstanding_settlement "
      "FROM installment_providers p "
      "LEFT JOIN installment_sales s ON s.provider_id = p.id AND s.status NOT IN ('CANCELLED','REFUNDED') "
      "WHERE ${where.join(' AND ')} GROUP BY p.id ORDER BY p.created_at",
      args,
    );
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String _addDays(String date, int days) {
    final d = DateTime.parse(date).add(Duration(days: days));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

/// سقف اعتبار مشتری برای اقساط مستقیم فروشگاه (§27)
class CustomerCreditRepository {
  final StoreDatabase store;
  CustomerCreditRepository(this.store);

  int creditLimit(String customerId) {
    final rows = store.db.select(
        'SELECT credit_limit FROM customer_credit_limits WHERE customer_id = ?', [customerId]);
    return rows.isEmpty ? 0 : rows.first['credit_limit'] as int;
  }

  void setCreditLimit(String customerId, int limit) {
    if (limit < 0) throw ArgumentError('سقف اعتبار نمی‌تواند منفی باشد');
    store.db.execute(
      'INSERT INTO customer_credit_limits (customer_id, credit_limit, updated_at) VALUES (?,?,?) '
      'ON CONFLICT(customer_id) DO UPDATE SET credit_limit = excluded.credit_limit, updated_at = excluded.updated_at',
      [customerId, limit, DateTime.now().toIso8601String()],
    );
  }
}
