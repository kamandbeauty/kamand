import '../db/store_database.dart';
import 'accounts.dart';
import 'audit.dart';

/// انواع حرکت موجودی — موجودی کالا «فقط» از طریق این مخزن تغییر می‌کند (§4)
class StockMovementType {
  static const purchase = 'purchase'; // ورود خرید +
  static const sale = 'sale'; // خروج فروش -
  static const saleReturn = 'sale_return'; // بازگشت از مشتری +
  static const purchaseReturn = 'purchase_return'; // بازگشت به تأمین‌کننده -
  static const adjustment = 'adjustment'; // اصلاح (امضادار) +/-
  static const opening = 'opening'; // موجودی آغازین همگام‌شده از کاتالوگ
}

class StockMovement {
  final String id;
  final String productId;
  final String movementType;
  final double quantity; // مثبت = ورود، منفی = خروج
  final int unitCost;
  final String refType;
  final String refId;
  final String note;
  final String movementDate;
  final String createdAt;

  const StockMovement({
    required this.id,
    required this.productId,
    required this.movementType,
    required this.quantity,
    required this.unitCost,
    required this.refType,
    required this.refId,
    required this.note,
    required this.movementDate,
    required this.createdAt,
  });
}

class ProductStockState {
  final String productId;
  final double currentQty;
  final double minQty;
  final int avgCost;
  const ProductStockState(this.productId, this.currentQty, this.minQty, this.avgCost);
}

class InventoryRepository {
  final StoreDatabase store;
  final AuditLog audit;
  InventoryRepository(this.store, this.audit);

  /// ثبت/همگام‌سازی اولیهٔ محصول از کاتالوگ موجود (idempotent).
  /// اگر مقدار اولیهٔ غیرصفر همراه سطر جدید بیاید، یک حرکت «افتتاحیه» ثبت
  /// می‌شود تا «موجودی = جمع حرکت‌ها» همیشه برقرار بماند (§51).
  void ensureProduct(String productId,
      {double currentQty = 0, double minQty = 0, int avgCost = 0}) {
    store.db.execute(
      'INSERT INTO product_stock (product_id, current_qty, min_qty, avg_cost, updated_at) '
      'VALUES (?,?,?,?,?) ON CONFLICT(product_id) DO NOTHING',
      [productId, currentQty, minQty, avgCost, DateTime.now().toIso8601String()],
    );
    final moved = store.db.select(
        'SELECT COUNT(*) AS c FROM stock_movements WHERE product_id = ?', [productId]);
    if ((moved.first['c'] as int) == 0 && currentQty != 0) {
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      store.db.execute(
        'INSERT OR IGNORE INTO stock_movements '
        '(id, product_id, movement_type, quantity, unit_cost, ref_type, ref_id, note, movement_date, idempotency_key, created_at) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?)',
        [
          'mv-open-$productId',
          productId,
          StockMovementType.opening,
          currentQty,
          0,
          'opening',
          productId,
          'موجودی آغازین از کاتالوگ',
          today,
          'open:$productId',
          now.toIso8601String(),
        ],
      );
    }
  }

  void setMinQty(String productId, double minQty) {
    ensureProduct(productId);
    store.db.execute(
        'UPDATE product_stock SET min_qty = ?, updated_at = ? WHERE product_id = ?',
        [minQty, DateTime.now().toIso8601String(), productId]);
  }

