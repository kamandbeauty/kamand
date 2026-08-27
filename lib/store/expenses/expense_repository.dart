import '../core/accounts.dart';
import '../core/audit.dart';
import '../db/store_database.dart';

class ExpenseCategory {
  final int id;
  final String key;
  final String title;
  final bool isSystem;
  const ExpenseCategory(this.id, this.key, this.title, this.isSystem);
}

class ExpenseRecord {
  final String id;
  final int categoryId;
  final int amount;
  final String date;
  final String description;
  final String? supplierId;
  final String? accountId;
  final String reference;
  final String? voidedAt;
  final bool isRecurring;
  const ExpenseRecord({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.date,
    required this.description,
    this.supplierId,
    this.accountId,
    this.reference = '',
    this.voidedAt,
    this.isRecurring = false,
  });
}

/// مدیریت هزینه‌ها (§8)
///
/// قانون مهم کسب‌وکار (§43): خرید عمدهٔ بسته‌بندی یک «هزینهٔ واقعی» ثبت
/// می‌شود و به‌صورت خودکار بین فاکتورها توزیع نمی‌شود. بازیافت آن از طریق
/// «دریافت بسته‌بندی از مشتری» (PACKAGING_CHARGE) انجام می‌شود که رویدادی
/// جداگانه است. گزارش‌ها هر دو را کنار هم نشان می‌دهند.
class ExpenseRepository {
  final StoreDatabase store;
  final LedgerRepository ledger;
  final AuditLog audit;
  ExpenseRepository(this.store, this.ledger, this.audit);

  List<ExpenseCategory> categories() {
    final rows =
        store.db.select('SELECT * FROM expense_categories ORDER BY sort, id');
    return rows
        .map((r) => ExpenseCategory(
              r['id'] as int,
              r['key'] as String,
              r['title'] as String,
              (r['is_system'] as int) == 1,
            ))
        .toList();
  }

  int addCategory(String key, String title) {
    store.db.execute(
      'INSERT INTO expense_categories (key, title, is_system, sort) VALUES (?,?,0,50)',
      [key, title],
    );
    return store.db
        .select('SELECT id FROM expense_categories WHERE key = ?', [key]).first['id'] as int;
  }

  String _eventTypeFor(ExpenseCategory category) {
    switch (category.key) {
      case 'SHIPPING':
        return LedgerEventType.shippingExpense;
      case 'PACKAGING':
        return LedgerEventType.packagingExpense;
      default:
        return LedgerEventType.expense;
    }
  }

  ExpenseCategory? categoryById(int id) {
    final rows = store.db
        .select('SELECT * FROM expense_categories WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return ExpenseCategory(
      r['id'] as int,
      r['key'] as String,
      r['title'] as String,
      (r['is_system'] as int) == 1,
    );
  }

  /// ثبت هزینه — همیشه با رویداد دفتر کل قابل ردیابی
  String add({
    required int categoryId,
    required int amount,
    required String date,
    String description = '',
    String? supplierId,
    String? accountId,
    String reference = '',
    String attachmentPath = '',
    bool isRecurring = false,
  }) {
    if (amount <= 0) throw ArgumentError('مبلغ هزینه باید مثبت باشد');
    final category = categoryById(categoryId);
    if (category == null) throw StateError('دستهٔ هزینه پیدا نشد');
    final id = 'exp-${newId()}';
    store.db.execute(
      'INSERT INTO expenses (id, category_id, amount, expense_date, description, supplier_id, account_id, reference, attachment_path, is_recurring, created_at) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?)',
      [
        id,
        categoryId,
        amount,
        date,
        description,
        supplierId,
        accountId,
        reference,
        attachmentPath,
        isRecurring ? 1 : 0,
        DateTime.now().toIso8601String(),
      ],
    );
    ledger.append(LedgerEntryInput(
      eventType: _eventTypeFor(category),
      date: date,
      amount: amount,
      direction: accountId == null ? 0 : -1,
      accountId: accountId,
      supplierId: supplierId,
      expenseId: id,
      reference: reference,
      description: '${category.title} — $description',
      idempotencyKey: 'expense:$id',
    ));
    audit.log('EXPENSE_CREATE', 'expense', id, '${category.title} $amount تومان');
    return id;
  }

