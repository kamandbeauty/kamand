import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// User Table
class UsersTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get country => text().withDefault(const Constant('ایران'))();
  TextColumn get province => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get usageType => text().withDefault(const Constant('store'))();
  BoolColumn get isOnboarded => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// Business Profile Table
class BusinessProfileTable extends Table {
  TextColumn get id => text()();
  TextColumn get shopName => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get taxId => text().nullable()();
  TextColumn get logoPath => text().nullable()();
  TextColumn get bankCardsJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Customers Table
class CustomersTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get mobile => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

// Products Table
class ProductsTable extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get unit => text().withDefault(const Constant('عدد'))();
  RealColumn get buyPrice => real().withDefault(const Constant(0.0))();
  RealColumn get sellPrice => real().withDefault(const Constant(0.0))();
  RealColumn get stock => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Invoices Table
class InvoicesTable extends Table {
  TextColumn get id => text()();
  TextColumn get number => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get customerName => text()();
  TextColumn get customerPhone => text().nullable()();
  TextColumn get type => text().withDefault(const Constant('sale'))();
  TextColumn get paymentType => text().withDefault(const Constant('cash'))();
  TextColumn get status => text().withDefault(const Constant('paid'))();
  TextColumn get date => text()();
  TextColumn get itemsJson => text()();
  RealColumn get subtotal => real()();
  RealColumn get discountPercent => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get shippingFee => real().withDefault(const Constant(0.0))();
  RealColumn get previousDebt => real().withDefault(const Constant(0.0))();
  RealColumn get deposit => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real()();
  RealColumn get paidAmount => real()();
  RealColumn get remainingAmount => real()();
  TextColumn get notes => text().nullable()();
  TextColumn get cardNumber => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

// Financial Expenses & Income Table (Legacy Combined Table)
class FinancialTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get category => text()();
  RealColumn get amount => real()();
  TextColumn get date => text()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isIncome => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// Expenses Table (DATABASE.md Table 8)
class ExpensesTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get category => text()();
  RealColumn get amount => real()();
  TextColumn get date => text()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Income Table (DATABASE.md Table 9)
class IncomeTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get category => text()();
  RealColumn get amount => real()();
  TextColumn get date => text()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Invoice Items Table (DATABASE.md Table 6)
class InvoiceItemsTable extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text()();
  TextColumn get productId => text().nullable()();
  TextColumn get title => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text().withDefault(const Constant('عدد'))();
  RealColumn get unitPrice => real()();
  RealColumn get totalPrice => real()();

  @override
  Set<Column> get primaryKey => {id};
}

// Payments Table (DATABASE.md Table 7)
class PaymentsTable extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text()();
  TextColumn get customerId => text()();
  RealColumn get amount => real()();
  TextColumn get date => text()();
  TextColumn get paymentMethod => text().withDefault(const Constant('کارت به کارت'))();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Settings Table
class SettingsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get startingInvoiceNum => integer().withDefault(const Constant(1004))();
  TextColumn get templateStyle => text().withDefault(const Constant('modern'))();
  BoolColumn get showLogo => boolean().withDefault(const Constant(true))();
  BoolColumn get showCardNum => boolean().withDefault(const Constant(true))();
  TextColumn get themeMode => text().withDefault(const Constant('light'))();
  BoolColumn get autoBackup => boolean().withDefault(const Constant(true))();
  TextColumn get pinCode => text().nullable()();
  BoolColumn get pinEnabled => boolean().withDefault(const Constant(false))();
}

// Backups Table (DATABASE.md Table 11)
class BackupsTable extends Table {
  TextColumn get id => text()();
  TextColumn get fileName => text()();
  TextColumn get createdAt => text()();
  IntColumn get sizeBytes => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  UsersTable,
  BusinessProfileTable,
  CustomersTable,
  ProductsTable,
  InvoicesTable,
  InvoiceItemsTable,
  PaymentsTable,
  ExpensesTable,
  IncomeTable,
  FinancialTable,
  SettingsTable,
  BackupsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<void> persistInvoiceRecord(String id, String number, String customerName, String date, double totalAmount) async {
    try {
      await into(invoicesTable).insertOnConflictUpdate(
        InvoicesTableCompanion.insert(
          id: id,
          number: number,
          customerName: customerName,
          date: date,
          itemsJson: '',
          subtotal: totalAmount,
          totalAmount: totalAmount,
          paidAmount: totalAmount,
          remainingAmount: 0,
          createdAt: date,
        ),
      );
    } catch (_) {}
  }

  Future<void> persistCustomerRecord(String id, String name, double balance, String createdAt) async {
    try {
      await into(customersTable).insertOnConflictUpdate(
        CustomersTableCompanion.insert(
          id: id,
          name: name,
          balance: Value(balance),
          createdAt: createdAt,
        ),
      );
    } catch (_) {}
  }

  Future<void> persistProductRecord(String id, String code, String name, double sellPrice) async {
    try {
      await into(productsTable).insertOnConflictUpdate(
        ProductsTableCompanion.insert(
          id: id,
          code: code,
          name: name,
          sellPrice: Value(sellPrice),
        ),
      );
    } catch (_) {}
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'factor_ruby.sqlite'));
    return NativeDatabase(file);
  });
}
