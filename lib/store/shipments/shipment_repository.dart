import '../core/accounts.dart';
import '../core/audit.dart';
import '../db/store_database.dart';

/// روش‌های ارسال — مرجع مشترک کل برنامه (بدون دیتابیس تکراری)
class ShipmentProviders {
  static const list = ['پست', 'تیپاکس', 'پیک', 'سایر'];
}

/// ورودی رهگیری برای ذخیرهٔ گروهی
class TrackingInput {
  final String orderId;
  final String trackingCode; // String — صفرهای ابتدایی/حروف/خط تیره عیناً حفظ می‌شود
  final String provider;
  final String shippedAt; // تاریخ ارسال جلالی رشته‌ای (لایهٔ UI)

  const TrackingInput({
    required this.orderId,
    required this.trackingCode,
    required this.provider,
    required this.shippedAt,
  });
}

/// وضعیت‌های نمایشی رهگیری — همیشه از دادهٔ واقعی مشتق می‌شود
class ShipmentFilter {
  static const all = 'all';
  static const pending = 'pending'; // ارسال نشده
  static const noCode = 'no_code'; // کد رهگیری ثبت نشده
  static const shipped = 'shipped'; // ارسال شده

  static const labels = {
    all: 'همه',
    pending: 'ارسال نشده',
    noCode: 'کد رهگیری ثبت نشده',
    shipped: 'ارسال شده',
  };
}

class ShipmentRow {
  final String orderId;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String orderDate;
  final String orderStatus;
  final String trackingCode;
  final String provider;
  final String shippedAt;

  const ShipmentRow({
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.orderDate,
    required this.orderStatus,
    required this.trackingCode,
    required this.provider,
    required this.shippedAt,
  });

  /// وضعیت مشتق‌شده از دادهٔ واقعی
  String get derivedStatus {
    if (trackingCode.trim().isNotEmpty) return 'shipped';
    if (orderStatus == 'SHIPPED') return 'no_code';
    return 'pending';
  }

  String get derivedStatusLabel {
    switch (derivedStatus) {
      case 'shipped':
        return 'ارسال شده';
      case 'no_code':
        return 'کد رهگیری ثبت نشده';
      default:
        return 'ارسال نشده';
    }
  }

  bool get hasPhone => customerPhone.trim().isNotEmpty;
}

/// رهگیری ارسال — همیشه بر اساس «سفارش» (نه مشتری)؛ بدون ذخیرهٔ آدرس؛
/// ثبت کد رهگیری هیچ رویداد مالی/موجودی نمی‌سازد.
class ShipmentRepository {
  final StoreDatabase store;
  final AuditLog audit;
  ShipmentRepository(this.store, this.audit);

