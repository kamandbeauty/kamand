import '../core/accounts.dart';
import '../core/audit.dart';
import '../db/store_database.dart';

class Supplier {
  final String id;
  final String name;
  final String mobile;
  final String company;
  final String address;
  final String economicId;
  final String notes;
  final bool isActive;

  const Supplier({
    required this.id,
    required this.name,
    this.mobile = '',
    this.company = '',
    this.address = '',
    this.economicId = '',
    this.notes = '',
    this.isActive = true,
  });
}

/// مدیریت تأمین‌کنندگان — بدهی تأمین‌کننده همیشه از دفتر کل مشتق می‌شود
class SupplierRepository {
  final StoreDatabase store;
  final LedgerRepository ledger;
  final AuditLog audit;
  SupplierRepository(this.store, this.ledger, this.audit);

  List<Supplier> list({String search = '', bool? onlyActive}) {
    final where = <String>['1=1'];
    final args = <Object?>[];
    if (search.isNotEmpty) {
      where.add('(name LIKE ? OR mobile LIKE ? OR company LIKE ?)');
      args.addAll(['%$search%', '%$search%', '%$search%']);
    }
    if (onlyActive == true) where.add('is_active = 1');
    final rows = store.db.select(
        'SELECT * FROM suppliers WHERE ${where.join(' AND ')} ORDER BY name', args);
    return rows.map((r) => _fromRow(r)).toList();
  }

  Supplier? byId(String id) {
    final rows = store.db.select('SELECT * FROM suppliers WHERE id = ?', [id]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Supplier _fromRow(Map<String, Object?> r) => Supplier(
        id: r['id'] as String,
        name: r['name'] as String,
        mobile: (r['mobile'] ?? '') as String,
        company: (r['company'] ?? '') as String,
        address: (r['address'] ?? '') as String,
        economicId: (r['economic_id'] ?? '') as String,
        notes: (r['notes'] ?? '') as String,
        isActive: (r['is_active'] as int) == 1,
      );

  String save({
    required String name,
    String mobile = '',
    String company = '',
    String address = '',
    String economicId = '',
    String notes = '',
    bool isActive = true,
    String? id,
  }) {
    final sid = id ?? 'sup-${newId()}';
    store.db.execute(
      'INSERT INTO suppliers (id, name, mobile, company, address, economic_id, notes, is_active, created_at) '
      'VALUES (?,?,?,?,?,?,?,?,?) '
      'ON CONFLICT(id) DO UPDATE SET name = excluded.name, mobile = excluded.mobile, '
      'company = excluded.company, address = excluded.address, economic_id = excluded.economic_id, '
      'notes = excluded.notes, is_active = excluded.is_active',
      [
        sid,
        name,
        mobile,
        company,
        address,
        economicId,
        notes,
        isActive ? 1 : 0,
        DateTime.now().toIso8601String(),
      ],
    );
    audit.log(id == null ? 'SUPPLIER_CREATE' : 'SUPPLIER_UPDATE', 'supplier', sid, name);
    return sid;
  }

  void setActive(String id, bool active) {
    store.db.execute(
        'UPDATE suppliers SET is_active = ? WHERE id = ?', [active ? 1 : 0, id]);
    audit.log('SUPPLIER_TOGGLE', 'supplier', id, active ? 'فعال' : 'غیرفعال');
  }

  /// بدهی فعلی به تأمین‌کننده (مثبت = بدهکاریم)
  int payable(String supplierId) =>
      ledger.sumField('supplier_delta', 'v', supplierId: supplierId);

  /// پرداخت به تأمین‌کننده — کاهش بدهی + خروج وجه از حساب
  /// idempotent با کلید payment:<paymentId>
  String pay({
    required String supplierId,
    required int amount,
    required String date,
    required String accountId,
    String? purchaseId,
    String method = 'cash',
    String reference = '',
    String notes = '',
  }) {
    if (amount <= 0) throw ArgumentError('مبلغ پرداخت باید مثبت باشد');
    final pid = 'spay-${newId()}';
    ledger.append(LedgerEntryInput(
      eventType: LedgerEventType.supplierPayment,
      date: date,
      amount: amount,
      direction: -1,
      accountId: accountId,
      supplierId: supplierId,
      purchaseId: purchaseId,
      paymentId: pid,
      reference: reference,
      description: notes,
      supplierDelta: -amount,
      idempotencyKey: 'payment:$pid',
    ));
    if (purchaseId != null) {
      _applyPurchasePayment(purchaseId, amount);
    }
    audit.log('SUPPLIER_PAYMENT', 'supplier', supplierId, 'پرداخت $amount تومان ($pid)');
    return pid;
  }

  void _applyPurchasePayment(String purchaseId, int amount) {
    final row = store.db
        .select('SELECT paid, total FROM purchase_invoices WHERE id = ?', [purchaseId]);
    if (row.isEmpty) return;
    final paid = (row.first['paid'] as int) + amount;
    final total = row.first['total'] as int;
    final status = paid >= total ? 'paid' : (paid > 0 ? 'partial' : 'unpaid');
    store.db.execute(
        'UPDATE purchase_invoices SET paid = ?, status = ? WHERE id = ?', [paid, status, purchaseId]);
  }

  /// صورت‌حساب تأمین‌کننده — رویدادهای مالی مؤثر
  List<LedgerEvent> statement(String supplierId, {int limit = 300}) =>
      ledger.effectiveEvents(supplierId: supplierId, limit: limit);
}