  ProductStockState? state(String productId) {
    final rows = store.db
        .select('SELECT * FROM product_stock WHERE product_id = ?', [productId]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return ProductStockState(
      productId,
      (r['current_qty'] as num).toDouble(),
      (r['min_qty'] as num).toDouble(),
      r['avg_cost'] as int,
    );
  }

  double currentQty(String productId) => state(productId)?.currentQty ?? 0;
  int avgCost(String productId) => state(productId)?.avgCost ?? 0;

  /// ورود کالا (خرید یا برگشت فروش) — به‌روزرسانی میانگین موزون بهای تمام‌شده
  void receive(
    String productId,
    double qty, {
    required String movementType,
    required int unitCost,
    required String date,
    String refType = '',
    String refId = '',
    String note = '',
    String? idempotencyKey,
  }) {
    if (qty <= 0) throw ArgumentError('تعداد ورود باید مثبت باشد');
    _move(productId, qty,
        movementType: movementType,
        unitCost: unitCost,
        date: date,
        refType: refType,
        refId: refId,
        note: note,
        idempotencyKey: idempotencyKey);
  }

  /// خروج کالا (فروش یا برگشت خرید) — مطابق مدل کسب‌وکار کاربر:
  /// فروش کالای ناموجود مجاز است و موجودی را **منفی** می‌کند (مثلاً ۵ فروش
  /// از موجودی صفر → −۵) و خرید بعدی آن را جبران می‌کند (۶ خرید → +۱).
  /// تمام حرکت‌ها همچنان شفاف و ردیابی‌شده ثبت می‌شوند.
  void deduct(
    String productId,
    double qty, {
    required String movementType,
    required String date,
    String refType = '',
    String refId = '',
    String note = '',
    String? idempotencyKey,
  }) {
    if (qty <= 0) throw ArgumentError('تعداد خروج باید مثبت باشد');
    _move(productId, -qty,
        movementType: movementType,
        unitCost: 0,
        date: date,
        refType: refType,
        refId: refId,
        note: note,
        idempotencyKey: idempotencyKey);
  }

  /// اصلاح موجودی به مقدار هدف — با ثبت حرکت شفاف اصلاح
  void adjustTo(String productId, double targetQty,
      {required String date, String note = 'اصلاح موجودی'}) {
    ensureProduct(productId);
    final cur = currentQty(productId);
    final delta = targetQty - cur;
    if (delta == 0) return;
    _move(productId, delta,
        movementType: StockMovementType.adjustment,
        unitCost: 0,
        date: date,
        refType: 'adjustment',
        refId: '',
        note: note,
        idempotencyKey: 'adj-$productId-${newId()}');
    audit.log('STOCK_ADJUST', 'product', productId,
        'از $cur به $targetQty — $note');
  }

  void _move(
    String productId,
    double signedQty, {
    required String movementType,
    required int unitCost,
    required String date,
    String refType = '',
    String refId = '',
    String note = '',
    String? idempotencyKey,
  }) {
    ensureProduct(productId);
    final db = store.db;
    store.txn(() {
      final before = state(productId)!;
      final mid = 'mv-${newId()}';
      db.execute(
        'INSERT OR IGNORE INTO stock_movements '
        '(id, product_id, movement_type, quantity, unit_cost, ref_type, ref_id, note, movement_date, idempotency_key, created_at) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?)',
        [
          mid,
          productId,
          movementType,
          signedQty,
          unitCost,
          refType,
          refId,
          note,
          date,
          idempotencyKey,
          DateTime.now().toIso8601String(),
        ],
      );
      // اگر حرکت تکراری بود (IGNORE شد) چیزی تغییر نکن
      final inserted = db.select('SELECT COUNT(*) AS c FROM stock_movements WHERE id = ?', [mid]).first['c'] as int;
      if (inserted == 0) return;
      var newQty = before.currentQty + signedQty;
      // موجودی منفی مجاز است (فروش ناموجود) — فقط ثبت شفاف
      var newAvg = before.avgCost;
      if (signedQty > 0 && unitCost > 0) {
        final totalQty = before.currentQty + signedQty;
        if (totalQty > 0) {
          // میانگین موزون: (موجودی×میانگین + ورود×بها) / جمع
          newAvg = ((before.avgCost * before.currentQty) + (unitCost * signedQty)) ~/
              totalQty;
        }
      }
      db.execute(
        'UPDATE product_stock SET current_qty = ?, avg_cost = ?, updated_at = ? WHERE product_id = ?',
        [newQty, newAvg, DateTime.now().toIso8601String(), productId],
      );
    });
  }

  List<StockMovement> movements(String productId, {int limit = 200}) {
    final rows = store.db.select(
      'SELECT * FROM stock_movements WHERE product_id = ? ORDER BY created_at DESC LIMIT ?',
      [productId, limit],
    );
    return rows
        .map((r) => StockMovement(
              id: r['id'] as String,
              productId: r['product_id'] as String,
              movementType: r['movement_type'] as String,
              quantity: (r['quantity'] as num).toDouble(),
              unitCost: r['unit_cost'] as int,
              refType: (r['ref_type'] ?? '') as String,
              refId: (r['ref_id'] ?? '') as String,
              note: (r['note'] ?? '') as String,
              movementDate: r['movement_date'] as String,
              createdAt: r['created_at'] as String,
            ))
        .toList();
  }

  /// کالاهای کم‌موجودی (موجودی <= حداقل) برای هشدار داشبورد
  List<ProductStockState> lowStock() {
    final rows = store.db.select(
      'SELECT * FROM product_stock WHERE current_qty <= min_qty AND min_qty >= 0 AND product_id != \'\'',
    );
    return rows
        .map((r) => ProductStockState(
              r['product_id'] as String,
              (r['current_qty'] as num).toDouble(),
              (r['min_qty'] as num).toDouble(),
              r['avg_cost'] as int,
            ))
        .toList();
  }

  /// ارزش‌گذاری موجودی به بهای میانگین
  int valuation() {
    final row = store.db.select(
      'SELECT COALESCE(SUM(current_qty * avg_cost), 0) AS v FROM product_stock',
    ).first;
    // ضرب REAL×INTEGER در SQLite خروجی REAL می‌دهد — تبدیل امن
    return (row['v'] as num).round();
  }
}
