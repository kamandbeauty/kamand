import '../db/store_database.dart';

/// انواع رویدادهای دفتر کل (§30) — تک‌منبع حقیقت مالی برنامه
class LedgerEventType {
  static const sale = 'SALE';
  static const paymentReceived = 'PAYMENT_RECEIVED';
  static const refund = 'REFUND';
  static const expense = 'EXPENSE';
  static const shippingExpense = 'SHIPPING_EXPENSE';
  static const packagingExpense = 'PACKAGING_EXPENSE';
  static const packagingCharge = 'PACKAGING_CHARGE';
  static const shippingCharge = 'SHIPPING_CHARGE';
  static const purchase = 'PURCHASE';
  static const purchasePayment = 'PURCHASE_PAYMENT';
  static const supplierPayment = 'SUPPLIER_PAYMENT';
  static const purchaseReturn = 'PURCHASE_RETURN';
  static const saleReturn = 'SALE_RETURN';
  static const revenueReversed = 'REVENUE_REVERSED';
  static const installmentCreated = 'INSTALLMENT_CREATED';
  static const installmentPaid = 'INSTALLMENT_PAID';
  static const providerSettlement = 'PROVIDER_SETTLEMENT';
  static const providerCommission = 'PROVIDER_COMMISSION';
  static const accountTransfer = 'ACCOUNT_TRANSFER';
  static const deposit = 'DEPOSIT';
  static const withdrawal = 'WITHDRAWAL';
  static const adjustment = 'ADJUSTMENT';

  // چک‌ها (نسخهٔ ۴)
  static const chequeReceived = 'CHEQUE_RECEIVED';
  static const chequeIssued = 'CHEQUE_ISSUED';
  static const chequeCleared = 'CHEQUE_CLEARED';
  static const chequeBounced = 'CHEQUE_BOUNCED';

  /// انواعی که «موجودی حساب» را تغییر می‌دهند ولی نه درآمد و نه هزینه‌اند
  static const nonPl = {
    accountTransfer,
    deposit,
    withdrawal,
    adjustment,
  };
}

class LedgerEvent {
  final String id;
  final String eventDate;
  final String eventType;
  final int amount;
  final int direction;
  final String? accountId;
  final String? customerId;
  final String? supplierId;
  final String? invoiceId;
  final String? purchaseId;
  final String? paymentId;
  final String? refundId;
  final String? installmentId;
  final int? installmentNo;
  final String? providerId;
  final String? expenseId;
  final String? transferId;
  final String reference;
  final String? reversalOf;
  final String description;
  final int customerDelta;
  final int supplierDelta;
  final String createdAt;

  const LedgerEvent({
    required this.id,
    required this.eventDate,
    required this.eventType,
    required this.amount,
    required this.direction,
    this.accountId,
    this.customerId,
    this.supplierId,
    this.invoiceId,
    this.purchaseId,
    this.paymentId,
    this.refundId,
    this.installmentId,
    this.installmentNo,
    this.providerId,
    this.expenseId,
    this.transferId,
    this.reference = '',
    this.reversalOf,
    this.description = '',
    this.customerDelta = 0,
    this.supplierDelta = 0,
    required this.createdAt,
  });

  factory LedgerEvent.fromRow(Map<String, Object?> r) => LedgerEvent(
        id: r['id'] as String,
        eventDate: r['event_date'] as String,
        eventType: r['event_type'] as String,
        amount: r['amount'] as int,
        direction: r['direction'] as int,
        accountId: r['account_id'] as String?,
        customerId: r['customer_id'] as String?,
        supplierId: r['supplier_id'] as String?,
        invoiceId: r['invoice_id'] as String?,
        purchaseId: r['purchase_id'] as String?,
        paymentId: r['payment_id'] as String?,
        refundId: r['refund_id'] as String?,
        installmentId: r['installment_id'] as String?,
        installmentNo: r['installment_no'] as int?,
        providerId: r['provider_id'] as String?,
        expenseId: r['expense_id'] as String?,
        transferId: r['transfer_id'] as String?,
        reference: (r['reference'] ?? '') as String,
        reversalOf: r['reversal_of'] as String?,
        description: (r['description'] ?? '') as String,
        customerDelta: r['customer_delta'] as int,
        supplierDelta: r['supplier_delta'] as int,
        createdAt: r['created_at'] as String,
      );
}

