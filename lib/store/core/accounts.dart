import '../db/store_database.dart';
import 'ledger.dart';

export 'ledger.dart';

/// تولید شناسهٔ یکتای محلی
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${_counter.incrementAndGet()}';

class _Counter {
  int _value = 0;
  int incrementAndGet() => ++_value;
}

final _counter = _Counter();

class FinancialAccount {
  final String id;
  final String name;
  final String type; // cash, bank, card, other
  final int openingBalance;
  final bool isActive;

  const FinancialAccount({
    required this.id,
    required this.name,
    required this.type,
    this.openingBalance = 0,
    this.isActive = true,
  });

  String get typeLabel {
    switch (type) {
      case 'cash':
        return 'صندوق نقدی';
      case 'bank':
        return 'حساب بانکی';
      case 'card':
        return 'کارت‌خوان';
      default:
        return 'سایر';
    }
  }
}

/// حساب‌های مالی: صندوق، بانک، کارت‌خوان...
/// موجودی هر حساب «مشتق» است: ماندهٔ آغازین + جمع رویدادهای مؤثر دفتر کل.
class AccountRepository {
  final StoreDatabase store;
  final LedgerRepository ledger;
  AccountRepository(this.store, this.ledger);

  List<FinancialAccount> list({bool onlyActive = false}) {
    final rows = store.db.select(
      onlyActive
          ? 'SELECT * FROM financial_accounts WHERE is_active = 1 ORDER BY created_at'
          : 'SELECT * FROM financial_accounts ORDER BY created_at',
    );
    return rows
        .map((r) => FinancialAccount(
              id: r['id'] as String,
              name: r['name'] as String,
              type: r['type'] as String,
              openingBalance: r['opening_balance'] as int,
              isActive: (r['is_active'] as int) == 1,
            ))
        .toList();
  }

  FinancialAccount? byId(String id) {
    final rows =
        store.db.select('SELECT * FROM financial_accounts WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return FinancialAccount(
      id: r['id'] as String,
      name: r['name'] as String,
      type: r['type'] as String,
      openingBalance: r['opening_balance'] as int,
      isActive: (r['is_active'] as int) == 1,
    );
  }

  String save({
    required String name,
    required String type,
    int openingBalance = 0,
    bool isActive = true,
    String? id,
  }) {
    final accountId = id ?? 'acc-${newId()}';
    store.db.execute(
      'INSERT INTO financial_accounts (id, name, type, opening_balance, is_active, created_at) '
      'VALUES (?,?,?,?,?,?) '
      'ON CONFLICT(id) DO UPDATE SET name = excluded.name, type = excluded.type, '
      'is_active = excluded.is_active',
      [
        accountId,
        name,
        type,
        openingBalance,
        isActive ? 1 : 0,
        DateTime.now().toIso8601String(),
      ],
    );
    return accountId;
  }

  void setActive(String id, bool active) {
    store.db.execute(
        'UPDATE financial_accounts SET is_active = ? WHERE id = ?', [active ? 1 : 0, id]);
  }

  /// موجودی فعلی حساب = مانده آغازین + ورودی‌ها − خروجی‌های مؤثر
  int balance(String accountId) {
    final inflow = ledger.sumField('amount', 'v',
        accountId: accountId, extraWhere: 'e.direction = 1');
    final outflow = ledger.sumField('amount', 'v',
        accountId: accountId, extraWhere: 'e.direction = -1');
    final opening =
        store.db.select('SELECT opening_balance FROM financial_accounts WHERE id = ?',
            [accountId]);
    final base = opening.isEmpty ? 0 : (opening.first['opening_balance'] as int);
    return base + inflow - outflow;
  }

  /// انتقال وجه بین حساب‌ها؛ درآمد/هزینه محسوب نمی‌شود (§9)
  /// idempotent با کلید transfer:<transferId>
  String transfer({
    required String fromAccountId,
    required String toAccountId,
    required int amount,
    required String date,
    String note = '',
    String? transferId,
  }) {
    if (amount <= 0) throw ArgumentError('مبلغ انتقال باید مثبت باشد');
    if (fromAccountId == toAccountId) {
      throw ArgumentError('حساب مبدأ و مقصد یکسان است');
    }
    final tid = transferId ?? 'tr-${newId()}';
    ledger.append(LedgerEntryInput(
      eventType: LedgerEventType.accountTransfer,
      date: date,
      amount: amount,
      direction: -1,
      accountId: fromAccountId,
      transferId: tid,
      description: 'انتقال وجه از $fromAccountId به $toAccountId $note',
      idempotencyKey: 'transfer-out:$tid',
    ));
    ledger.append(LedgerEntryInput(
      eventType: LedgerEventType.accountTransfer,
      date: date,
      amount: amount,
      direction: 1,
      accountId: toAccountId,
      transferId: tid,
      description: 'انتقال وجه دریافتی از $fromAccountId $note',
      idempotencyKey: 'transfer-in:$tid',
    ));
    return tid;
  }

  /// واریز به حساب (از بیرون سیستم) — درآمد نیست
  String deposit({
    required String accountId,
    required int amount,
    required String date,
    String note = '',
  }) {
    if (amount <= 0) throw ArgumentError('مبلغ باید مثبت باشد');
    return ledger.append(LedgerEntryInput(
      eventType: LedgerEventType.deposit,
      date: date,
      amount: amount,
      direction: 1,
      accountId: accountId,
      description: 'واریز به حساب $note',
      idempotencyKey: 'deposit-${newId()}',
    ));
  }

  /// برداشت از حساب — هزینه نیست
  String withdraw({
    required String accountId,
    required int amount,
    required String date,
    String note = '',
  }) {
    if (amount <= 0) throw ArgumentError('مبلغ باید مثبت باشد');
    return ledger.append(LedgerEntryInput(
      eventType: LedgerEventType.withdrawal,
      date: date,
      amount: amount,
      direction: -1,
      accountId: accountId,
      description: 'برداشت از حساب $note',
      idempotencyKey: 'withdraw-${newId()}',
    ));
  }
}
