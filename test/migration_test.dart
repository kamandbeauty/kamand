import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:factor_ruby/core/migration/app_migration.dart';
import 'package:factor_ruby/core/utils/prefs_store.dart';

/// این تست‌ها دقیقاً همان مسیری را می‌سنجند که کاربران فعلی اپلیکیشن روبی
/// با نصب نسخه‌ی تازه روی آن قرار می‌گیرند: داده‌ی نسخه‌ی ۱.۰.۴ در
/// SharedPreferences وجود دارد (بدون فیلدهای تازه) و نسخه‌ی جدید باید آن را
/// کامل کند، بدون حذف هیچ رکوردی و بدون دو بار حساب کردن مبلغ‌ها.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// داده‌ی ذخیره‌شده‌ی نسخه‌ی قدیمی (۱.۰.۴) — بدون هیچ‌کدام از فیلدهای جدید.
  Map<String, Object> legacyPrefs() => <String, Object>{
        PrefsStore.kUser: jsonEncode(<String, dynamic>{
          'id': 'u1',
          'name': 'جاوید',
          'phone': '09120000000',
          'country': 'ایران',
          'province': 'تهران',
          'city': 'تهران',
          'usageType': 'store',
          'isOnboarded': true,
        }),
        PrefsStore.kBusiness: jsonEncode(<String, dynamic>{
          'id': 'b1',
          'shopName': 'فروشگاه روبی',
          'phone': '02100000000',
          'address': 'تهران',
          'taxId': '',
          'logoPath': '',
          'bankCards': <String>[],
        }),
        PrefsStore.kSettings: jsonEncode(<String, dynamic>{
          'startingInvoiceNum': 1001,
          'templateStyle': 'modern',
          'showLogo': true,
          'showCardNum': true,
          'themeMode': 'light',
        }),
        PrefsStore.kProducts: jsonEncode(<String, dynamic>[
          <String, dynamic>{
            'id': 'p1',
            'code': '100',
            'name': 'شامپو',
            'unit': 'عدد',
            'buyPrice': 50000,
            'sellPrice': 80000,
            'stock': 10,
            'notes': '',
          },
        ]),
        PrefsStore.kCustomers: jsonEncode(<String, dynamic>[
          <String, dynamic>{
            'id': 'c1',
            'name': 'مشتری قدیمی',
            'mobile': '09121111111',
            'phone': '',
            'address': '',
            'notes': '',
            'balance': 20000,
            'createdAt': '1403/01/01',
          },
        ]),
        PrefsStore.kInvoices: jsonEncode(<String, dynamic>[
          // فاکتور فروش قدیمی: قلم‌ها قیمت خرید و شناسه‌ی کالا ندارند.
          <String, dynamic>{
            'id': 'inv-1',
            'number': '1001',
            'customerId': 'c1',
            'customerName': 'مشتری قدیمی',
            'customerPhone': '09121111111',
            'type': 'sale',
            'paymentType': 'non_cash',
            'status': 'unpaid',
            'date': '1403/01/02',
            'items': <dynamic>[
              <String, dynamic>{
                'id': 'it-1',
                'title': 'شامپو',
                'quantity': 2,
                'unit': 'عدد',
                'unitPrice': 80000,
                'totalPrice': 160000,
              },
            ],
            'subtotal': 160000,
            'discountAmount': 0,
            'shippingFee': 0,
            'previousDebt': 0,
            'deposit': 0,
            'totalAmount': 160000,
            'paidAmount': 0,
            'remainingAmount': 160000,
            'notes': '',
            'cardNumber': '',
            'createdAt': '1403/01/02',
          },
          // فاکتور خرید قدیمی: نام تامین‌کننده فقط در customerName است.
          <String, dynamic>{
            'id': 'inv-2',
            'number': '1002',
            'customerId': 'c-2',
            'customerName': 'تامین‌کننده نمونه',
            'customerPhone': '',
            'type': 'purchase',
            'paymentType': 'non_cash',
            'status': 'unpaid',
            'date': '1403/01/03',
            'items': <dynamic>[
              <String, dynamic>{
                'id': 'it-2',
                'title': 'شامپو',
                'quantity': 5,
                'unit': 'عدد',
                'unitPrice': 50000,
                'totalPrice': 250000,
              },
            ],
            'subtotal': 250000,
            'discountAmount': 0,
            'shippingFee': 0,
            'previousDebt': 0,
            'deposit': 0,
            'totalAmount': 250000,
            'paidAmount': 50000,
            'remainingAmount': 200000,
            'notes': '',
            'cardNumber': '',
            'createdAt': '1403/01/03',
          },
        ]),
        PrefsStore.kDraft: jsonEncode(<String, dynamic>{
          'id': 'draft-1',
          'number': '1003',
          'customerId': '',
          'customerName': '',
          'customerPhone': '',
          'type': 'sale',
          'paymentType': 'cash',
          'status': 'paid',
          'date': '1403/01/04',
          'items': <dynamic>[
            <String, dynamic>{
              'id': 'it-3',
              'title': 'شامپو',
              'quantity': 1,
              'unit': 'عدد',
              'unitPrice': 80000,
            },
          ],
          'subtotal': 80000,
          'discountAmount': 0,
          'shippingFee': 0,
          'previousDebt': 0,
          'deposit': 0,
          'totalAmount': 80000,
          'paidAmount': 80000,
          'remainingAmount': 0,
          'notes': '',
          'cardNumber': '',
          'createdAt': '1403/01/04',
        }),
      };

  setUp(() {
    SharedPreferences.setMockInitialValues(legacyPrefs());
  });

  test('داده‌ی نسخه‌ی قبل بدون حذف هیچ رکوردی منتقل می‌شود', () async {
    final before = await PrefsStore.loadInvoices();
    expect(before.length, 2);

    final report = await AppMigration.instance.ensureMigrated();

    expect(report.didRun, isTrue);
    expect(report.errors, isEmpty);
    expect(report.fromDataVersion, 1);
    expect(report.toDataVersion, 2);

    final after = await PrefsStore.loadInvoices();
    expect(after.length, before.length, reason: 'هیچ فاکتوری نباید حذف شود');
    expect(after.map((e) => e.id).toSet(), before.map((e) => e.id).toSet());
    expect(after.first.totalAmount, before.first.totalAmount);
    expect(after.first.paidAmount, before.first.paidAmount);
    expect(after.first.remainingAmount, before.first.remainingAmount);
    expect(after.first.date, before.first.date);

    // مشتری‌ها هم دست‌نخورده می‌مانند
    final customers = await PrefsStore.loadCustomers();
    expect(customers.length, 1);
    expect(customers.first.balance, 20000);
  });

  test('قیمت خرید و سود فاکتورهای قدیمی از کاتالوگ پر می‌شود', () async {
    await AppMigration.instance.ensureMigrated();
    final invoices = await PrefsStore.loadInvoices();

    final sale = invoices.firstWhere((invoice) => invoice.id == 'inv-1');
    expect(sale.items.first.buyPrice, 50000, reason: 'قیمت خرید از کاتالوگ پیدا شود');
    expect(sale.items.first.productId, 'p1', reason: 'شناسه‌ی کالا به قلم فاکتور اضافه شود');
    expect(sale.totalBuyAmount, 100000); // 2 × 50000
    expect(sale.profitAmount, 60000); // 2 × (80000 - 50000)

    final purchase = invoices.firstWhere((invoice) => invoice.id == 'inv-2');
    expect(purchase.totalBuyAmount, 250000);
    expect(purchase.profitAmount, 0, reason: 'فاکتور خرید سود ندارد');
  });

  test('کارت حساب تامین‌کننده از فاکتورهای خرید ساخته می‌شود', () async {
    await AppMigration.instance.ensureMigrated();
    final suppliers = await PrefsStore.loadSuppliers();
    expect(suppliers.length, 1);
    expect(suppliers.first.name, 'تامین‌کننده نمونه');
    expect(suppliers.first.balance, 200000, reason: 'مانده‌ی فاکتور خرید پرداخت‌نشده');

    final invoices = await PrefsStore.loadInvoices();
    final purchase = invoices.firstWhere((invoice) => invoice.id == 'inv-2');
    expect(purchase.supplierId, suppliers.first.id);
    expect(purchase.supplierName, 'تامین‌کننده نمونه');
  });

  test('اجرای دوباره‌ی مهاجرت داده را دو بار حساب نمی‌کند', () async {
    await AppMigration.instance.ensureMigrated();
    final firstRunSuppliers = await PrefsStore.loadSuppliers();
    final firstRunInvoices = await PrefsStore.loadInvoices();

    // اجرای معمول بعدی: هیچ کاری نباید انجام شود.
    final second = await AppMigration.instance.ensureMigrated();
    expect(second.didRun, isFalse);

    // حتی اجرای اجباری (مثلاً بعد از بازگردانی پشتیبان) نباید داده را تغییر دهد.
    final forced = await AppMigration.instance.reapplyAfterRestore();
    expect(forced.errors, isEmpty);

    final thirdRunSuppliers = await PrefsStore.loadSuppliers();
    final thirdRunInvoices = await PrefsStore.loadInvoices();

    expect(thirdRunSuppliers.length, firstRunSuppliers.length);
    expect(thirdRunSuppliers.first.balance, firstRunSuppliers.first.balance);
    expect(
      thirdRunInvoices.map((e) => '${e.id}:${e.totalBuyAmount}:${e.profitAmount}').toList(),
      firstRunInvoices.map((e) => '${e.id}:${e.totalBuyAmount}:${e.profitAmount}').toList(),
    );
  });

  test('پیش‌نویس نیمه‌کاره‌ی نسخه‌ی قبل هم منتقل می‌شود', () async {
    await AppMigration.instance.ensureMigrated();
    final draft = await PrefsStore.loadDraft();
    expect(draft, isNotNull);
    expect(draft!.id, 'draft-1');
    expect(draft.items.first.buyPrice, 50000);
  });

  test('دفتر مهاجرت با نسخه‌ی داده‌ی تازه ثبت می‌شود', () async {
    await AppMigration.instance.ensureMigrated();
    final ledger = await PrefsStore.readRawMap(PrefsStore.kMigrationLedger);
    expect(ledger, isNotNull);
    expect(ledger!['dataVersion'], PrefsStore.schemaVersion);
    expect((ledger['completed'] as List).length, 5);
  });

  test('نصب تازه مهاجرت را اجرا نمی‌کند و داده‌ی خالی نمی‌سازد', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final report = await AppMigration.instance.ensureMigrated();
    expect(report.didRun, isFalse);
    expect(report.hadLegacyData, isFalse);
    expect(await PrefsStore.loadSuppliers(), isEmpty);
    final ledger = await PrefsStore.readRawMap(PrefsStore.kMigrationLedger);
    expect(ledger?['dataVersion'], PrefsStore.schemaVersion);
  });

  test('مشتری گم‌شده از روی فاکتورهایش بازسازی می‌شود', () async {
    // شبیه‌سازی حالتی که فهرست مشتریان (به‌خاطر ایراد نسخه‌های قبلی) خالی شده
    // است اما فاکتورها باقی مانده‌اند.
    final prefs = legacyPrefs();
    prefs[PrefsStore.kCustomers] = jsonEncode(<dynamic>[]);
    SharedPreferences.setMockInitialValues(prefs);

    final report = await AppMigration.instance.ensureMigrated();
    expect(report.errors, isEmpty);

    final customers = await PrefsStore.loadCustomers();
    expect(customers.length, 1, reason: 'مشتری باید از روی فاکتور بازسازی شود');
    expect(customers.first.name, 'مشتری قدیمی');
    expect(customers.first.mobile, '09121111111');
    expect(customers.first.balance, 160000, reason: 'مانده‌ی فاکتور پرداخت‌نشده');

    final invoice = (await PrefsStore.loadInvoices()).firstWhere((item) => item.id == 'inv-1');
    expect(invoice.customerId, customers.first.id, reason: 'فاکتور باید به مشتری بازسازی‌شده وصل شود');

    // اجرای دوباره نباید مشتری تازه‌ی دیگری بسازد.
    await AppMigration.instance.reapplyAfterRestore();
    expect((await PrefsStore.loadCustomers()).length, 1);
  });

  test('مشتری و تامین‌کننده‌ی «عمومی» کارت حساب نمی‌سازند', () async {
    final prefs = legacyPrefs();
    prefs[PrefsStore.kCustomers] = jsonEncode(<dynamic>[]);
    prefs[PrefsStore.kInvoices] = jsonEncode(<dynamic>[
      <String, dynamic>{
        'id': 'inv-9',
        'number': '2001',
        'type': 'sale',
        'customerId': 'c-x',
        'customerName': 'مشتری عمومی',
        'customerPhone': '',
        'date': '1403/01/05',
        'items': <dynamic>[],
        'totalAmount': 50000,
        'paidAmount': 0,
        'remainingAmount': 50000,
        'createdAt': '1403/01/05',
      },
    ]);
    SharedPreferences.setMockInitialValues(prefs);

    await AppMigration.instance.ensureMigrated();
    expect(await PrefsStore.loadCustomers(), isEmpty);
  });

  test('رکورد خراب یا ناقص باعث از دست رفتن بقیه‌ی داده نمی‌شود', () async {
    final prefs = legacyPrefs();
    prefs[PrefsStore.kInvoices] = jsonEncode(<dynamic>[
      <String, dynamic>{'id': 'inv-1', 'number': '1001', 'totalAmount': 100000},
      'این یک رکورد خراب است',
      <String, dynamic>{
        'id': 'inv-1',
        'number': '1002',
        'totalAmount': 50000,
        'items': <dynamic>[],
      },
    ]);
    SharedPreferences.setMockInitialValues(prefs);

    final report = await AppMigration.instance.ensureMigrated();
    expect(report.errors, isEmpty);

    final invoices = await PrefsStore.loadInvoices();
    expect(invoices.length, 2, reason: 'رکورد خراب حذف می‌شود اما داده‌ی سالم می‌ماند');
    expect(invoices.map((e) => e.id).toSet().length, 2, reason: 'شناسه‌ی تکراری باید اصلاح شود');
  });
}
