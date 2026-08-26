import 'package:shamsi_date/shamsi_date.dart';

import '../../models/invoice_model.dart';
import '../core/accounts.dart';
import '../core/audit.dart';
import '../core/inventory.dart';
import '../core/money.dart';
import '../db/store_database.dart';

/// پل میان جریان فاکتور موجود و هستهٔ حسابداری جدید.
///
/// اصول:
/// - ذخیرهٔ اسناد فاکتور در لایهٔ قبلی دست‌نخورده می‌ماند؛ این پل فقط
///   «آینهٔ مالی» (sales_documents + دفتر کل + موجودی) را به‌روز نگه می‌دارد.
/// - همهٔ اثرات مالی نسخه‌دار (v1, v2, ...) و idempotent هستند؛ ویرایش فاکتور
///   یعنی معکوس‌سازی دقیق نسخهٔ قبل + ثبت نسخهٔ جدید.
/// - فاکتور حذف‌شده هرگز از تاریخ مالی پاک نمی‌شود؛ فقط اثرش معکوس و سند
///   «deleted» می‌شود (§40، §41).
class SalesLedgerBridge {
  final StoreDatabase store;
  final LedgerRepository ledger;
  final InventoryRepository inventory;
  final AuditLog audit;

  /// یافتن شناسهٔ کاتالوگ برای قلم فاکتور (با عنوان) — اختیاری
  String? Function(String title)? productMatcher;

  SalesLedgerBridge({
    required this.store,
    required this.ledger,
    required this.inventory,
    required this.audit,
    this.productMatcher,
  });

  static const defaultCashAccount = 'acc-cash';

