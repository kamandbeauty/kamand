import '../core/accounts.dart';
import '../core/audit.dart';
import '../db/store_database.dart';

/// جهت چک
class ChequeDirection {
  static const received = 'received'; // چکِ دریافت‌شده از مشتری (نزد ما)
  static const issued = 'issued'; // چکِ پرداختی به تأمین‌کننده (از حساب ما)
}

/// وضعیت چک
class ChequeStatus {
  static const held = 'HELD'; // نزد ما، هنوز پاس نشده
  static const cleared = 'CLEARED'; // وصول/پاس شد
  static const bounced = 'BOUNCED'; // برگشت خورد
  static const passedOn = 'PASSED_ON'; // به دیگری سپرده شد
  static const cancelled = 'CANCELLED';
}

class ChequeEntity {
  final String id;
  final String direction;
  final int amount;
  final String chequeNumber;
  final String sayadiNumber;
  final String holderName;
  final String bankName;
  final String dueDate;
  final String counterpartyId;
  final String counterpartyName;
  final String status;
  final String? clearedDate;
  final String? clearedAccountId;
  final String notes;
  final String? ledgerEventId;
  final String createdAt;

  const ChequeEntity({
    required this.id,
    required this.direction,
    required this.amount,
    required this.chequeNumber,
    this.sayadiNumber = '',
    this.holderName = '',
    this.bankName = '',
    required this.dueDate,
    this.counterpartyId = '',
    this.counterpartyName = '',
    required this.status,
    this.clearedDate,
    this.clearedAccountId,
    this.notes = '',
    this.ledgerEventId,
    required this.createdAt,
  });

  bool get isReceived => direction == ChequeDirection.received;
  String get statusLabel {
    switch (status) {
      case ChequeStatus.cleared:
        return 'وصول شد';
      case ChequeStatus.bounced:
        return 'برگشت خورد';
      case ChequeStatus.passedOn:
        return 'به دیگری سپرده شد';
      case ChequeStatus.cancelled:
        return 'لغو شد';
      default:
        return 'در جریان (نزد ما)';
    }
  }
}

/// مدیریت چک در دریافت و پرداخت (نسخهٔ ۴)
///
/// منطق مالی:
/// - دریافت چک از مشتری: بدهی مشتری کم می‌شود ولی هنوز نقد نیست (direction 0)
/// - وصول چک (پاس شد): پول وارد حساب انتخابی می‌شود
/// - برگشت چک: اثر معکوس دقیقاً یک‌بار — بدهی مشتری برمی‌گردد
/// - پرداخت چک به تأمین‌کننده: بدهی ما کم می‌شود؛ هنگام پاس شدن از حساب کم می‌شود
class ChequeRepository {
  final StoreDatabase store;
  final LedgerRepository ledger;
  final AuditLog audit;
  ChequeRepository(this.store, this.ledger, this.audit);