  ExpenseRecord? byId(String id) {
    final rows = store.db.select('SELECT * FROM expenses WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  ExpenseRecord _fromRow(Map<String, Object?> r) => ExpenseRecord(
        id: r['id'] as String,
        categoryId: r['category_id'] as int,
        amount: r['amount'] as int,
        date: r['expense_date'] as String,
        description: (r['description'] ?? '') as String,
        supplierId: r['supplier_id'] as String?,
        accountId: r['account_id'] as String?,
        reference: (r['reference'] ?? '') as String,
        voidedAt: r['voided_at'] as String?,
        isRecurring: (r['is_recurring'] as int) == 1,
      );

  List<ExpenseRecord> list({
    int? categoryId,
    String? supplierId,
    String? accountId,
    String? from,
    String? to,
    bool includeVoided = false,
    int limit = 300,
  }) {
    final where = <String>['1=1'];
    final args = <Object?>[];
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (supplierId != null) {
      where.add('supplier_id = ?');
      args.add(supplierId);
    }
    if (accountId != null) {
      where.add('account_id = ?');
      args.add(accountId);
    }
    if (from != null) {
      where.add('expense_date >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('expense_date <= ?');
      args.add(to);
    }
    if (!includeVoided) where.add('voided_at IS NULL');
    args.add(limit);
    return store.db
        .select(
            'SELECT * FROM expenses WHERE ${where.join(' AND ')} ORDER BY expense_date DESC, created_at DESC LIMIT ?',
            args)
        .map(_fromRow)
        .toList();
  }

  /// ابطال ایمن هزینه — هرگز حذف فیزیکی نمی‌شود؛ اثر معکوس ثبت می‌شود (§58)
  void voidExpense(String id, {String reason = ''}) {
    final expense = byId(id);
    if (expense == null) throw StateError('هزینه پیدا نشد');
    if (expense.voidedAt != null) {
      throw StateError('این هزینه قبلاً ابطال شده است');
    }
    store.db.execute('UPDATE expenses SET voided_at = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), id]);
    final ev = store.db.select(
        'SELECT id FROM ledger_events WHERE expense_id = ? AND reversal_of IS NULL',
        [id]);
    if (ev.isNotEmpty) {
      ledger.reverse(ev.first['id'] as String, description: 'ابطال هزینه — $reason');
    }
    audit.log('EXPENSE_VOID', 'expense', id, reason);
  }

  /// ویرایش مبلغ/توضیح: اثر معکوس + ثبت مجدد (تصحیح، نه دست‌کاری تاریخ) (§58)
  void edit(
    String id, {
    int? amount,
    String? description,
    int? categoryId,
    String? accountId,
  }) {
    final expense = byId(id);
    if (expense == null) throw StateError('هزینه پیدا نشد');
    if (expense.voidedAt != null) throw StateError('هزینهٔ ابطال‌شده قابل ویرایش نیست');
    if (amount != null && amount != expense.amount) {
      final ev = store.db.select(
          'SELECT id FROM ledger_events WHERE expense_id = ? AND reversal_of IS NULL',
          [id]);
      if (ev.isNotEmpty) {
        ledger.reverse(ev.first['id'] as String, description: 'تصحیح مبلغ هزینه');
      }
      store.db.execute(
        'UPDATE expenses SET amount = ?, description = ?, category_id = ?, account_id = ? WHERE id = ?',
        [
          amount,
          description ?? expense.description,
          categoryId ?? expense.categoryId,
          accountId ?? expense.accountId,
          id,
        ],
      );
      final category = categoryById(categoryId ?? expense.categoryId)!;
      ledger.append(LedgerEntryInput(
        eventType: _eventTypeFor(category),
        date: expense.date,
        amount: amount,
        direction: (accountId ?? expense.accountId) == null ? 0 : -1,
        accountId: accountId ?? expense.accountId,
        supplierId: expense.supplierId,
        expenseId: id,
        description: '${category.title} (تصحیح) — ${description ?? expense.description}',
        idempotencyKey: 'expense-fix:$id:${newId()}',
      ));
    } else {
      store.db.execute(
        'UPDATE expenses SET description = ?, category_id = ?, account_id = ? WHERE id = ?',
        [
          description ?? expense.description,
          categoryId ?? expense.categoryId,
          accountId ?? expense.accountId,
          id,
        ],
      );
    }
    audit.log('EXPENSE_EDIT', 'expense', id, '');
  }

  /// جمع هزینه به تفکیک دسته برای بازه
  List<Map<String, Object?>> totalsByCategory({String? from, String? to}) {
    final where = <String>['e.voided_at IS NULL'];
    final args = <Object?>[];
    if (from != null) {
      where.add('e.expense_date >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('e.expense_date <= ?');
      args.add(to);
    }
    return store.db.select(
      'SELECT c.key AS cat_key, c.title AS cat_title, COALESCE(SUM(e.amount), 0) AS total, COUNT(*) AS cnt '
      'FROM expenses e JOIN expense_categories c ON c.id = e.category_id '
      'WHERE ${where.join(' AND ')} GROUP BY c.id ORDER BY total DESC',
      args,
    );
  }

  /// جمع ماهانهٔ هزینه‌ها
  List<Map<String, Object?>> monthlyTotals({int months = 12}) {
    return store.db.select(
      "SELECT substr(expense_date, 1, 7) AS ym, COALESCE(SUM(amount), 0) AS total "
      "FROM expenses WHERE voided_at IS NULL GROUP BY ym ORDER BY ym DESC LIMIT ?",
      [months],
    );
  }
}