  /// تاریخ جلالی فاکتور موجود ('1404/06/05') را به میلادی ISO برمی‌گرداند
  String toIsoDate(String jalaliDate) {
    try {
      final parts = jalaliDate.split('/');
      if (parts.length == 3) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        if (y > 1200 && y < 1600 && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          final g = Jalali(y, m, d).toDateTime();
          return '${g.year.toString().padLeft(4, '0')}-${g.month.toString().padLeft(2, '0')}-${g.day.toString().padLeft(2, '0')}';
        }
      }
      // شاید از قبل میلادی باشد
      final parsed = DateTime.tryParse(jalaliDate);
      if (parsed != null) {
        return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Map<String, Object?>? _docRow(String sourceId) {
    final rows = store.db
        .select('SELECT * FROM sales_documents WHERE source_id = ?', [sourceId]);
    return rows.isEmpty ? null : rows.first;
  }

  /// یکتایی شمارهٔ فاکتور بین اسناد «فعال» (§42) — سابقهٔ حذف‌شده آزاد می‌ماند
  bool isInvoiceNumberTaken(String number, {String? excludeSourceId}) {
    if (number.trim().isEmpty) return false;
    final rows = store.db.select(
      "SELECT COUNT(*) AS c FROM sales_documents WHERE number = ? AND status = 'active' AND deleted_at IS NULL AND source_id != ?",
      [number.trim(), excludeSourceId ?? ''],
    );
    return (rows.first['c'] as int) > 0;
  }

  int _activeVersion(String sourceId) {
    final row = _docRow(sourceId);
    if (row == null) return 0;
    return (row['ledger_version'] as int? ?? 0);
  }

  /// ذخیره/ویرایش فاکتور فروش — هم‌نما با سند موجود، اثرات مالی نسخه‌دار
  void onInvoiceSaved(InvoiceModel invoice) {
    if (invoice.type != 'sale') return; // پیش‌فاکتور/خرید قدیمی وارد دفتر مالی نمی‌شوند
    final sourceId = invoice.id;
    final isoDate = toIsoDate(invoice.date);
    final revenue = _clampMoney(invoice.subtotal - invoice.discountAmount + invoice.shippingFee);
    final total = Money.fromDouble(invoice.totalAmount);
    final paid = Money.fromDouble(invoice.paidAmount);
    final remaining = Money.fromDouble(invoice.remainingAmount);

    final oldRow = _docRow(sourceId);
    final oldVersion = oldRow == null ? 0 : (oldRow['ledger_version'] as int? ?? 0);
    final nextVersion = oldVersion + 1;

    // §42 — یکتایی شمارهٔ فاکتور بین اسناد فعال (فقط سند جدید یا تغییر شماره)
    if (oldRow == null && isInvoiceNumberTaken(invoice.number)) {
      audit.log('INVOICE_NUMBER_DUP', 'invoice', sourceId,
          'شمارهٔ ${invoice.number} تکراری — سند فعال دیگری دارد');
      throw StateError('شمارهٔ فاکتور ${invoice.number} قبلاً برای فاکتور فعال دیگری ثبت شده است');
    }
    if (oldRow != null &&
        (oldRow['number'] as String) != invoice.number &&
        isInvoiceNumberTaken(invoice.number, excludeSourceId: sourceId)) {
      audit.log('INVOICE_NUMBER_DUP', 'invoice', sourceId,
          'تغییر به شمارهٔ تکراری ${invoice.number} رد شد');
      throw StateError('شمارهٔ فاکتور ${invoice.number} برای فاکتور فعال دیگری ثبت شده است');
    }

    // اگر چیزی تغییر نکرده، رویداد تکراری ثبت نکن (idempotent)
    if (oldRow != null &&
        (oldRow['revenue'] as int) == revenue &&
        (oldRow['total'] as int) == total &&
        (oldRow['paid'] as int) == paid &&
        (oldRow['remaining'] as int) == remaining &&
        (oldRow['doc_date'] as String) == isoDate &&
        oldRow['deleted_at'] == null) {
      return;
    }

    // بهای تمام‌شدهٔ اقلام: تطبیق با کاتالوگ + بهای میانگین موجودی
    final items = <Map<String, Object>>[];
    var cost = 0;
    for (final item in invoice.items) {
      final productId = productMatcher?.call(item.title.trim()) ?? '';
      var unitCost = 0;
      if (productId.isNotEmpty) {
        inventory.ensureProduct(productId);
        unitCost = inventory.avgCost(productId);
      }
      final itemCost = (item.quantity * unitCost).round();
      cost += itemCost;
      items.add({
        'product_id': productId,
        'title': item.title,
        'quantity': item.quantity,
        'unit': item.unit,
        'unit_price': Money.fromDouble(item.unitPrice),
        'total_price': Money.fromDouble(item.totalPrice),
        'unit_cost': unitCost,
      });
    }

    store.txn(() {
      // ۱) معکوس‌سازی نسخهٔ قبل (رویدادها + موجودی) اگر وجود دارد
      if (oldVersion > 0) {
        _reverseVersion(sourceId, oldVersion, isoDate);
      }

      // ۲) آینهٔ سند
      final id = oldRow?['id'] as String? ?? 'sdoc-$sourceId';
      store.db.execute(
        'INSERT INTO sales_documents (id, source_id, number, customer_id, customer_name, doc_type, doc_date, revenue, total, paid, remaining, shipping_charge, discount, cost, status, ledger_version, deleted_at, updated_at) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) '
        'ON CONFLICT(id) DO UPDATE SET number = excluded.number, customer_id = excluded.customer_id, customer_name = excluded.customer_name, doc_date = excluded.doc_date, revenue = excluded.revenue, total = excluded.total, paid = excluded.paid, remaining = excluded.remaining, shipping_charge = excluded.shipping_charge, discount = excluded.discount, cost = excluded.cost, status = excluded.status, ledger_version = excluded.ledger_version, deleted_at = excluded.deleted_at, updated_at = excluded.updated_at',
        [
          id,
          sourceId,
          invoice.number,
          invoice.customerId,
          invoice.customerName,
          'sale',
          isoDate,
          revenue,
          total,
          paid,
          remaining,
          Money.fromDouble(invoice.shippingFee),
          Money.fromDouble(invoice.discountAmount),
          cost,
          'active',
          nextVersion,
          null,
          DateTime.now().toIso8601String(),
        ],
      );

      // ۳) اقلام فروش برای گزارش سود کالا
      store.db.execute('DELETE FROM sale_items WHERE invoice_id = ?', [sourceId]);
      for (final item in items) {
        store.db.execute(
          'INSERT INTO sale_items (id, invoice_id, product_id, title, quantity, unit, unit_price, total_price, unit_cost, doc_date, ledger_version) '
          'VALUES (?,?,?,?,?,?,?,?,?,?,?)',
          [
            'sit-${newId()}',
            sourceId,
            item['product_id'] as String,
            item['title'] as String,
            item['quantity'] as double,
            item['unit'] as String,
            item['unit_price'] as int,
            item['total_price'] as int,
            item['unit_cost'] as int,
            isoDate,
            nextVersion,
          ],
        );
      }

      // ۴) خروج موجودی — فقط از طریق InventoryRepository
      for (final item in items) {
        final productId = item['product_id'] as String;
        final qty = item['quantity'] as double;
        if (productId.isNotEmpty && qty > 0) {
          inventory.deduct(
            productId,
            qty,
            movementType: StockMovementType.sale,
            date: isoDate,
            refType: 'sale',
            refId: sourceId,
            note: 'فاکتور ${invoice.number}',
            idempotencyKey: 'sale:$sourceId:v$nextVersion:item:$productId',
          );
        }
      }

      // ۵) رویدادهای مالی نسخهٔ جدید
      ledger.append(LedgerEntryInput(
        eventType: LedgerEventType.sale,
        date: isoDate,
        amount: revenue,
        customerId: invoice.customerId.isEmpty ? null : invoice.customerId,
        invoiceId: sourceId,
        reference: 'v$nextVersion',
        description: 'فروش فاکتور ${invoice.number} — ${invoice.customerName}',
        customerDelta: remaining,
        idempotencyKey: 'sale:$sourceId:v$nextVersion:sale',
      ));
      if (paid > 0) {
        ledger.append(LedgerEntryInput(
          eventType: LedgerEventType.paymentReceived,
          date: isoDate,
          amount: paid,
          direction: 1,
          accountId: defaultCashAccount,
          customerId: invoice.customerId.isEmpty ? null : invoice.customerId,
          invoiceId: sourceId,
          reference: 'v$nextVersion',
          description: 'دریافت نقدی فاکتور ${invoice.number}',
          idempotencyKey: 'sale:$sourceId:v$nextVersion:pay',
        ));
      }
    });
    audit.log(oldVersion == 0 ? 'INVOICE_SALE_CREATE' : 'INVOICE_SALE_EDIT',
        'invoice', sourceId, 'نسخهٔ مالی v$nextVersion — درآمد $revenue');
  }

  void _reverseVersion(String sourceId, int version, String date) {
    // معکوس‌سازی رویدادهای مالی نسخهٔ قدیمی
    final events = store.db.select(
      "SELECT id FROM ledger_events WHERE invoice_id = ? AND reference = ? AND reversal_of IS NULL",
      [sourceId, 'v$version'],
    );
    for (final e in events) {
      final eid = e['id'] as String;
      if (!ledger.isReversed(eid)) {
        ledger.reverse(eid, date: date, description: 'ویرایش فاکتور — معکوس نسخهٔ v$version');
      }
    }
    // بازگردانی موجودی نسخهٔ قدیمی (حرکت معکوس دقیق)
    final moves = store.db.select(
      "SELECT * FROM stock_movements WHERE idempotency_key LIKE 'sale:$sourceId:v$version:item:%' OR idempotency_key LIKE 'sale:$sourceId:v$version:rev:%'",
    );
    for (final m in moves) {
      final key = m['idempotency_key'] as String?;
      if (key == null || key.contains(':rev:')) continue;
      final productId = m['product_id'] as String;
      final qty = (m['quantity'] as num).toDouble(); // منفی (خروج فروش)
      if (qty < 0) {
        inventory.receive(
          productId,
          -qty,
          movementType: StockMovementType.saleReturn,
          unitCost: 0,
          date: date,
          refType: 'sale_edit_reversal',
          refId: sourceId,
          note: 'بازگردانی موجودی هنگام ویرایش فاکتور',
          idempotencyKey: 'sale:$sourceId:v$version:rev:$productId',
        );
      }
    }
  }

  /// حذف نرم فاکتور: اثر مالی معکوس + موجودی برمی‌گردد + سند «deleted» می‌ماند (§40)
  void onInvoiceDeleted(String sourceId) {
    final row = _docRow(sourceId);
    if (row == null) return;
    if (row['deleted_at'] != null) return;
    final version = row['ledger_version'] as int? ?? 0;
    final now = DateTime.now().toIso8601String();
    store.txn(() {
      if (version > 0) {
        _reverseVersion(sourceId, version, now.substring(0, 10));
      }
      store.db.execute(
        'UPDATE sales_documents SET status = ?, deleted_at = ?, updated_at = ? WHERE source_id = ?',
        ['deleted', now, now, sourceId],
      );
    });
    audit.log('INVOICE_SALE_DELETE', 'invoice', sourceId, 'حذف نرم — نسخهٔ v$version');
  }

  /// دریافت/تسویهٔ فاکتور (از دکمهٔ ثبت دریافت موجود) — idempotent با «مجموع پرداخت»
  void onInvoicePayment(String sourceId, double amountAdded) {
    final row = _docRow(sourceId);
    if (row == null) return;
    if (row['deleted_at'] != null) return;
    final amount = Money.fromDouble(amountAdded);
    if (amount <= 0) return;
    final paid = row['paid'] as int;
    final remaining = row['remaining'] as int;
    final newPaid = paid + amount;
    final newRemaining = remaining - amount < 0 ? 0 : remaining - amount;
    final customerId = row['customer_id'] as String? ?? '';
    store.txn(() {
      // کاهش بدهی مشتری (تا کف صفر)
      var delta = 0;
      if (customerId.isNotEmpty) {
        final r = ledger.sumField('customer_delta', 'v', customerId: customerId);
        delta = amount > r ? -r : -amount;
      }
      ledger.append(LedgerEntryInput(
        eventType: LedgerEventType.paymentReceived,
        date: _todayStr(),
        amount: amount,
        direction: 1,
        accountId: defaultCashAccount,
        customerId: customerId.isEmpty ? null : customerId,
        invoiceId: sourceId,
        paymentId: 'ipay-$sourceId-$newPaid',
        description: 'تسویه/دریافت فاکتور ${row['number']}',
        customerDelta: delta,
        idempotencyKey: 'salepay:$sourceId:$newPaid',
      ));
      store.db.execute(
        'UPDATE sales_documents SET paid = ?, remaining = ?, updated_at = ? WHERE source_id = ?',
        [newPaid, newRemaining, DateTime.now().toIso8601String(), sourceId],
      );
    });
    audit.log('INVOICE_PAYMENT', 'invoice', sourceId, '$amount تومان');
  }

  /// ماندهٔ مشتق مشتری از دفتر کل (§9) — تک‌منبع حقیقت
  int derivedCustomerBalance(String customerId) {
    if (customerId.isEmpty) return 0;
    final v = ledger.sumField('customer_delta', 'v', customerId: customerId);
    return v < 0 ? 0 : v;
  }

  int _clampMoney(num v) => v.round() < 0 ? 0 : v.round().toInt();

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }
}
