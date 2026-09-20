import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/bank_card_model.dart';
import '../models/customer_model.dart';
import '../models/expense_model.dart';
import '../models/invoice_item_model.dart';
import '../models/invoice_model.dart';
import '../models/product_model.dart';
import '../models/supplier_model.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// پایگاه‌داده محلی (SQLite) به‌عنوان «آینه‌ی» اطلاعات برنامه.
///
/// منبع اصلی داده همان SharedPreferences است، اما این فایل SQLite از نسخه‌ی
/// ۱.۰.۴ روی گوشی کاربران وجود دارد؛ بنابراین هنگام به‌روزرسانی:
///
///  • هیچ‌وقت فایل پاک یا بازنویسی نمی‌شود (`DELETE`/`DROP` نداریم)؛
///  • ساختار با شماره‌ی `PRAGMA user_version` ارتقا پیدا می‌کند؛
///  • ستون‌های تازه با `ALTER TABLE ... ADD COLUMN` به جدول‌های قدیمی اضافه
///    می‌شوند و داده‌ی نسخه‌ی قبل دست‌نخورده می‌ماند؛
///  • اگر جدول یا ستونی به هر دلیلی گم شده باشد، در هر اجرا ترمیم می‌شود.
class AppDatabase {
  /// نسخه‌ی ساختار فعلی. نسخه‌ی ۱ همان جداول عرضه‌شده در ۱.۰.۴ است.
  static const int schemaVersion = 2;

  Database? _db;
  bool _initialized = false;
  final String? pathOverride;
  final bool inMemory;

  AppDatabase({this.pathOverride, this.inMemory = false}) {
    _ready = _initDb();
  }

  late final Future<void> _ready;

  /// پایان آماده‌سازی و ارتقای ساختار جدول‌ها.
  Future<void> get ready => _ready;

  bool get isReady => _initialized;

  Future<void> _initDb() async {
    try {
      if (inMemory) {
        _db = sqlite3.openInMemory();
      } else {
        final dbFolder = await getApplicationDocumentsDirectory();
        final path = pathOverride ?? p.join(dbFolder.path, 'factor_ruby.sqlite');
        _db = sqlite3.open(path);
      }
      _migrate();
      _initialized = true;
    } catch (error, stack) {
      // خطای پایگاه‌داده هرگز نباید اجرای برنامه را متوقف کند؛ اطلاعات اصلی
      // در SharedPreferences است و دست‌نخورده می‌ماند.
      debugPrint('AppDatabase init failed: $error\n$stack');
    }
  }

  // ---------------------------------------------------------------------------
  // مهاجرت ساختار
  // ---------------------------------------------------------------------------