class LedgerEntryInput {
  final String eventType;
  final String date;
  final int amount;
  final int direction;
  final String? accountId;
  final String? customerId;
  final String? supplierId;
  final String? invoiceId;
  final String? purchaseId;
  final String? paymentId;
  final String? refundId;
  final String? installmentId;
  final int? installmentNo;
  final String? providerId;
  final String? expenseId;
  final String? transferId;
  final String reference;
  final String? reversalOf;
  final String description;
  final int customerDelta;
  final int supplierDelta;
  final String? idempotencyKey;

  const LedgerEntryInput({
    required this.eventType,
    required this.date,
    required this.amount,
    this.direction = 0,
    this.accountId,
    this.customerId,
    this.supplierId,
    this.invoiceId,
    this.purchaseId,
    this.paymentId,
    this.refundId,
    this.installmentId,
    this.installmentNo,
    this.providerId,
    this.expenseId,
    this.transferId,
    this.reference = '',
    this.reversalOf,
    this.description = '',
    this.customerDelta = 0,
    this.supplierDelta = 0,
    this.idempotencyKey,
  });
}

/// دفتر کل یکپارچه — همهٔ جهش‌های مالی از اینجا می‌گذرند (قانون طلایی ۲ و ۵)
class LedgerRepository {
  final StoreDatabase store;
  LedgerRepository(this.store);

  /// مبلغ امضادار: رویداد معکوس با علامت منفی جمع می‌شود (حسابداری تصحیحی)
  static const signedAmountExpr =
      "CASE WHEN e.reversal_of IS NULL THEN e.amount ELSE -e.amount END";

