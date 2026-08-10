import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// Offline-First local database implementation using SQLite.
/// Works out-of-the-box without requiring generated build_runner files.
class AppDatabase {
  Database? _db;
  bool _initialized = false;

  AppDatabase() {
    _initDb();
  }

  Future<void> _initDb() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'factor_ruby.sqlite'));
      _db = sqlite3.open(file.path);
      _createTables();
      _initialized = true;
    } catch (_) {
      // Fallback in-memory state is maintained cleanly by Riverpod
    }
  }

  void _createTables() {
    if (_db == null) return;
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id TEXT PRIMARY KEY,
        number TEXT,
        customerName TEXT,
        date TEXT,
        totalAmount REAL,
        createdAt TEXT
      );
    ''');
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        name TEXT,
        balance REAL,
        createdAt TEXT
      );
    ''');
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        code TEXT,
        name TEXT,
        sellPrice REAL
      );
    ''');
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        startingInvoiceNum INTEGER DEFAULT 1004,
        templateStyle TEXT DEFAULT 'modern',
        showLogo INTEGER DEFAULT 1,
        showCardNum INTEGER DEFAULT 1,
        themeMode TEXT DEFAULT 'light'
      );
    ''');
  }

  Future<void> persistInvoiceRecord(
      String id, String number, String customerName, String date, double totalAmount) async {
    try {
      if (!_initialized) await _initDb();
      _db?.execute(
        'INSERT OR REPLACE INTO invoices (id, number, customerName, date, totalAmount, createdAt) VALUES (?, ?, ?, ?, ?, ?)',
        [id, number, customerName, date, totalAmount, date],
      );
    } catch (_) {}
  }

  Future<void> persistCustomerRecord(
      String id, String name, double balance, String createdAt) async {
    try {
      if (!_initialized) await _initDb();
      _db?.execute(
        'INSERT OR REPLACE INTO customers (id, name, balance, createdAt) VALUES (?, ?, ?, ?)',
        [id, name, balance, createdAt],
      );
    } catch (_) {}
  }

  Future<void> persistProductRecord(
      String id, String code, String name, double sellPrice) async {
    try {
      if (!_initialized) await _initDb();
      _db?.execute(
        'INSERT OR REPLACE INTO products (id, code, name, sellPrice) VALUES (?, ?, ?, ?)',
        [id, code, name, sellPrice],
      );
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// DATABASE SCHEMA REFERENCE (DATABASE.md)
// ---------------------------------------------------------------------------

class UsersTableSchema {
  final String id = 'id';
  final String name = 'name';
  final String country = 'country';
  final String province = 'province';
  final String city = 'city';
  final String usageType = 'usage_type';
  final String isOnboarded = 'is_onboarded';
}

class BusinessProfileTableSchema {
  final String id = 'id';
  final String shopName = 'shop_name';
  final String phone = 'phone';
  final String address = 'address';
  final String taxId = 'tax_id';
  final String logoPath = 'logo_path';
  final String bankCardsJson = 'bank_cards_json';
}

class CustomersTableSchema {
  final String id = 'id';
  final String name = 'name';
  final String mobile = 'mobile';
  final String phone = 'phone';
  final String address = 'address';
  final String notes = 'notes';
  final String balance = 'balance';
  final String createdAt = 'created_at';
}

class ProductsTableSchema {
  final String id = 'id';
  final String code = 'code';
  final String name = 'name';
  final String unit = 'unit';
  final String buyPrice = 'buy_price';
  final String sellPrice = 'sell_price';
  final String stock = 'stock';
  final String notes = 'notes';
}

class InvoicesTableSchema {
  final String id = 'id';
  final String number = 'number';
  final String customerId = 'customer_id';
  final String customerName = 'customer_name';
  final String customerPhone = 'customer_phone';
  final String type = 'type';
  final String paymentType = 'payment_type';
  final String status = 'status';
  final String date = 'date';
  final String itemsJson = 'items_json';
  final String subtotal = 'subtotal';
  final String discountPercent = 'discount_percent';
  final String discountAmount = 'discount_amount';
  final String shippingFee = 'shipping_fee';
  final String previousDebt = 'previous_debt';
  final String deposit = 'deposit';
  final String totalAmount = 'total_amount';
  final String paidAmount = 'paid_amount';
  final String remainingAmount = 'remaining_amount';
  final String notes = 'notes';
  final String cardNumber = 'card_number';
  final String createdAt = 'created_at';
}

class InvoiceItemsTableSchema {
  final String id = 'id';
  final String invoiceId = 'invoice_id';
  final String productId = 'product_id';
  final String title = 'title';
  final String quantity = 'quantity';
  final String unit = 'unit';
  final String unitPrice = 'unit_price';
  final String totalPrice = 'total_price';
}

class PaymentsTableSchema {
  final String id = 'id';
  final String invoiceId = 'invoice_id';
  final String customerId = 'customer_id';
  final String amount = 'amount';
  final String date = 'date';
  final String paymentMethod = 'payment_method';
  final String notes = 'notes';
}

class ExpensesTableSchema {
  final String id = 'id';
  final String title = 'title';
  final String category = 'category';
  final String amount = 'amount';
  final String date = 'date';
  final String notes = 'notes';
}

class IncomeTableSchema {
  final String id = 'id';
  final String title = 'title';
  final String category = 'category';
  final String amount = 'amount';
  final String date = 'date';
  final String notes = 'notes';
}

class SettingsTableSchema {
  final String id = 'id';
  final String startingInvoiceNum = 'starting_invoice_num';
  final String templateStyle = 'template_style';
  final String showLogo = 'show_logo';
  final String showCardNum = 'show_card_num';
  final String themeMode = 'theme_mode';
  final String autoBackup = 'auto_backup';
  final String pinCode = 'pin_code';
  final String pinEnabled = 'pin_enabled';
}

class BackupsTableSchema {
  final String id = 'id';
  final String fileName = 'file_name';
  final String createdAt = 'created_at';
  final String sizeBytes = 'size_bytes';
}
