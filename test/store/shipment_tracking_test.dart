import 'package:flutter_test/flutter_test.dart';
import 'package:factor_ruby/store/core/ledger.dart';
import 'package:factor_ruby/store/orders/order_repository.dart';
import 'package:factor_ruby/store/shipments/shipment_repository.dart';
import 'package:factor_ruby/store/store_core.dart';

/// کدهای رهگیری ارسال — تست‌های جامع طبق مشخصات (بدون هیچ آدرسی)
void main() {
  late StoreCore core;

  setUp(() {
    core = StoreCore.inMemory();
  });

  String _order(String name,
      {String phone = '',
      String number = '',
      int price = 100_000,
      String date = '2026-01-05'}) {
    return core.orders.save(
      number: number,
      customerId: 'c-$name',
      customerName: name,
      customerPhone: phone,
      orderDate: date,
      items: [OrderItem(title: 'کالا', quantity: 1, unitPrice: price)],
    );
  }

  group('ساختار و جست‌وجو', () {
    test('هر سفارش ردیف جدا — حتی با مشتری مشترک؛ جست‌وجو با نام', () {
      _order('جاوید', number: '1024');
      _order('جاوید', number: '1058');
      _order('محمد', number: '1025');
      final rows = core.shipments.rows();
      expect(rows.length, 3);
      // جست‌وجوی «جاوید» → دو سفارش جدا
      final found = core.shipments.rows(search: 'جاوید');
      expect(found.length, 2);
      expect(found.every((r) => r.customerName == 'جاوید'), isTrue);
      // شمارهٔ فاکتور هر ردیف مشخص است
      expect(found.map((r) => r.orderNumber).toSet(), {'1024', '1058'});
    });

    test('ترتیب پیش‌فرض: اول بی‌کدها، بعد جدید‌ترین‌ها', () {
      final a = _order('الف'); // قدیمی‌تر
      _order('ب'); // جدیدتر بدون کد
      core.shipments.bulkSave([
        TrackingInput(
            orderId: a, trackingCode: '111', provider: 'پست', shippedAt: '1405/06/01'),
      ]);
      final rows = core.shipments.rows();
      expect(rows.first.customerName, 'ب'); // بی‌کد اول
      expect(rows.last.trackingCode, '111');
    });
  });

  group('ذخیرهٔ گروهی و صحت داده', () {
    test('۲۰ سفارش، ذخیرهٔ گروهی ۵تایی (ذخیرهٔ جزئی)؛ بقیه دست‌نخورده', () {
      final ids = [for (var i = 0; i < 20; i++) _order('مشتری $i', number: '${1000 + i}')];
      final items = [
        for (var i = 0; i < 5; i++)
          TrackingInput(
              orderId: ids[i],
              trackingCode: 'TRK-00$i',
              provider: ShipmentProviders.list[i % 4],
              shippedAt: '1405/06/02'),
      ];
      expect(core.shipments.bulkSave(items), 5);
      final rows = core.shipments.rows();
      final withCode = rows.where((r) => r.trackingCode.isNotEmpty).length;
      expect(withCode, 5);
      expect(rows.length, 20);
      // سفارش‌های دارای کد → SHIPPED و خارج از فهرست ارسال‌نشده
      expect(core.orders.pendingCount(), 15);
      expect(core.orders.byId(ids.first)!.status, 'SHIPPED');
      expect(core.orders.byId(ids.last)!.status, 'PENDING');
    });

    test('کد رهگیری String — صفر ابتدایی، حروف و خط تیره عیناً حفظ می‌شوند', () {
      final a = _order('الف', number: '1');
      core.shipments.bulkSave([
        TrackingInput(orderId: a, trackingCode: ' 00123456789 ', provider: 'پست', shippedAt: '1405/06/02'),
      ]);
      expect(core.shipments.rows()[0].trackingCode, '00123456789');
      // به‌روزرسانی با TP و AB
      core.shipments.bulkSave([
        TrackingInput(orderId: a, trackingCode: 'TP987654321', provider: 'تیپاکس', shippedAt: '1405/06/03'),
      ]);
      expect(core.shipments.rows()[0].trackingCode, 'TP987654321');
      core.shipments.bulkSave([
        TrackingInput(orderId: a, trackingCode: 'AB-00123456', provider: 'پیک', shippedAt: '1405/06/04'),
      ]);
      final row = core.shipments.rows()[0];
      expect(row.trackingCode, 'AB-00123456');
      expect(row.provider, 'پیک');
      expect(row.shippedAt, '1405/06/04');
    });

    test('به‌روزرسانی = تغییر همان رکورد، نه رکورد تکراری', () {
      final a = _order('الف');
      core.shipments.bulkSave([
        TrackingInput(orderId: a, trackingCode: 'X1', provider: 'پست', shippedAt: '1405/06/01'),
      ]);
      core.shipments.bulkSave([
        TrackingInput(orderId: a, trackingCode: 'X2', provider: 'پست', shippedAt: '1405/06/02'),
      ]);
      final cnt = core.db.db.select('SELECT COUNT(*) AS c FROM shipments').first;
      expect(cnt['c'], 1); // نه تکرار
      expect(core.shipments.rows()[0].trackingCode, 'X2');
      // ذخیرهٔ مکرر همان داده هم تکرار نمی‌سازد
      core.shipments.bulkSave([
        TrackingInput(orderId: a, trackingCode: 'X2', provider: 'پست', shippedAt: '1405/06/02'),
      ]);
      expect(core.db.db.select('SELECT COUNT(*) AS c FROM shipments').first['c'], 1);
    });

    test('ردیف نامعتبر → هیچ چیز نوشته نمی‌شود (رفع کامل نه جزئی)', () {
      final a = _order('معتبر', number: '1');
      final b = _order('نامعتبر', number: '2');
      final items = [
        TrackingInput(orderId: a, trackingCode: 'OK-1', provider: 'پست', shippedAt: '1405/06/01'),
        TrackingInput(orderId: b, trackingCode: '', provider: 'پست', shippedAt: '1405/06/01'), // کد خالی
      ];
      // اعتبارسنجی جداگانه
      final errors = core.shipments.validate(items);
      expect(errors.length, 1);
      expect(errors[b], 'کد رهگیری الزامی است');
      // ذخیرهٔ گروهی رد می‌شود
      expect(() => core.shipments.bulkSave(items), throwsArgumentError);
      // هیچ رکوردی نوشته نشده
      expect(core.db.db.select('SELECT COUNT(*) AS c FROM shipments').first['c'], 0);
      expect(core.orders.pendingCount(), 2);
      // سپس اصلاح و ذخیرهٔ کامل
      items[1] = TrackingInput(orderId: b, trackingCode: 'OK-2', provider: 'تیپاکس', shippedAt: '1405/06/01');
      expect(core.shipments.bulkSave(items), 2);
    });

    test('عدم دست‌خوردگی مالی/موجودی/دادهٔ سفارش', () {
      final a = _order('الف', number: '9', price: 500_000, phone: '09121112233');
      final eventsBefore =
          core.db.db.select('SELECT COUNT(*) AS c FROM ledger_events').first['c'];
      final movesBefore =
          core.db.db.select('SELECT COUNT(*) AS c FROM stock_movements').first['c'];
      core.shipments.bulkSave([
        TrackingInput(orderId: a, trackingCode: '99Z', provider: 'سایر', shippedAt: '1405/06/05'),
      ]);
      expect(
          core.db.db.select('SELECT COUNT(*) AS c FROM ledger_events').first['c'],
          eventsBefore); // هیچ رویداد مالی جدید
      expect(
          core.db.db.select('SELECT COUNT(*) AS c FROM stock_movements').first['c'],
          movesBefore); // موجودی تغییر نکرد
      final o = core.orders.byId(a)!;
      expect(o.total, 500_000); // مبلغ سفارش دست‌نخورده
      expect(o.items.length, 1);
      expect(o.customerName, 'الف');
      expect(o.customerPhone, '09121112233');
    });
  });

  group('فیلتر و وضعیت', () {
    test('فیلترها: همه / ارسال‌نشده / بی‌کد / ارسال‌شده + وضعیت مشتق', () {
      final a = _order('با-کد', number: '1');
      final b = _order('ارسال-شده-بی-کد', number: '2');
      _order('ناموجود-کد', number: '3');
      core.shipments.bulkSave([
        TrackingInput(orderId: a, trackingCode: 'T1', provider: 'پست', shippedAt: '1405/06/01'),
      ]);
      // b: ارسال علامت خورده بدون کد (وضعیت قدیمی)
      core.orders.markShipped(b);
      expect(core.shipments.rows().length, 3);
      expect(core.shipments.rows(filter: ShipmentFilter.shipped).length, 1);
      expect(core.shipments.rows(filter: ShipmentFilter.pending).length, 1);
      expect(core.shipments.rows(filter: ShipmentFilter.noCode).length, 2); // b + سوم
      final rowA = core.shipments.rows(search: 'با-کد')[0];
      expect(rowA.derivedStatus, 'shipped');
      expect(rowA.derivedStatusLabel, 'ارسال شده');
      final rowB = core.shipments.rows(search: 'ارسال-شده-بی-کد')[0];
      expect(rowB.derivedStatus, 'no_code');
      expect(rowB.derivedStatusLabel, 'کد رهگیری ثبت نشده');
    });
  });

  group('پیام کد رهگیری', () {
    test('پیام پست — پویا از دادهٔ واقعی', () {
      final a = _order('جاوید', number: '1024', phone: '09120000000');
      core.shipments.bulkSave([
        TrackingInput(orderId: a, trackingCode: '123456789012345', provider: 'پست', shippedAt: '1405/06/02'),
      ]);
      final msg = core.shipments.generateMessage(core.shipments.rows()[0]);
      expect(msg,
          'جاوید عزیز،\nسفارش شما تحویل پست شد.\nکد رهگیری: 123456789012345');
    });

    test('پیام تیپاکس — با کد حرفی-عددی', () {
      final a = _order('جاوید', number: '1025');
      core.shipments.bulkSave([
        TrackingInput(orderId: a, trackingCode: 'TP987654321', provider: 'تیپاکس', shippedAt: '1405/06/02'),
      ]);
      final msg = core.shipments.generateMessage(core.shipments.rows()[0]);
      expect(msg, 'جاوید عزیز،\nسفارش شما تحویل تیپاکس شد.\nکد رهگیری: TP987654321');
    });

    test('مشتری بدون شماره — hasPhone=false (UI پیام می‌دهد، کرش نمی‌کند)', () {
      final a = _order('بی‌شماره');
      core.shipments.bulkSave([
        TrackingInput(orderId: a, trackingCode: '55', provider: 'پیک', shippedAt: '1405/06/01'),
      ]);
      final row = core.shipments.rows()[0];
      expect(row.hasPhone, isFalse);
      expect(core.shipments.generateMessage(row), contains('بی‌شماره عزیز'));
    });
  });

  test('rollback تراکنشی: خطای دیتابیس وسط عملیات → دادهٔ ناقص نمی‌ماند', () {
    final a = _order('الف');
    // شبیه‌سازی خطا: order_id ناموجود باعث خطای کلید خارجی نمی‌شود (بدون FK)
    // پس به‌جایش خطای سطح دیتابیس با جدول قفل‌شده تست می‌شود؛ اینجا رفتار
    // تراکنش را مستقیم می‌آزماییم: داخل txn یک خطا → rollback کامل
    try {
      core.db.txn(() {
        core.db.db.execute(
            "INSERT INTO shipments (id, order_id, tracking_code, provider, shipped_at, created_at, updated_at) "
            "VALUES ('x1', '$a', 'BAD', 'پست', '1405/06/01', 't', 't')");
        // خطای عمدی → کل تراکنش باید rollback شود
        throw StateError('شبیه‌سازی خطای دیتابیس');
      });
    } on StateError {
      // انتظار: سطر INSERTشده هم برگردد
    }
    final cnt = core.db.db
        .select("SELECT COUNT(*) AS c FROM shipments WHERE id = 'x1'")
        .first['c'];
    expect(cnt, 0); // rollback کار کرد
  });

  test('پس از ثبت کد رهگیری، سفارش از «ارسال‌نشده» خارج و دادهٔ فاکتور سالم می‌ماند', () {
    final a = _order('جاوید', number: '1024', price: 2_000_000);
    core.shipments.bulkSave([
      TrackingInput(orderId: a, trackingCode: 'RR123', provider: 'پست', shippedAt: '1405/06/02'),
    ]);
    expect(core.orders.pendingCount(), 0);
    expect(core.orders.list(status: 'PENDING').length, 0);
    final o = core.orders.byId(a)!;
    expect(o.status, 'SHIPPED');
    expect(o.sentDate, '1405/06/02');
    expect(o.total, 2_000_000);
    // رهگیری دوباره خوانده می‌شود (نمایش خودکار در هرجای برنامه)
    expect(core.shipments.rows(search: 'جاوید')[0].trackingCode, 'RR123');
  });
}
