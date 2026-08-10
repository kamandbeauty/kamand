import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

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

// Financial Expenses & Income Table
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

@DriftDatabase(tables: [
  UsersTable,
  BusinessProfileTable,
  CustomersTable,
  ProductsTable,
  InvoicesTable,
  FinancialTable,
  SettingsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'factor_fida.sqlite'));
    return NativeDatabase(file);
  });
}