  int get userVersion {
    final db = _db;
    if (db == null) return 0;
    try {
      return db.select('PRAGMA user_version').first.values.first as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  void _setUserVersion(int version) {
    _db?.execute('PRAGMA user_version = $version');
  }

  void _migrate() {
    final db = _db;
    if (db == null) return;

    final from = userVersion;
    try {
      db.execute('BEGIN');
      try {
        if (from < 1) {
          _createSchemaV1();
        }
        if (from < schemaVersion) {
          _upgradeToSchemaV2();
        }
        // ترمیم همیشگی: اگر جدول/ستونی به هر دلیلی گم شده باشد اضافه می‌شود.
        _createSchemaV1();
        _upgradeToSchemaV2();
        _createIndexes();
        _setUserVersion(schemaVersion);
        _recordMigration(from, schemaVersion, 'schema upgrade');
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
      debugPrint('AppDatabase schema ready (was v$from, now v$schemaVersion).');
    } catch (error) {
      debugPrint('AppDatabase migration failed: $error');
    }
  }

  /// ساختار نسخه‌ی ۱.۰.۴ — عیناً همان دستورهایی که نسخه‌ی نصب‌شده اجرا کرده
  /// است، تا روی نصب‌های موجود بی‌اثر (no-op) باشد.
  void _createSchemaV1() {
    final db = _db;
    if (db == null) return;
    db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id TEXT PRIMARY KEY,
        number TEXT,
        customerName TEXT,
        date TEXT,
        totalAmount REAL,
        createdAt TEXT
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        name TEXT,
        balance REAL,
        createdAt TEXT
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        code TEXT,
        name TEXT,
        sellPrice REAL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        startingInvoiceNum INTEGER DEFAULT 1,
        templateStyle TEXT DEFAULT 'modern',
        showLogo INTEGER DEFAULT 1,
        showCardNum INTEGER DEFAULT 1,
        themeMode TEXT DEFAULT 'light'
      );
    ''');
  }

  /// ساختار نسخه‌ی ۲: جدول‌های تازه + ستون‌های تازه روی جدول‌های قدیمی.
  void _upgradeToSchemaV2() {
    final db = _db;
    if (db == null) return;

    db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        name TEXT,
        phone TEXT,
        mobile TEXT,
        address TEXT,
        notes TEXT,
        balance REAL DEFAULT 0,
        createdAt TEXT,
        updatedAt TEXT
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id TEXT PRIMARY KEY,
        title TEXT,
        amount REAL DEFAULT 0,
        category TEXT,
        date TEXT,
        notes TEXT,
        invoiceId TEXT,
        createdAt TEXT,
        updatedAt TEXT
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS bank_cards (
        id TEXT PRIMARY KEY,
        cardNumber TEXT,
        sheba TEXT,
        bankName TEXT,
        persianName TEXT,
        createdAt TEXT,
        updatedAt TEXT
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_items (
        id TEXT PRIMARY KEY,
        invoiceId TEXT,
        title TEXT,
        quantity REAL DEFAULT 0,
        unit TEXT,
        unitPrice REAL DEFAULT 0,
        totalPrice REAL DEFAULT 0,
        buyPrice REAL DEFAULT 0,
        productId TEXT
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS app_meta (
        key TEXT PRIMARY KEY,
        value TEXT
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS data_migrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fromVersion INTEGER,
        toVersion INTEGER,
        name TEXT,
        appliedAt TEXT
      );
    ''');

    _ensureColumns('invoices', <String, String>{
      'customerId': 'TEXT',
      'customerPhone': 'TEXT',
      'type': 'TEXT',
      'paymentType': 'TEXT',
      'status': 'TEXT',
      'paidAmount': 'REAL DEFAULT 0',
      'remainingAmount': 'REAL DEFAULT 0',
      'subtotal': 'REAL DEFAULT 0',
      'discountPercent': 'REAL DEFAULT 0',
      'discountAmount': 'REAL DEFAULT 0',
      'shippingFee': 'REAL DEFAULT 0',
      'previousDebt': 'REAL DEFAULT 0',
      'deposit': 'REAL DEFAULT 0',
      'notes': 'TEXT',
      'supplierId': 'TEXT',
      'supplierName': 'TEXT',
      'totalBuyAmount': 'REAL DEFAULT 0',
      'profitAmount': 'REAL DEFAULT 0',
      'expenseAmount': 'REAL DEFAULT 0',
      'expenseTitle': 'TEXT',
      'itemsJson': 'TEXT',
      'updatedAt': 'TEXT',
    });

    _ensureColumns('customers', <String, String>{
      'mobile': 'TEXT',
      'phone': 'TEXT',
      'address': 'TEXT',
      'notes': 'TEXT',
      'updatedAt': 'TEXT',
    });

    _ensureColumns('products', <String, String>{
      'unit': 'TEXT',
      'buyPrice': 'REAL DEFAULT 0',
      'stock': 'REAL DEFAULT 0',
      'notes': 'TEXT',
      'updatedAt': 'TEXT',
    });

    _ensureColumns('settings', <String, String>{
      'showStamp': 'INTEGER DEFAULT 1',
      'showSignature': 'INTEGER DEFAULT 1',
      // 0xFFF97316 — رنگ نارنجی پیش‌فرض روبی
      'accentColor': 'INTEGER DEFAULT 4294538006',
      'autoBackup': 'INTEGER DEFAULT 1',
      'pinCode': 'TEXT',
      'pinEnabled': 'INTEGER DEFAULT 0',
    });
  }

  void _ensureColumns(String table, Map<String, String> columns) {
    final db = _db;
    if (db == null) return;
    final existing = _tableColumns(table);
    if (existing.isEmpty) return; // جدول وجود ندارد؛ ساختش با CREATE انجام شده است
    for (final entry in columns.entries) {
      if (existing.contains(entry.key)) continue;
      try {
        db.execute('ALTER TABLE $table ADD COLUMN ${entry.key} ${entry.value}');
      } catch (error) {
        debugPrint('AppDatabase: adding $table.${entry.key} failed: $error');
      }
    }
  }

  Set<String> _tableColumns(String table) {
    final db = _db;
    if (db == null) return <String>{};
    try {
      final rows = db.select('PRAGMA table_info($table)');
      return rows.map((row) => '${row['name']}').toSet();
    } catch (_) {
      return <String>{};
    }
  }

  void _createIndexes() {
    final db = _db;
    if (db == null) return;
    const statements = <String>[
      'CREATE INDEX IF NOT EXISTS idx_invoices_number ON invoices(number)',
      'CREATE INDEX IF NOT EXISTS idx_invoices_date ON invoices(date)',
      'CREATE INDEX IF NOT EXISTS idx_invoices_supplier ON invoices(supplierId)',
      'CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items(invoiceId)',
      'CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)',
      'CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)',
      'CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)',
      'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date)',
    ];
    for (final statement in statements) {
      try {
        db.execute(statement);
      } catch (_) {}
    }
  }

  void _recordMigration(int from, int to, String name) {
    final db = _db;
    if (db == null) return;
    if (from >= to) return;
    try {
      db.execute(
        'INSERT INTO data_migrations (fromVersion, toVersion, name, appliedAt) VALUES (?, ?, ?, ?)',
        [from, to, name, DateTime.now().toIso8601String()],
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // نوشتن (آینه‌کردن داده‌های برنامه)
  // ---------------------------------------------------------------------------

  /// درج/به‌روزرسانی یک فاکتور. (سازگار با نسخه‌ی قبل)
  ///
  /// از UPSERT استفاده می‌کند نه `INSERT OR REPLACE`؛ چون REPLACE کل ردیف را
  /// دور می‌ریزد و ستون‌های تکمیل‌شده (سود، بهای تمام شده، اقلام) را پاک
  /// می‌کرد. اینجا فقط ستون‌های همین نوشتن به‌روز می‌شوند.
  Future<void> persistInvoiceRecord(
      String id, String number, String customerName, String date, double totalAmount) async {
    await _run(() {
      _db?.execute(
        'INSERT INTO invoices (id, number, customerName, date, totalAmount, createdAt, updatedAt) '
        'VALUES (?, ?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(id) DO UPDATE SET '
        'number = excluded.number, customerName = excluded.customerName, date = excluded.date, '
        'totalAmount = excluded.totalAmount, updatedAt = excluded.updatedAt',
        [id, number, customerName, date, totalAmount, date, DateTime.now().toIso8601String()],
      );
    });
  }

  /// درج/به‌روزرسانی یک مشتری. (سازگار با نسخه‌ی قبل)
  Future<void> persistCustomerRecord(
      String id, String name, double balance, String createdAt) async {
    await _run(() {
      _db?.execute(
        'INSERT INTO customers (id, name, balance, createdAt, updatedAt) VALUES (?, ?, ?, ?, ?) '
        'ON CONFLICT(id) DO UPDATE SET name = excluded.name, balance = excluded.balance, '
        'updatedAt = excluded.updatedAt',
        [id, name, balance, createdAt, DateTime.now().toIso8601String()],
      );
    });
  }

  /// درج/به‌روزرسانی یک کالا. (سازگار با نسخه‌ی قبل)
  Future<void> persistProductRecord(
      String id, String code, String name, double sellPrice) async {
    await _run(() {
      _db?.execute(
        'INSERT INTO products (id, code, name, sellPrice, updatedAt) VALUES (?, ?, ?, ?, ?) '
        'ON CONFLICT(id) DO UPDATE SET code = excluded.code, name = excluded.name, '
        'sellPrice = excluded.sellPrice, updatedAt = excluded.updatedAt',
        [id, code, name, sellPrice, DateTime.now().toIso8601String()],
      );
    });
  }

  /// آینه‌کردن کل فهرست فاکتورها. هیچ رکوردی حذف نمی‌شود.
  Future<void> mirrorInvoices(List<InvoiceModel> invoices) async {
    await _run(() {
      final db = _db;
      if (db == null) return;
      final now = DateTime.now().toIso8601String();
      for (final invoice in invoices) {
        db.execute(
          'INSERT OR REPLACE INTO invoices ('
          'id, number, customerId, customerName, customerPhone, type, paymentType, status, date, '
          'subtotal, discountPercent, discountAmount, shippingFee, previousDebt, deposit, '
          'totalAmount, paidAmount, remainingAmount, notes, supplierId, supplierName, '
          'totalBuyAmount, profitAmount, expenseAmount, expenseTitle, itemsJson, createdAt, updatedAt'
          ') VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
          [
            invoice.id,
            invoice.number,
            invoice.customerId,
            invoice.customerName,
            invoice.customerPhone,
            invoice.type,
            invoice.paymentType,
            invoice.status,
            invoice.date,
            invoice.subtotal,
            invoice.discountPercent,
            invoice.discountAmount,
            invoice.shippingFee,
            invoice.previousDebt,
            invoice.deposit,
            invoice.totalAmount,
            invoice.paidAmount,
            invoice.remainingAmount,
            invoice.notes,
            invoice.supplierId,
            invoice.supplierName,
            invoice.totalBuyAmount,
            invoice.profitAmount,
            invoice.expenseAmount,
            invoice.expenseTitle,
            _itemsToJson(invoice.items),
            invoice.createdAt,
            now,
          ],
        );
        for (var index = 0; index < invoice.items.length; index++) {
          final item = invoice.items[index];
          // اگر شناسه‌ی قلم خالی باشد (داده‌ی نسخه‌های قدیمی) از شماره‌ی ترتیب
          // استفاده می‌شود تا اقلام روی هم بازنویسی نشوند.
          final itemKey = item.id.trim().isEmpty ? '${invoice.id}::index-$index' : '${invoice.id}::${item.id}';
          db.execute(
            'INSERT OR REPLACE INTO invoice_items '
            '(id, invoiceId, title, quantity, unit, unitPrice, totalPrice, buyPrice, productId) '
            'VALUES (?,?,?,?,?,?,?,?,?)',
            [
              itemKey,
              invoice.id,
              item.title,
              item.quantity,
              item.unit,
              item.unitPrice,
              item.totalPrice,
              item.buyPrice,
              item.productId,
            ],
          );
        }
      }
    });
  }

  Future<void> mirrorCustomers(List<CustomerModel> customers) async {
    await _run(() {
      final db = _db;
      if (db == null) return;
      final now = DateTime.now().toIso8601String();
      for (final customer in customers) {
        db.execute(
          'INSERT OR REPLACE INTO customers '
          '(id, name, mobile, phone, address, notes, balance, createdAt, updatedAt) '
          'VALUES (?,?,?,?,?,?,?,?,?)',
          [
            customer.id,
            customer.name,
            customer.mobile,
            customer.phone,
            customer.address,
            customer.notes,
            customer.balance,
            customer.createdAt,
            now,
          ],
        );
      }
    });
  }

  Future<void> mirrorProducts(List<ProductModel> products) async {
    await _run(() {
      final db = _db;
      if (db == null) return;
      final now = DateTime.now().toIso8601String();
      for (final product in products) {
        db.execute(
          'INSERT OR REPLACE INTO products '
          '(id, code, name, unit, buyPrice, sellPrice, stock, notes, updatedAt) '
          'VALUES (?,?,?,?,?,?,?,?,?)',
          [
            product.id,
            product.code,
            product.name,
            product.unit,
            product.buyPrice,
            product.sellPrice,
            product.stock,
            product.notes,
            now,
          ],
        );
      }
    });
  }

  Future<void> mirrorSuppliers(List<SupplierModel> suppliers) async {
    await _run(() {
      final db = _db;
      if (db == null) return;
      final now = DateTime.now().toIso8601String();
      for (final supplier in suppliers) {
        db.execute(
          'INSERT OR REPLACE INTO suppliers '
          '(id, name, phone, mobile, address, notes, balance, createdAt, updatedAt) '
          'VALUES (?,?,?,?,?,?,?,?,?)',
          [
            supplier.id,
            supplier.name,
            supplier.phone,
            supplier.mobile,
            supplier.address,
            supplier.notes,
            supplier.balance,
            supplier.createdAt,
            now,
          ],
        );
      }
    });
  }

  Future<void> mirrorExpenses(List<ExpenseModel> expenses) async {
    await _run(() {
      final db = _db;
      if (db == null) return;
      final now = DateTime.now().toIso8601String();
      for (final expense in expenses) {
        db.execute(
          'INSERT OR REPLACE INTO expenses '
          '(id, title, amount, category, date, notes, invoiceId, createdAt, updatedAt) '
          'VALUES (?,?,?,?,?,?,?,?,?)',
          [
            expense.id,
            expense.title,
            expense.amount,
            expense.category,
            expense.date,
            expense.notes,
            expense.invoiceId,
            expense.createdAt,
            now,
          ],
        );
      }
    });
  }

  Future<void> mirrorBankCards(List<BankCardModel> cards) async {
    await _run(() {
      final db = _db;
      if (db == null) return;
      final now = DateTime.now().toIso8601String();
      for (final card in cards) {
        db.execute(
          'INSERT OR REPLACE INTO bank_cards '
          '(id, cardNumber, sheba, bankName, persianName, updatedAt) '
          'VALUES (?,?,?,?,?,?)',
          [card.id, card.cardNumber, card.sheba, card.bankName, card.persianName, now],
        );
      }
    });
  }

  /// ثبت یادداشت مهاجرت/به‌روزرسانی برای پیگیری پشتیبانی.
  Future<void> logEvent(String key, String value) async {
    await _run(() {
      _db?.execute(
        'INSERT OR REPLACE INTO app_meta (key, value) VALUES (?, ?)',
        [key, value],
      );
    });
  }

  // ---------------------------------------------------------------------------
  // خواندن (برای بازیابی و پشتیبان‌گیری)
  // ---------------------------------------------------------------------------

  /// خواندن همه‌ی ردیف‌های یک جدول؛ در صورت نبود جدول، لیست خالی.
  Future<List<Map<String, dynamic>>> readTable(String table) async {
    final db = _db;
    if (db == null) return <Map<String, dynamic>>[];
    try {
      final rows = db.select('SELECT * FROM $table');
      return rows.map((row) => Map<String, dynamic>.from(row)).toList();
    } catch (error) {
      debugPrint('AppDatabase: reading $table failed: $error');
      return <Map<String, dynamic>>[];
    }
  }

  /// تعداد ردیف‌های یک جدول (برای گزارش وضعیت مهاجرت).
  Future<int> countRows(String table) async {
    final db = _db;
    if (db == null) return 0;
    try {
      return db.select('SELECT COUNT(*) AS c FROM $table').first['c'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> close() async {
    try {
      _db?.dispose();
    } catch (_) {}
    _db = null;
    _initialized = false;
  }

  // ---------------------------------------------------------------------------
  // کمکی‌های داخلی
  // ---------------------------------------------------------------------------

  Future<void> _run(void Function() action) async {
    try {
      await _ready;
      final db = _db;
      if (db == null) return;
      action();
    } catch (error) {
      // نوشتن در پایگاه‌داده هرگز نباید جریان برنامه را متوقف کند.
      debugPrint('AppDatabase write failed: $error');
    }
  }

  String _itemsToJson(List<InvoiceItemModel> items) {
    try {
      return jsonEncode(items.map((item) => item.toMap()).toList());
    } catch (_) {
      return '[]';
    }
  }
}