  ChequeEntity? byId(String id) {
    final rows = store.db.select('SELECT * FROM cheques WHERE id = ?', [id]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  ChequeEntity _fromRow(Map<String, Object?> r) => ChequeEntity(
        id: r['id'] as String,
        direction: r['direction'] as String,
        amount: r['amount'] as int,
        chequeNumber: r['cheque_number'] as String,
        sayadiNumber: (r['sayadi_number'] ?? '') as String,
        holderName: (r['holder_name'] ?? '') as String,
        bankName: (r['bank_name'] ?? '') as String,
        dueDate: r['due_date'] as String,
        counterpartyId: (r['counterparty_id'] ?? '') as String,
        counterpartyName: (r['counterparty_name'] ?? '') as String,
        status: r['status'] as String,
        clearedDate: r['cleared_date'] as String?,
        clearedAccountId: r['cleared_account_id'] as String?,
        notes: (r['notes'] ?? '') as String,
        ledgerEventId: r['ledger_event_id'] as String?,
        createdAt: r['created_at'] as String,
      );

  /// دریافت چک از مشتری — شمارهٔ چک و تاریخ سررسید اجباری، مابقی اختیاری
  String receiveCheque({
    required String customerId,
    required String customerName,
    required int amount,
    required String chequeNumber,
    required String dueDate,
    String sayadiNumber = '',
    String holderName = '',
    String bankName = '',
    String date = '',
    String notes = '',
  }) {
    if (amount <= 0) throw ArgumentError('مبلغ چک باید مثبت باشد');
    if (chequeNumber.trim().isEmpty) {
      throw ArgumentError('شمارهٔ چک الزامی است');
    }
    if (dueDate.trim().isEmpty) {
      throw ArgumentError('تاریخ سررسید چک الزامی است');
    }
    // ماندهٔ مشتری هرگز منفی نمی‌شود (§50)
    if (customerId.isNotEmpty) {
      final r = ledger.sumField('customer_delta', 'v', customerId: customerId);
      if (amount > r) {
        throw StateError('مبلغ چک ($amount) بیشتر از بدهی فعلی مشتری ($r) است');
      }
    }
    final id = 'chq-${newId()}';
    final eventDate = date.isEmpty ? _today() : date;
    store.txn(() {
      final eventId = ledger.append(LedgerEntryInput(
        eventType: LedgerEventType.chequeReceived,
        date: eventDate,
        amount: amount,
        customerId: customerId.isEmpty ? null : customerId,
        reference: 'چک $chequeNumber',
        description: 'دریافت چک از $customerName — سررسید $dueDate',
        customerDelta: customerId.isEmpty ? 0 : -amount,
        idempotencyKey: 'cheque:$id',
      ));
      store.db.execute(
        'INSERT INTO cheques (id, direction, amount, cheque_number, sayadi_number, holder_name, bank_name, due_date, counterparty_id, counterparty_name, status, notes, ledger_event_id, created_at) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          id,
          ChequeDirection.received,
          amount,
          chequeNumber.trim(),
          sayadiNumber.trim(),
          holderName.trim(),
          bankName.trim(),
          dueDate,
          customerId,
          customerName,
          ChequeStatus.held,
          notes,
          eventId,
          DateTime.now().toIso8601String(),
        ],
      );
    });
    audit.log('CHEQUE_RECEIVE', 'cheque', id,
        'از $customerName — $amount تومان — سررسید $dueDate');
    return id;
  }

  /// پرداخت چک به تأمین‌کننده
  String issueCheque({
    required String supplierId,
    required String supplierName,
    required int amount,
    required String chequeNumber,
    required String dueDate,
    String sayadiNumber = '',
    String holderName = '',
    String bankName = '',
    String date = '',
    String notes = '',
  }) {
    if (amount <= 0) throw ArgumentError('مبلغ چک باید مثبت باشد');
    if (chequeNumber.trim().isEmpty) {
      throw ArgumentError('شمارهٔ چک الزامی است');
    }
    if (dueDate.trim().isEmpty) {
      throw ArgumentError('تاریخ سررسید چک الزامی است');
    }
    final id = 'chq-${newId()}';
    final eventDate = date.isEmpty ? _today() : date;
    store.txn(() {
      final eventId = ledger.append(LedgerEntryInput(
        eventType: LedgerEventType.chequeIssued,
        date: eventDate,
        amount: amount,
        supplierId: supplierId.isEmpty ? null : supplierId,
        reference: 'چک $chequeNumber',
        description: 'پرداخت چک به $supplierName — سررسید $dueDate',
        supplierDelta: supplierId.isEmpty ? 0 : -amount,
        idempotencyKey: 'cheque:$id',
      ));
      store.db.execute(
        'INSERT INTO cheques (id, direction, amount, cheque_number, sayadi_number, holder_name, bank_name, due_date, counterparty_id, counterparty_name, status, notes, ledger_event_id, created_at) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          id,
          ChequeDirection.issued,
          amount,
          chequeNumber.trim(),
          sayadiNumber.trim(),
          holderName.trim(),
          bankName.trim(),
          dueDate,
          supplierId,
          supplierName,
          ChequeStatus.held,
          notes,
          eventId,
          DateTime.now().toIso8601String(),
        ],
      );
    });
    audit.log('CHEQUE_ISSUE', 'cheque', id,
        'به $supplierName — $amount تومان — سررسید $dueDate');
    return id;
  }

