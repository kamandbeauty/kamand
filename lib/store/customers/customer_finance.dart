import '../core/accounts.dart';
import '../core/audit.dart';
import '../db/store_database.dart';
import '../installments/installment_repository.dart';

class CustomerFinanceSummary {
  final int receivable;
  final int totalPaid;
  final int totalRefunded;
  final int totalReturned;
  final int installmentPurchases;
  final int outstandingInstallments;
  final int overdueCount;
  final int overdueAmount;
  final String? lastTransactionDate;
  const CustomerFinanceSummary({
    required this.receivable,
    required this.totalPaid,
    required this.totalRefunded,
    required this.totalReturned,
    required this.installmentPurchases,
    required this.outstandingInstallments,
    required this.overdueCount,
    required this.overdueAmount,
    this.lastTransactionDate,
  });
}

/// مالی مشتری (§5) — مانده همیشه از دفتر کل مشتق می‌شود، هرگز دستی انباشته نمی‌شود.
class CustomerFinanceRepository {
  final StoreDatabase store;
  final LedgerRepository ledger;
  final AuditLog audit;
  final CustomerCreditRepository credit;
  CustomerFinanceRepository(this.store, this.ledger, this.audit, this.credit);

  /// ماندهٔ بدهی مشتری (مثبت = بدهکار؛ هرگز منفی نمی‌شود)
  int receivable(String customerId) =>
      ledger.sumField('customer_delta', 'v', customerId: customerId);

  /// دریافت از مشتری — نمی‌تواند بیشتر از بدهی باشد (§50: مانده منفی ممنوع)
  String receivePayment({
    required String customerId,
    required int amount,
    required String date,
    required String accountId,
    String? invoiceId,
    String method = 'cash',
    String reference = '',
    String notes = '',
    String? idempotencyKey,
  }) {
    if (amount <= 0) throw ArgumentError('مبلغ باید مثبت باشد');
    final current = receivable(customerId);
    if (amount > current) {
      throw StateError('دریافت ($amount) بیشتر از بدهی فعلی ($current) نیست');
    }
    final pid = 'cpay-${newId()}';
    ledger.append(LedgerEntryInput(
      eventType: LedgerEventType.paymentReceived,
      date: date,
      amount: amount,
      direction: 1,
      accountId: accountId,
      customerId: customerId,
      invoiceId: invoiceId,
      paymentId: pid,
      reference: reference,
      description: notes,
      customerDelta: -amount,
      idempotencyKey: idempotencyKey ?? 'cpay:$pid',
    ));
    audit.log('CUSTOMER_PAYMENT', 'customer', customerId, '$amount تومان ($pid)');
    return pid;
  }

  /// برگشت وجه به مشتری (§11) — خروج نقدی + ردیابی کامل؛ اثر مشتری از مسیر
  /// رویداد برگشت/لغو (SALE_RETURN / REVENUE_REVERSED) اعمال می‌شود تا مانده
  /// هرگز منفی نشود.
  String refund({
    required String customerId,
    required int amount,
    required String date,
    required String accountId,
    String reason = '',
    String? invoiceId,
  }) {
    if (amount <= 0) throw ArgumentError('مبلغ برگشت باید مثبت باشد');
    final rid = 'ref-${newId()}';
    ledger.append(LedgerEntryInput(
      eventType: LedgerEventType.refund,
      date: date,
      amount: amount,
      direction: -1,
      accountId: accountId,
      customerId: customerId,
      invoiceId: invoiceId,
      refundId: rid,
      description: reason,
      idempotencyKey: 'refund:$rid',
    ));
    audit.log('CUSTOMER_REFUND', 'customer', customerId, '$amount تومان ($rid)');
    return rid;
  }

  /// برگشت کالا از مشتری (کاهش درآمد و بدهی تا کف صفر؛ مازاد از مسیر وجه برگشتی)
  /// موجودی کالا از طریق InventoryRepository (در پل فروش) برمی‌گردد.
  String recordReturn({
    required String customerId,
    required int amount,
    required String date,
    String? invoiceId,
    String notes = '',
  }) {
    if (amount <= 0) throw ArgumentError('مبلغ برگشت باید مثبت باشد');
    final current = receivable(customerId);
    final delta = amount > current ? current : amount;
    final rid = 'sret-${newId()}';
    ledger.append(LedgerEntryInput(
      eventType: LedgerEventType.saleReturn,
      date: date,
      amount: amount,
      customerId: customerId,
      invoiceId: invoiceId,
      reference: rid,
      description: notes,
      customerDelta: -delta,
      idempotencyKey: 'salereturn:$rid',
    ));
    audit.log('SALE_RETURN', 'customer', customerId, '$amount تومان ($rid)');
    return rid;
  }