  /// افزودن رویداد؛ با کلید idempotency تکرارپذیر ایمن است (INSERT OR IGNORE)
  /// خروجی: شناسهٔ رویداد (موجود یا جدید)
  String append(LedgerEntryInput input) {
    final db = store.db;
    final id = 'ev-${DateTime.now().microsecondsSinceEpoch}-'
        '${_seq()}';
    final key = input.idempotencyKey;
    db.execute(
      'INSERT OR IGNORE INTO ledger_events '
      '(id, event_date, event_type, amount, direction, account_id, customer_id, supplier_id, '
      'invoice_id, purchase_id, payment_id, refund_id, installment_id, installment_no, '
      'provider_id, expense_id, transfer_id, reference, reversal_of, description, '
      'customer_delta, supplier_delta, idempotency_key, created_at) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        id,
        input.date,
        input.eventType,
        input.amount,
        input.direction,
        input.accountId,
        input.customerId,
        input.supplierId,
        input.invoiceId,
        input.purchaseId,
        input.paymentId,
        input.refundId,
        input.installmentId,
        input.installmentNo,
        input.providerId,
        input.expenseId,
        input.transferId,
        input.reference,
        input.reversalOf,
        input.description,
        input.customerDelta,
        input.supplierDelta,
        key,
        DateTime.now().toIso8601String(),
      ],
    );
    if (key != null) {
      final row = db.select(
          'SELECT id FROM ledger_events WHERE idempotency_key = ?', [key]).first;
      return row['id'] as String;
    }
    return id;
  }

  /// اثر معکوس دقیقاً یک‌بار برای رویداد قبلی (idempotent با کلید reversal:<id>)
  String reverse(String originalId, {String? date, String? description}) {
    final original = byId(originalId);
    if (original == null) {
      throw StateError('رویداد اصلی برای اثر معکوس پیدا نشد: $originalId');
    }
    if (isReversed(originalId)) {
      throw StateError('این رویداد قبلاً یک‌بار معکوس شده است: $originalId');
    }
    return append(LedgerEntryInput(
      eventType: original.eventType == LedgerEventType.sale
          ? LedgerEventType.revenueReversed
          : original.eventType,
      date: date ?? _today(),
      amount: original.amount,
      direction: -original.direction,
      accountId: original.accountId,
      customerId: original.customerId,
      supplierId: original.supplierId,
      invoiceId: original.invoiceId,
      purchaseId: original.purchaseId,
      paymentId: original.paymentId,
      refundId: original.refundId,
      installmentId: original.installmentId,
      installmentNo: original.installmentNo,
      providerId: original.providerId,
      expenseId: original.expenseId,
      transferId: original.transferId,
      reference: original.reference,
      reversalOf: originalId,
      description: description ?? 'اثر معکوس ${original.id}',
      customerDelta: -original.customerDelta,
      supplierDelta: -original.supplierDelta,
      idempotencyKey: 'reversal:$originalId',
    ));
  }

  bool isReversed(String eventId) {
    final row = store.db.select(
      'SELECT COUNT(*) AS c FROM ledger_events WHERE reversal_of = ?',
      [eventId],
    ).first;
    return (row['c'] as int) > 0;
  }

  LedgerEvent? byId(String id) {
    final rows =
        store.db.select('SELECT * FROM ledger_events WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return LedgerEvent.fromRow(rows.first);
  }

  /// رویدادهای «موثر» = وضعیت فعال خالص: نه خودشان معکوس‌شده‌اند و نه
  /// معکوسِ رویداد دیگری‌اند. زوج‌های (اصلی + معکوس) هر دو از این نما خارج
  /// می‌شوند ولی در جدول و audit history برای همیشه حفظ می‌شوند (§40).
  static const effectiveFilter =
      "(e.reversal_of IS NULL AND NOT EXISTS (SELECT 1 FROM ledger_events r WHERE r.reversal_of = e.id))";

  List<LedgerEvent> effectiveEvents({
    String? from,
    String? to,
    String? customerId,
    String? supplierId,
    String? accountId,
    String? invoiceId,
    String? purchaseId,
    String? installmentId,
    Set<String>? types,
    int limit = 500,
  }) {
    final where = <String>['1=1', effectiveFilter];
    final args = <Object?>[];
    if (from != null) {
      where.add('e.event_date >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('e.event_date <= ?');
      args.add(to);
    }
    if (customerId != null) {
      where.add('e.customer_id = ?');
      args.add(customerId);
    }
    if (supplierId != null) {
      where.add('e.supplier_id = ?');
      args.add(supplierId);
    }
    if (accountId != null) {
      where.add('e.account_id = ?');
      args.add(accountId);
    }
    if (invoiceId != null) {
      where.add('e.invoice_id = ?');
      args.add(invoiceId);
    }
    if (purchaseId != null) {
      where.add('e.purchase_id = ?');
      args.add(purchaseId);
    }
    if (installmentId != null) {
      where.add('e.installment_id = ?');
      args.add(installmentId);
    }
    if (types != null && types.isNotEmpty) {
      final marks = List.filled(types.length, '?').join(',');
      where.add('e.event_type IN ($marks)');
      args.addAll(types);
    }
    args.add(limit);
    final rows = store.db.select(
      'SELECT e.* FROM ledger_events e WHERE ${where.join(' AND ')} '
      'ORDER BY e.created_at DESC, e.id DESC LIMIT ?',
      args,
    );
    return rows.map(LedgerEvent.fromRow).toList();
  }

  /// جمع مؤثر یک ستون دلخواه با فیلترهای مشابه
  int sumField(String expression, String aggregateColumn,
      {String? from,
      String? to,
      String? customerId,
      String? supplierId,
      String? accountId,
      String? invoiceId,
      Set<String>? types,
      String extraWhere = ''}) {
    final where = <String>['1=1', effectiveFilter];
    final args = <Object?>[];
    if (from != null) {
      where.add('e.event_date >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('e.event_date <= ?');
      args.add(to);
    }
    if (customerId != null) {
      where.add('e.customer_id = ?');
      args.add(customerId);
    }
    if (supplierId != null) {
      where.add('e.supplier_id = ?');
      args.add(supplierId);
    }
    if (accountId != null) {
      where.add('e.account_id = ?');
      args.add(accountId);
    }
    if (invoiceId != null) {
      where.add('e.invoice_id = ?');
      args.add(invoiceId);
    }
    if (types != null && types.isNotEmpty) {
      final marks = List.filled(types.length, '?').join(',');
      where.add('e.event_type IN ($marks)');
      args.addAll(types);
    }
    if (extraWhere.isNotEmpty) where.add(extraWhere);
    final rows = store.db.select(
      'SELECT COALESCE(SUM($expression), 0) AS v FROM ledger_events e '
      'WHERE ${where.join(' AND ')}',
      args,
    );
    return rows.first['v'] as int;
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  int _seq() => DateTime.now().millisecondsSinceEpoch % 100000;
}
