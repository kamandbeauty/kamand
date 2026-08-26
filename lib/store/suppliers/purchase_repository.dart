import '../core/accounts.dart';
import '../core/audit.dart';
import '../core/inventory.dart';
import '../db/store_database.dart';

class PurchaseItemInput {
  final String productId;
  final String title;
  final double quantity;
  final String unit;
  final int unitPrice;
  const PurchaseItemInput({
    required this.productId,
    required this.title,
    this.quantity = 1,
    this.unit = 'عدد',
    this.unitPrice = 0,
  });
}

class PurchaseInvoice {
  final String id;
  final String supplierId;
  final String number;
  final String date;
  final int subtotal;
  final int discount;
  final int shipping;
  final int otherCosts;
  final int tax;
  final int total;
  final int paid;
  final String status;
  final String notes;
  const PurchaseInvoice({
    required this.id,
    required this.supplierId,
    required this.number,
    required this.date,
    required this.subtotal,
    required this.discount,
    required this.shipping,
    required this.otherCosts,
    required this.tax,
    required this.total,
    required this.paid,
    required this.status,
    required this.notes,
  });
}

class PurchaseReturnInput {
  final String purchaseItemId;
  final double quantity;
  const PurchaseReturnInput({required this.purchaseItemId, required this.quantity});
}

/// فاکتورهای خرید — ورود موجودی + رویداد مالی + بدهی تأمین‌کننده
/// همهٔ عملیات‌ها تراکنشی و idempotent هستند.
class PurchaseRepository {
  final StoreDatabase store;
  final LedgerRepository ledger;
  final InventoryRepository inventory;
  final AuditLog audit;

  PurchaseRepository(this.store, this.ledger, this.inventory, this.audit);