  /// سفارش‌ها + رهگیری موجود — جست‌وجو و فیلتر در سطح دیتابیس
  /// ترتیب پیش‌فرض: اول نیازمندندِ رهگیری، بعد جدید‌ترین‌ها
  List<ShipmentRow> rows({String? search, String filter = ShipmentFilter.all}) {
    final where = <String>["o.status != 'CANCELLED'"];
    final args = <Object?>[];
    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim()}%';
      where.add('(o.customer_name LIKE ? OR o.customer_phone LIKE ? OR o.number LIKE ?)');
      args.addAll([q, q, q]);
    }
    switch (filter) {
      case ShipmentFilter.pending:
        where.add(
            "(o.status = 'PENDING' AND (s.tracking_code IS NULL OR s.tracking_code = ''))");
        break;
      case ShipmentFilter.noCode:
        where.add("(s.tracking_code IS NULL OR s.tracking_code = '')");
        break;
      case ShipmentFilter.shipped:
        where.add("(s.tracking_code IS NOT NULL AND s.tracking_code != '')");
        break;
      default:
        break;
    }
    return store.db
        .select(
          'SELECT o.id AS order_id, o.number AS order_number, o.customer_name, '
          'o.customer_phone, o.order_date, o.status AS order_status, '
          "COALESCE(s.tracking_code, '') AS tracking_code, "
          "COALESCE(s.provider, '') AS provider, "
          "COALESCE(s.shipped_at, '') AS shipped_at "
          'FROM orders o LEFT JOIN shipments s ON s.order_id = o.id '
          'WHERE ${where.join(' AND ')} '
          "ORDER BY CASE WHEN (s.tracking_code IS NULL OR s.tracking_code = '') THEN 0 ELSE 1 END, "
          'o.created_at DESC '
          'LIMIT 500',
          args,
        )
        .map((r) => ShipmentRow(
              orderId: r['order_id'] as String,
              orderNumber: (r['order_number'] ?? '') as String,
              customerName: r['customer_name'] as String,
              customerPhone: (r['customer_phone'] ?? '') as String,
              orderDate: r['order_date'] as String,
              orderStatus: r['order_status'] as String,
              trackingCode: r['tracking_code'] as String,
              provider: r['provider'] as String,
              shippedAt: r['shipped_at'] as String,
            ))
        .toList();
  }

  /// اعتبارسنجی ورودی‌های «تغییریافته» — بدون نوشتن چیزی در دیتابیس
  /// خروجی: نگاشت orderId → پیام خطای فارسی (خالی یعنی معتبر)
  Map<String, String> validate(List<TrackingInput> items) {
    final errors = <String, String>{};
    for (final it in items) {
      if (it.trackingCode.trim().isEmpty) {
        errors[it.orderId] = 'کد رهگیری الزامی است';
      } else if (it.provider.trim().isEmpty) {
        errors[it.orderId] = 'روش ارسال الزامی است';
      } else if (it.shippedAt.trim().isEmpty) {
        errors[it.orderId] = 'تاریخ ارسال الزامی است';
      }
    }
    return errors;
  }

  /// ذخیرهٔ گروهیِ تراکنشی — اول اعتبارسنجی کامل؛ اگر هر ردیف تغییریافته‌ای
  /// نامعتبر بود، هیچ چیزی نوشته نمی‌شود (رفع کل، نه ذخیرهٔ ناقص).
  /// ردیف‌های دست‌نخورده هرگز تغییر نمی‌کنند.
  /// ثبت رهگیری: به‌روزرسانی عملیاتیِ سفارش است — نه رویداد مالی/موجودی.
  int bulkSave(List<TrackingInput> items) {
    if (items.isEmpty) return 0;
    final errors = validate(items);
    if (errors.isNotEmpty) {
      throw ArgumentError(
          'ردیف‌های نامعتبر: ${errors.length} مورد — ابتدا اصلاح کنید');
    }
    var saved = 0;
    store.txn(() {
      final now = DateTime.now().toIso8601String();
      for (final it in items) {
        // فقط رشته‌های کناری trim می‌شوند؛ کاراکترهای داخلی کد عیناً حفظ می‌شوند
        final code = it.trackingCode.trim();
        final provider = it.provider.trim();
        final shippedAt = it.shippedAt.trim();
        final existing = store.db.select(
            'SELECT id FROM shipments WHERE order_id = ?', [it.orderId]);
        if (existing.isEmpty) {
          store.db.execute(
            'INSERT INTO shipments (id, order_id, tracking_code, provider, shipped_at, created_at, updated_at) '
            'VALUES (?,?,?,?,?,?,?)',
            ['shm-${newId()}', it.orderId, code, provider, shippedAt, now, now],
          );
        } else {
          store.db.execute(
            'UPDATE shipments SET tracking_code = ?, provider = ?, shipped_at = ?, updated_at = ? '
            'WHERE order_id = ?',
            [code, provider, shippedAt, now, it.orderId],
          );
        }
        // سفارش ↔ ارسال‌شده (از فهرست ارسال‌نشده‌ها خارج می‌شود)
        store.db.execute(
          "UPDATE orders SET status = 'SHIPPED', sent_date = ?, updated_at = ? WHERE id = ? AND status != 'CANCELLED'",
          [shippedAt, now, it.orderId],
        );
        saved++;
      }
    });
    audit.log('SHIPMENT_BULK_SAVE', 'shipment', '-',
        'ذخیرهٔ رهگیری $saved سفارش (تراکنشی)');
    return saved;
  }

  /// پیام کد رهگیری — پویا از دادهٔ واقعی سفارش/مشتری/رهگیری
  String generateMessage(ShipmentRow row) {
    return '${row.customerName} عزیز،\n'
        'سفارش شما تحویل ${row.provider} شد.\n'
        'کد رهگیری: ${row.trackingCode}';
  }
}
