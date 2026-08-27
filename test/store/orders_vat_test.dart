import 'package:flutter_test/flutter_test.dart';
import 'package:factor_ruby/models/invoice_model.dart';
import 'package:factor_ruby/store/cheques/cheque_repository.dart';
import 'package:factor_ruby/store/core/ledger.dart';
import 'package:factor_ruby/store/orders/order_repository.dart';
import 'package:factor_ruby/store/store_core.dart';
import 'package:factor_ruby/store/suppliers/purchase_repository.dart';

/// قابلیت‌های جدید: سفارشات، مالیات ارزش افزوده، پنجرهٔ یادآور چک پرداختی
void main() {
  late StoreCore core;

  setUp(() {
    core = StoreCore.inMemory();
  });

  group('سفارشات (نسخهٔ ۵)', () {
    test('ثبت سفارش → ارسال‌نشده؛ ارسال → خارج از فهرست؛ ویرایش کامل', () {
      final id = core.orders.save(
        customerId: 'c1',
        customerName: 'مشتری تست',
        customerPhone: '09120000000',
        address: 'تهران، خیابان اصلی',
        orderDate: '2026-01-05',
        items: const [
          OrderItem(title: 'کالای A', quantity: 2, unitPrice: 500_000),
          OrderItem(title: 'کالای B', quantity: 1, unitPrice: 1_000_000),
        ],
        discount: 100_000,
        shipping: 50_000,
      );
      // جمع: 2M − 100هزار + 50هزار = 1_950_000
      expect(core.orders.pendingCount(), 1);
      final o = core.orders.byId(id)!;
      expect(o.total, 1_950_000);
      expect(o.subtotal, 2_000_000);
      expect(o.isPending, isTrue);
      expect(o.customerPhone, '09120000000');

      // ویرایش: تغییر تعداد
      core.orders.save(
        id: id,
        customerId: 'c1',
        customerName: 'مشتری تست',
        customerPhone: '09120000000',
        orderDate: '2026-01-05',
        items: const [OrderItem(title: 'کالای A', quantity: 5, unitPrice: 500_000)],
      );
      expect(core.orders.byId(id)!.total, 2_500_000);
      expect(core.orders.byId(id)!.items.length, 1);

      // ارسال
      core.orders.markShipped(id, date: '2026-01-07');
      expect(core.orders.pendingCount(), 0);
      expect(core.orders.byId(id)!.status, 'SHIPPED');
      expect(core.orders.byId(id)!.sentDate, '2026-01-07');
      final pendingList = core.orders.list(status: 'PENDING');
      expect(pendingList.length, 0);
    });

    test('اعتبارسنجی: نام مشتری و حداقل یک قلم الزامی', () {
      expect(
        () => core.orders.save(
            customerId: '', customerName: ' ', orderDate: '2026-01-01', items: const []),
        throwsArgumentError,
      );
      expect(
        () => core.orders.save(
            customerId: 'c',
            customerName: 'مشتری',
            orderDate: '2026-01-01',
            items: const []),
        throwsArgumentError,
      );
    });

    test('لغو سفارش و فهرست همه', () {
      final id = core.orders.save(
        customerId: 'c1',
        customerName: 'الف',
        orderDate: '2026-01-01',
        items: const [OrderItem(title: 'X', quantity: 1, unitPrice: 100)],
      );
      core.orders.markCancelled(id);
      expect(core.orders.pendingCount(), 0);
      expect(core.orders.list().length, 1); // در «همه» می‌ماند
      expect(core.orders.list()[0].status, 'CANCELLED');
    });
  });

  group('مالیات بر ارزش افزوده (فاکتور فروش)', () {
    InvoiceModel _sale({double taxPercent = 0, double paid = 0}) {
      final base = 1_000_000.0;
      final inv = InvoiceModel(
        id: 'v1',
        number: '1',
        customerId: 'c1',
        customerName: 'م',
        customerPhone: '',
        type: 'sale',
        paymentType: paid >= base ? 'cash' : 'non_cash',
        status: 'unpaid',
        date: '1404/10/12',
        items: const [],
        subtotal: base,
        discountPercent: 0,
        discountAmount: 0,
        shippingFee: 0,
        taxPercent: taxPercent,
        previousDebt: 0,
        deposit: 0,
        totalAmount: base,
        paidAmount: paid,
        remainingAmount: base - paid,
        notes: '',
        cardNumber: '',
        createdAt: '',
      );
      return inv;
    }

    test('مبلغ مالیات = ۱۰٪ پایه و در درآمد دفتر کل محاسبه می‌شود', () {
      final inv = _sale(taxPercent: 10); // ۱م → مالیات ۱۰۰هزار
      expect(inv.taxAmount, 100_000);
      core.bridge.onInvoiceSaved(inv);
      final doc = core.db.db.select('SELECT * FROM sales_documents').first;
      expect(doc['revenue'], 1_100_000); // درآمد شامل مالیات
    });

    test('بدون تیک مالیات، درآمد همان پایه است', () {
      core.bridge.onInvoiceSaved(_sale(taxPercent: 0));
      final doc = core.db.db.select('SELECT * FROM sales_documents').first;
      expect(doc['revenue'], 1_000_000);
    });

    test('مالیات بعد از تخفیف محاسبه می‌شود', () {
      final inv = InvoiceModel(
        id: 'v2',
        number: '2',
        customerId: 'c1',
        customerName: 'م',
        customerPhone: '',
        type: 'sale',
        paymentType: 'non_cash',
        status: 'unpaid',
        date: '1404/10/12',
        items: const [],
        subtotal: 1_000_000,
        discountPercent: 0,
        discountAmount: 200_000,
        shippingFee: 0,
        taxPercent: 10,
        previousDebt: 0,
        deposit: 0,
        totalAmount: 880_000,
        paidAmount: 0,
        remainingAmount: 880_000,
        notes: '',
        cardNumber: '',
        createdAt: '',
      );
      expect(inv.taxAmount, 80_000); // ۱۰٪ × (۱م − ۲۰۰هزار)
    });
  });

  group('پنجرهٔ یادآور چک پرداختی (۷ روز قبل تا سررسید)', () {
    test('فقط چک‌های خود کاربر در بازهٔ [-7, 0] نسبت به سررسید — نه بعد و نه قبل‌تر', () {
      final supplierId = core.suppliers.save(name: 'ت');
      // برای کاهش بدهی تأمین‌کننده لازم است بدهی موجود باشد
      core.purchases.create(
        supplierId: supplierId,
        date: '2026-01-01',
        items: const [
          PurchaseItemInput(productId: 'p1', title: 'ک', quantity: 5, unitPrice: 1_000_000),
        ],
      );
      // چک پرداختی با سررسید ۱۰ فوریه
      core.cheques.issueCheque(
        supplierId: supplierId,
        supplierName: 'ت',
        amount: 1_000_000,
        chequeNumber: 'A1',
        dueDate: '2026-02-10',
      );
      // چک پرداختی سررسید ۱ مارس (دور)
      core.purchases.create(
        supplierId: supplierId,
        date: '2026-01-02',
        items: const [
          PurchaseItemInput(productId: 'p1', title: 'ک', quantity: 1, unitPrice: 500_000),
        ],
      );
      core.cheques.issueCheque(
        supplierId: supplierId,
        supplierName: 'ت',
        amount: 500_000,
        chequeNumber: 'A2',
        dueDate: '2026-03-01',
      );

      // ۲ فوریه (۸ روز قبل): هیچ‌کدام
      expect(core.cheques.upcomingIssued('2026-02-02').length, 0);
      // ۳ فوریه (۷ روز قبل): A1
      var up = core.cheques.upcomingIssued('2026-02-03');
      expect(up.length, 1);
      expect(up.first.chequeNumber, 'A1');
      // روز سررسید ۱۰ فوریه: هنوز A1
      expect(core.cheques.upcomingIssued('2026-02-10').length, 1);
      // ۱۱ فوریه (یک روز بعد سررسید): دیگر یادآوری نیست
      expect(core.cheques.upcomingIssued('2026-02-11').length, 0);
      // ۲۲ فوریه: A2 وارد پنجره می‌شود
      expect(core.cheques.upcomingIssued('2026-02-22').length, 1);
    });

    test('مبلغ چک‌های صادره جزو پرداختی‌های داشبورد است', () {
      final supplierId = core.suppliers.save(name: 'ت');
      core.purchases.create(
        supplierId: supplierId,
        date: '2026-01-01',
        items: const [
          PurchaseItemInput(productId: 'p1', title: 'ک', quantity: 2, unitPrice: 1_000_000),
        ],
      );
      core.cheques.issueCheque(
        supplierId: supplierId,
        supplierName: 'ت',
        amount: 2_000_000,
        chequeNumber: 'B1',
        dueDate: '2026-02-10',
      );
      // بدهی تأمین‌کننده با چک صفر شد؛ ولی پرداختی (تعهد چک) = ۲م
      expect(core.suppliers.payable(supplierId), 0);
      expect(core.cheques.outstandingIssuedAmount(), 2_000_000);
      final d = core.reports.dashboard('2026-01-01');
      expect(d.payables, 2_000_000);
      final totals = core.reports.forecastTotals();
      expect(totals['expectedOutgoing'], 2_000_000);
    });

    test('پرسش «پاس شد؟» فقط برای چک‌های دریافتی است، نه پرداختی', () {
      // چک پرداختیِ سررسیدشده — در dueForConfirmation نیست
      final supplierId = core.suppliers.save(name: 'ت');
      core.purchases.create(
        supplierId: supplierId,
        date: '2026-01-01',
        items: const [
          PurchaseItemInput(productId: 'p1', title: 'ک', quantity: 1, unitPrice: 300_000),
        ],
      );
      core.cheques.issueCheque(
        supplierId: supplierId,
        supplierName: 'ت',
        amount: 300_000,
        chequeNumber: 'C1',
        dueDate: '2026-01-15',
      );
      expect(core.cheques.dueForConfirmation('2026-01-20').length, 0);

      // چک دریافتیِ سررسیدشده — پرسیده می‌شود
      core.ledger.append(LedgerEntryInput(
        eventType: 'SALE',
        date: '2026-01-01',
        amount: 500_000,
        customerId: 'c1',
        customerDelta: 500_000,
      ));
      core.cheques.receiveCheque(
        customerId: 'c1',
        customerName: 'م',
        amount: 500_000,
        chequeNumber: 'D1',
        dueDate: '2026-01-18',
      );
      expect(core.cheques.dueForConfirmation('2026-01-20').length, 1);
      expect(ChequeStatus.held, 'HELD');
    });
  });
}