  /// ایجاد فاکتور خرید:
  /// - موجودی را (فقط) از طریق InventoryRepository افزایش می‌دهد
  /// - رویداد PURCHASE و در صورت پرداخت PURCHASE_PAYMENT ثبت می‌کند
  /// - هزینه‌های جانبی به‌تناسب اقلام در بهای تمام‌شده توزیع می‌شود
  PurchaseInvoice create({
    required String supplierId,
    required String date,
    required List<PurchaseItemInput> items,
    int discount = 0,
    int shipping = 0,
    int otherCosts = 0,
    int tax = 0,
    int paidAmount = 0,
    String? accountId,
    String number = '',
    String notes = '',
  }) {
    if (items.isEmpty) throw ArgumentError('فاکتور خرید باید حداقل یک قلم داشته باشد');
    final subtotal =
        items.fold(0, (sum, i) => sum + (i.unitPrice * i.quantity).round());
    final total = subtotal - discount + shipping + otherCosts + tax;
    if (total < 0) throw ArgumentError('جمع فاکتور خرید نمی‌تواند منفی باشد');
    if (paidAmount > total) throw ArgumentError('پرداخت نمی‌تواند از جمع فاکتور بیشتر باشد');
    final pid = 'pur-${newId()}';

    final db = store.db;
    store.txn(() {
      db.execute(
        'INSERT INTO purchase_invoices (id, supplier_id, number, purchase_date, subtotal, discount, shipping, other_costs, tax, total, paid, status, notes, created_at) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          pid,
          supplierId,
          number,
          date,
          subtotal,
          discount,
          shipping,
          otherCosts,
          tax,
          total,
          0,
          'unpaid',
          notes,
          DateTime.now().toIso8601String(),
        ],
      );
      // توزیع هزینه‌های جانبی (ارسال/سایر/مالیات − تخفیف) به‌تناسب ارزش اقلام
      final extraCosts = tax + shipping + otherCosts - discount;
      final allocated = subtotal > 0 && extraCosts != 0
          ? _allocate(subtotal, extraCosts, items.map((i) => (i.unitPrice * i.quantity).round()).toList())
          : List<int>.filled(items.length, 0);
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final itemTotal = (item.unitPrice * item.quantity).round();
        db.execute(
          'INSERT INTO purchase_items (id, purchase_id, product_id, title, quantity, unit, unit_price, total_price) '
          'VALUES (?,?,?,?,?,?,?,?)',
          [
            'pit-${newId()}',
            pid,
            item.productId,
            item.title,
            item.quantity,
            item.unit,
            item.unitPrice,
            itemTotal,
          ],
        );
        if (item.productId.isNotEmpty && item.quantity > 0) {
          final unitCost = item.quantity > 0
              ? ((itemTotal + allocated[i]) / item.quantity).round()
              : item.unitPrice;
          final safeCost = unitCost < 0 ? 0 : unitCost;
          inventory.receive(
            item.productId,
            item.quantity,
            movementType: StockMovementType.purchase,
            unitCost: safeCost,
            date: date,
            refType: 'purchase',
            refId: pid,
            idempotencyKey: 'purchase:$pid:item:${item.productId}',
          );
        }
      }

      // رویداد مالی خرید: افزایش بدهی تأمین‌کننده
      ledger.append(LedgerEntryInput(
        eventType: LedgerEventType.purchase,
        date: date,
        amount: total,
        supplierId: supplierId,
        purchaseId: pid,
        supplierDelta: total,
        description: 'فاکتور خرید $number',
        idempotencyKey: 'purchase:$pid',
      ));

      if (paidAmount > 0) {
        if (accountId == null || accountId.isEmpty) {
          throw ArgumentError('برای پرداخت، حساب مالی لازم است');
        }
        final paymentId = 'spay-${newId()}';
        db.execute(
          'INSERT OR IGNORE INTO supplier_payments (id, supplier_id, purchase_id, amount, payment_date, account_id, method, reference, created_at) '
          'VALUES (?,?,?,?,?,?,?,?,?)',
          [
            paymentId,
            supplierId,
            pid,
            paidAmount,
            date,
            accountId,
            'purchase',
            number,
            DateTime.now().toIso8601String(),
          ],
        );
        ledger.append(LedgerEntryInput(
          eventType: LedgerEventType.purchasePayment,
          date: date,
          amount: paidAmount,
          direction: -1,
          accountId: accountId,
          supplierId: supplierId,
          purchaseId: pid,
          paymentId: paymentId,
          supplierDelta: -paidAmount,
          description: 'پرداخت فاکتور خرید $number',
          idempotencyKey: 'payment:$paymentId',
        ));
        db.execute(
            'UPDATE purchase_invoices SET paid = ?, status = ? WHERE id = ?',
            [
              paidAmount,
              paidAmount >= total ? 'paid' : 'partial',
              pid,
            ]);
      }
    });
    audit.log('PURCHASE_CREATE', 'purchase', pid, 'جمع $total تومان');
    return byId(pid)!;
  }

  List<int> _allocate(int baseTotal, int extra, List<int> weights) {
    final result = List<int>.filled(weights.length, 0);
    if (baseTotal == 0) return result;
    var distributed = 0;
    for (var i = 0; i < weights.length; i++) {
      final share = (extra * weights[i]) ~/ baseTotal;
      result[i] = share;
      distributed += share;
    }
    result[0] += extra - distributed; // باقیمانده روی قلم اول
    return result;
  }

  PurchaseInvoice? byId(String id) {
    final rows =
        store.db.select('SELECT * FROM purchase_invoices WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return PurchaseInvoice(
      id: r['id'] as String,
      supplierId: r['supplier_id'] as String,
      number: (r['number'] ?? '') as String,
      date: r['purchase_date'] as String,
      subtotal: r['subtotal'] as int,
      discount: r['discount'] as int,
      shipping: r['shipping'] as int,
      otherCosts: r['other_costs'] as int,
      tax: r['tax'] as int,
      total: r['total'] as int,
      paid: r['paid'] as int,
      status: r['status'] as String,
      notes: (r['notes'] ?? '') as String,
    );
  }

  List<PurchaseInvoice> list({String? supplierId, String? from, String? to}) {
    final where = <String>['1=1'];
    final args = <Object?>[];
    if (supplierId != null) {
      where.add('supplier_id = ?');
      args.add(supplierId);
    }
    if (from != null) {
      where.add('purchase_date >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('purchase_date <= ?');
      args.add(to);
    }
    final rows = store.db.select(
        'SELECT * FROM purchase_invoices WHERE ${where.join(' AND ')} ORDER BY created_at DESC',
        args);
    return rows.map((r) => PurchaseInvoice(
          id: r['id'] as String,
          supplierId: r['supplier_id'] as String,
          number: (r['number'] ?? '') as String,
          date: r['purchase_date'] as String,
          subtotal: r['subtotal'] as int,
          discount: r['discount'] as int,
          shipping: r['shipping'] as int,
          otherCosts: r['other_costs'] as int,
          tax: r['tax'] as int,
          total: r['total'] as int,
          paid: r['paid'] as int,
          status: r['status'] as String,
          notes: (r['notes'] ?? '') as String,
        )).toList();
  }

  List<Map<String, Object?>> items(String purchaseId) => store.db.select(
      'SELECT * FROM purchase_items WHERE purchase_id = ?', [purchaseId]);

  double returnedQty(String purchaseItemId) {
    final row = store.db.select(
      'SELECT COALESCE(SUM(quantity), 0) AS q FROM purchase_return_items WHERE purchase_item_id = ?',
      [purchaseItemId],
    ).first;
    return (row['q'] as num).toDouble();
  }

  /// برگشت از خرید — هرگز بیشتر از مقدار خریدشده/باقی‌مانده نمی‌پذیرد (§50)
  /// [reducePayable] true = کاهش بدهی تأمین‌کننده، false = دریافت نقدی وجه
  String returnPurchase({
    required String purchaseId,
    required List<PurchaseReturnInput> returnItems,
    required String date,
    bool reducePayable = true,
    String? refundAccountId,
    String notes = '',
  }) {
    final purchase = byId(purchaseId);
    if (purchase == null) throw StateError('فاکتور خرید پیدا نشد');
    if (returnItems.isEmpty) throw ArgumentError('برگشت خالی است');
    final db = store.db;
    final rid = 'pret-${newId()}';
    var total = 0;
    store.txn(() {
      for (final ri in returnItems) {
        final rows = db.select(
            'SELECT * FROM purchase_items WHERE id = ? AND purchase_id = ?',
            [ri.purchaseItemId, purchaseId]);
        if (rows.isEmpty) throw StateError('قلم خرید پیدا نشد: ${ri.purchaseItemId}');
        final item = rows.first;
        final purchased = (item['quantity'] as num).toDouble();
        final already = returnedQty(ri.purchaseItemId);
        if (ri.quantity <= 0) throw ArgumentError('تعداد برگشت باید مثبت باشد');
        if (already + ri.quantity > purchased) {
          throw StateError(
              'برگشت بیشتر از خرید مجاز نیست: خرید $purchased، برگشتی قبلی $already، درخواست ${ri.quantity}');
        }
        final unitPrice = item['unit_price'] as int;
        final itemTotal = (unitPrice * ri.quantity).round();
        total += itemTotal;
        final productId = (item['product_id'] ?? '') as String;
        db.execute(
          'INSERT INTO purchase_return_items (id, return_id, purchase_item_id, product_id, title, quantity, unit_price, total_price) '
          'VALUES (?,?,?,?,?,?,?,?)',
          [
            'prit-${newId()}',
            rid,
            ri.purchaseItemId,
            productId,
            item['title'] as String,
            ri.quantity,
            unitPrice,
            itemTotal,
          ],
        );
        if (productId.isNotEmpty) {
          inventory.deduct(
            productId,
            ri.quantity,
            movementType: StockMovementType.purchaseReturn,
            date: date,
            refType: 'purchase_return',
            refId: rid,
            idempotencyKey: 'purchase-return:$rid:item:$productId',
          );
        }
      }
      db.execute(
        'INSERT INTO purchase_returns (id, purchase_id, return_date, total, reduce_payable, notes, created_at) '
        'VALUES (?,?,?,?,?,?,?)',
        [
          rid,
          purchaseId,
          date,
          total,
          reducePayable ? 1 : 0,
          notes,
          DateTime.now().toIso8601String(),
        ],
      );

      ledger.append(LedgerEntryInput(
        eventType: LedgerEventType.purchaseReturn,
        date: date,
        amount: total,
        direction: reducePayable ? 0 : 1,
        accountId: reducePayable ? null : refundAccountId,
        supplierId: purchase.supplierId,
        purchaseId: purchaseId,
        supplierDelta: reducePayable ? -total : 0,
        description: 'برگشت از خرید $notes',
        idempotencyKey: 'purchase-return:$rid',
      ));
    });
    audit.log('PURCHASE_RETURN', 'purchase_return', rid, 'جمع $total تومان');
    return rid;
  }
}