  /// وصول چک (پاس شد) — پول وارد حساب می‌شود؛ فقط یک‌بار
  void clearCheque(String id,
      {required String accountId, required String date}) {
    final cheque = byId(id);
    if (cheque == null) throw StateError('چک پیدا نشد');
    if (cheque.status != ChequeStatus.held) {
      throw StateError('این چک در وضعیت قابل وصول نیست (${cheque.statusLabel})');
    }
    store.txn(() {
      ledger.append(LedgerEntryInput(
        eventType: LedgerEventType.chequeCleared,
        date: date,
        amount: cheque.amount,
        direction: cheque.isReceived ? 1 : -1,
        accountId: accountId,
        customerId: cheque.isReceived ? (cheque.counterpartyId.isEmpty ? null : cheque.counterpartyId) : null,
        supplierId: !cheque.isReceived ? (cheque.counterpartyId.isEmpty ? null : cheque.counterpartyId) : null,
        reference: 'چک ${cheque.chequeNumber}',
        description:
            'وصول چک ${cheque.chequeNumber} (${cheque.counterpartyName})',
        idempotencyKey: 'cheque-clear:$id',
      ));
      store.db.execute(
        'UPDATE cheques SET status = ?, cleared_date = ?, cleared_account_id = ? WHERE id = ?',
        [ChequeStatus.cleared, date, accountId, id],
      );
    });
    audit.log('CHEQUE_CLEAR', 'cheque', id, 'وصول ${cheque.amount} تومان');
  }

  /// برگشت چک — اثر معکوس دقیقاً یک‌بار (بدهی طرف برمی‌گردد)
  void bounceCheque(String id, {String date = ''}) {
    final cheque = byId(id);
    if (cheque == null) throw StateError('چک پیدا نشد');
    if (cheque.status != ChequeStatus.held) {
      throw StateError('این چک قابل برگشت نیست (${cheque.statusLabel})');
    }
    final d = date.isEmpty ? _today() : date;
    store.txn(() {
      if (cheque.ledgerEventId != null &&
          !ledger.isReversed(cheque.ledgerEventId!)) {
        ledger.reverse(cheque.ledgerEventId!,
            date: d, description: 'برگشت چک ${cheque.chequeNumber}');
      }
      store.db.execute('UPDATE cheques SET status = ? WHERE id = ?',
          [ChequeStatus.bounced, id]);
    });
    audit.log('CHEQUE_BOUNCE', 'cheque', id, 'برگشت ${cheque.chequeNumber}');
  }

  /// چک‌های «در جریان» که سررسیدشان رسیده/گذشته — برای پرسش «پاس شد؟»
  /// فقط چک‌های «دریافتی» که باید در سررسید از کاربر پرسید «پاس شد؟»
  List<ChequeEntity> dueForConfirmation(String today,
      {int lookaheadDays = 0}) {
    final rows = store.db.select(
      "SELECT * FROM cheques WHERE direction = 'received' AND status = 'HELD' AND due_date <= date(?, '+$lookaheadDays day') ORDER BY due_date",
      [today],
    );
    return rows.map(_fromRow).toList();
  }

  /// چک‌های پرداختیِ خود کاربر (صادرکننده = کاربر): یادآوری فقط از
  /// «۷ روز قبل از سررسید» تا «روز سررسید» — نه قبلش، نه بعدش.
  /// فقط یادآوری است؛ از کاربر «پاس شد؟» پرسیده نمی‌شود.
  List<ChequeEntity> upcomingIssued(String today, {int days = 7}) {
    final rows = store.db.select(
      "SELECT * FROM cheques WHERE direction = 'issued' AND status = 'HELD' "
      "AND date(?) BETWEEN date(due_date, '-$days day') AND due_date "
      "ORDER BY due_date",
      [today],
    );
    return rows.map(_fromRow).toList();
  }

  /// جمع مبلغ چک‌های پرداختیِ در جریان — جزو «پرداختی‌های» فروشگاه
  int outstandingIssuedAmount() {
    final row = store.db.select(
      "SELECT COALESCE(SUM(amount), 0) AS v FROM cheques WHERE direction = 'issued' AND status = 'HELD'",
    ).first;
    return (row['v'] as num).round();
  }

  List<ChequeEntity> list(
      {String? direction, String? status, String? from, String? to}) {
    final where = <String>['1=1'];
    final args = <Object?>[];
    if (direction != null) {
      where.add('direction = ?');
      args.add(direction);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    if (from != null) {
      where.add('due_date >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('due_date <= ?');
      args.add(to);
    }
    return store.db
        .select(
            'SELECT * FROM cheques WHERE ${where.join(' AND ')} ORDER BY due_date DESC',
            args)
        .map(_fromRow)
        .toList();
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }
}
