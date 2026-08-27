import 'dart:convert';

import '../core/accounts.dart';
import '../core/audit.dart';
import '../db/store_database.dart';

class OrderItem {
  final String title;
  final double quantity;
  final String unit;
  final int unitPrice;

  const OrderItem({
    required this.title,
    this.quantity = 1,
    this.unit = 'عدد',
    this.unitPrice = 0,
  });

  int get total => (quantity * unitPrice).round();

  Map<String, dynamic> toJson() =>
      {'title': title, 'quantity': quantity, 'unit': unit, 'unitPrice': unitPrice};

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        title: (j['title'] ?? '') as String,
        quantity: ((j['quantity'] ?? 1) as num).toDouble(),
        unit: (j['unit'] ?? 'عدد') as String,
        unitPrice: ((j['unitPrice'] ?? 0) as num).round(),
      );
}

class OrderEntity {
  final String id;
  final String number;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String address;
  final String orderDate;
  final List<OrderItem> items;
  final int subtotal;
  final int discount;
  final int shipping;
  final int total;
  final String status; // PENDING | SHIPPED | CANCELLED
  final String? sentDate;
  final String notes;
  final String createdAt;
  final String updatedAt;

  const OrderEntity({
    required this.id,
    this.number = '',
    this.customerId = '',
    required this.customerName,
    this.customerPhone = '',
    this.address = '',
    required this.orderDate,
    this.items = const [],
    this.subtotal = 0,
    this.discount = 0,
    this.shipping = 0,
    this.total = 0,
    this.status = 'PENDING',
    this.sentDate,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == 'PENDING';
  String get statusLabel {
    switch (status) {
      case 'SHIPPED':
        return 'ارسال شد';
      case 'CANCELLED':
        return 'لغو شد';
      default:
        return 'ارسال نشده';
    }
  }
}

/// سفارشات — ثبت سفارش، مشاهدهٔ کامل، ویرایش، علامت‌گذاری ارسال
class OrderRepository {
  final StoreDatabase store;
  final AuditLog audit;
  OrderRepository(this.store, this.audit);

  OrderEntity? byId(String id) {
    final rows = store.db.select('SELECT * FROM orders WHERE id = ?', [id]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  OrderEntity _fromRow(Map<String, Object?> r) => OrderEntity(
        id: r['id'] as String,
        number: (r['number'] ?? '') as String,
        customerId: (r['customer_id'] ?? '') as String,
        customerName: r['customer_name'] as String,
        customerPhone: (r['customer_phone'] ?? '') as String,
        address: (r['address'] ?? '') as String,
        orderDate: r['order_date'] as String,
        items: (jsonDecode((r['items_json'] ?? '[]') as String) as List)
            .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        subtotal: r['subtotal'] as int,
        discount: r['discount'] as int,
        shipping: r['shipping'] as int,
        total: r['total'] as int,
        status: r['status'] as String,
        sentDate: r['sent_date'] as String?,
        notes: (r['notes'] ?? '') as String,
        createdAt: r['created_at'] as String,
        updatedAt: r['updated_at'] as String,
      );

  /// ثبت/ویرایش سفارش (idempotent با id)
  String save({
    String? id,
    String number = '',
    required String customerId,
    required String customerName,
    String customerPhone = '',
    String address = '',
    required String orderDate,
    required List<OrderItem> items,
    int discount = 0,
    int shipping = 0,
    String notes = '',
    String status = 'PENDING',
  }) {
    if (customerName.trim().isEmpty) {
      throw ArgumentError('نام مشتری الزامی است');
    }
    if (items.isEmpty) {
      throw ArgumentError('سفارش باید حداقل یک قلم داشته باشد');
    }
    final oid = id ?? 'ord-${newId()}';
    final subtotal = items.fold(0, (s, i) => s + i.total);
    final total = subtotal - discount + shipping;
    final now = DateTime.now().toIso8601String();
    store.db.execute(
      'INSERT INTO orders (id, number, customer_id, customer_name, customer_phone, address, order_date, items_json, subtotal, discount, shipping, total, status, notes, created_at, updated_at) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) '
      'ON CONFLICT(id) DO UPDATE SET number = excluded.number, customer_id = excluded.customer_id, '
      'customer_name = excluded.customer_name, customer_phone = excluded.customer_phone, address = excluded.address, '
      'order_date = excluded.order_date, items_json = excluded.items_json, subtotal = excluded.subtotal, '
      'discount = excluded.discount, shipping = excluded.shipping, total = excluded.total, '
      'status = excluded.status, notes = excluded.notes, updated_at = excluded.updated_at',
      [
        oid,
        number,
        customerId,
        customerName.trim(),
        customerPhone.trim(),
        address.trim(),
        orderDate,
        jsonEncode(items.map((i) => i.toJson()).toList()),
        subtotal,
        discount,
        shipping,
        total,
        status,
        notes,
        now,
        now,
      ],
    );
    audit.log(id == null ? 'ORDER_CREATE' : 'ORDER_UPDATE', 'order', oid,
        '$customerName — $total تومان — ${items.length} قلم');
    return oid;
  }

  List<OrderEntity> list({String? status, String? search}) {
    final where = <String>['1=1'];
    final args = <Object?>[];
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('(customer_name LIKE ? OR customer_phone LIKE ? OR number LIKE ?)');
      args.addAll(['%$search%', '%$search%', '%$search%']);
    }
    return store.db
        .select(
            'SELECT * FROM orders WHERE ${where.join(' AND ')} ORDER BY created_at DESC',
            args)
        .map(_fromRow)
        .toList();
  }

  /// علامت‌گذاری «ارسال شد» — تاریخ ثبت می‌شود
  void markShipped(String id, {String? date}) {
    final d = date ?? DateTime.now().toIso8601String().substring(0, 10);
    store.db.execute(
        'UPDATE orders SET status = ?, sent_date = ?, updated_at = ? WHERE id = ?',
        ['SHIPPED', d, DateTime.now().toIso8601String(), id]);
    audit.log('ORDER_SHIPPED', 'order', id, 'ارسال در $d');
  }

  void markCancelled(String id) {
    store.db.execute(
        'UPDATE orders SET status = ?, updated_at = ? WHERE id = ?',
        ['CANCELLED', DateTime.now().toIso8601String(), id]);
    audit.log('ORDER_CANCELLED', 'order', id, '');
  }

  int pendingCount() {
    final row = store.db
        .select("SELECT COUNT(*) AS c FROM orders WHERE status = 'PENDING'")
        .first;
    return row['c'] as int;
  }
}