  /// دریافت بسته‌بندی از مشتری (§43) — رویدادی جدا از هزینهٔ عمدهٔ بسته‌بندی.
  /// اگر حساب مشخص شود مبلغ همان‌جا دریافت می‌شود؛ وگرنه به بدهی مشتری می‌افزاید.
  String packagingCharge({
    required String customerId,
    required int amount,
    required String date,
    String? accountId,
  }) {
    if (amount <= 0) throw ArgumentError('مبلغ باید مثبت باشد');
    return ledger.append(LedgerEntryInput(
      eventType: LedgerEventType.packagingCharge,
      date: date,
      amount: amount,
      direction: accountId == null ? 0 : 1,
      accountId: accountId,
      customerId: customerId,
      customerDelta: accountId == null ? amount : 0,
      description: 'دریافت بسته‌بندی از مشتری',
      idempotencyKey: 'pkg-${newId()}',
    ));
  }

  /// دریافت هزینهٔ ارسال از مشتری (§44) — جدا از هزینهٔ واقعی ارسال فروشگاه
  String shippingCharge({
    required String customerId,
    required int amount,
    required String date,
    String? accountId,
  }) {
    if (amount <= 0) throw ArgumentError('مبلغ باید مثبت باشد');
    return ledger.append(LedgerEntryInput(
      eventType: LedgerEventType.shippingCharge,
      date: date,
      amount: amount,
      direction: accountId == null ? 0 : 1,
      accountId: accountId,
      customerId: customerId,
      customerDelta: accountId == null ? amount : 0,
      description: 'دریافت هزینهٔ ارسال از مشتری',
      idempotencyKey: 'ship-${newId()}',
    ));
  }

  CustomerFinanceSummary summary(String customerId, {String? today}) {
    final t = today ?? _todayStr();
    final totalPaid = ledger.sumField(LedgerRepository.signedAmountExpr, 'v',
        customerId: customerId, types: {LedgerEventType.paymentReceived});
    final totalRefunded = ledger.sumField(LedgerRepository.signedAmountExpr, 'v',
        customerId: customerId, types: {LedgerEventType.refund});
    final totalReturned = ledger.sumField(LedgerRepository.signedAmountExpr, 'v',
        customerId: customerId, types: {LedgerEventType.saleReturn});
    final installmentRow = store.db.select(
      "SELECT COALESCE(SUM(gross), 0) AS g FROM installment_sales "
      "WHERE customer_id = ? AND status NOT IN ('CANCELLED','REFUNDED')",
      [customerId],
    ).first;
    final outstandingRow = store.db.select(
      "SELECT COALESCE(SUM(i.amount - i.paid_amount), 0) AS v, "
      "SUM(CASE WHEN i.due_date < ? AND i.paid_amount < i.amount AND i.status NOT IN ('CANCELLED','WAIVED') THEN 1 ELSE 0 END) AS overdue_cnt, "
      "COALESCE(SUM(CASE WHEN i.due_date < ? AND i.paid_amount < i.amount AND i.status NOT IN ('CANCELLED','WAIVED') THEN i.amount - i.paid_amount ELSE 0 END), 0) AS overdue_amt "
      "FROM installments i JOIN installment_sales s ON s.id = i.sale_id "
      "WHERE s.customer_id = ? AND s.status NOT IN ('CANCELLED','REFUNDED') "
      "AND i.status NOT IN ('CANCELLED','WAIVED') AND i.paid_amount < i.amount",
      [t, t, customerId],
    ).first;
    final lastRow = store.db.select(
      'SELECT MAX(event_date) AS d FROM ledger_events e '
      'WHERE ${LedgerRepository.effectiveFilter} AND e.customer_id = ?',
      [customerId],
    ).first;
    return CustomerFinanceSummary(
      receivable: receivable(customerId),
      totalPaid: totalPaid,
      totalRefunded: totalRefunded,
      totalReturned: totalReturned,
      installmentPurchases: installmentRow['g'] as int,
      outstandingInstallments: outstandingRow['v'] as int,
      overdueCount: (outstandingRow['overdue_cnt'] as int? ?? 0),
      overdueAmount: outstandingRow['overdue_amt'] as int,
      lastTransactionDate: lastRow['d'] as String?,
    );
  }

  /// صورت‌حساب مشتری — رویدادهای مالی مؤثر به ترتیب زمانی
  List<LedgerEvent> statement(String customerId, {int limit = 300}) =>
      ledger.effectiveEvents(customerId: customerId, limit: limit);

  /// ماندهٔ اقساط مستقیم فروشگاه + سقف اعتبار → اعتبار قابل استفاده (§27)
  int availableCredit(String customerId, {required int outstandingStoreDebt}) {
    final limit = credit.creditLimit(customerId);
    if (limit <= 0) return 0;
    final available = limit - outstandingStoreDebt;
    return available < 0 ? 0 : available;
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }
}
