import 'bridge/sales_ledger_bridge.dart';
import 'core/accounts.dart';
import 'core/audit.dart';
import 'core/inventory.dart';
import 'customers/customer_finance.dart';
import 'db/store_database.dart';
import 'expenses/expense_repository.dart';
import 'installments/installment_repository.dart';
import 'reports/report_repository.dart';
import 'suppliers/purchase_repository.dart';
import 'suppliers/supplier_repository.dart';

/// هستهٔ فروشگاه — نقطهٔ واحد دسترسی به همهٔ مخزن‌های حسابداری.
/// پول همه‌جا Long/تومان است؛ همهٔ جهش‌ها تراکنشی و idempotent هستند.
class StoreCore {
  final StoreDatabase db;
  late final AuditLog audit = AuditLog(db);
  late final LedgerRepository ledger = LedgerRepository(db);
  late final AccountRepository accounts = AccountRepository(db, ledger);
  late final InventoryRepository inventory = InventoryRepository(db, audit);
  late final CustomerCreditRepository credit = CustomerCreditRepository(db);
  late final InstallmentRepository installments =
      InstallmentRepository(db, ledger, audit, credit);
  late final CustomerFinanceRepository customerFinance =
      CustomerFinanceRepository(db, ledger, audit, credit);
  late final SupplierRepository suppliers = SupplierRepository(db, ledger, audit);
  late final PurchaseRepository purchases =
      PurchaseRepository(db, ledger, inventory, audit);
  late final ExpenseRepository expenses = ExpenseRepository(db, ledger, audit);
  late final ReportRepository reports = ReportRepository(db, ledger);
  late final SalesLedgerBridge bridge = SalesLedgerBridge(
    store: db,
    ledger: ledger,
    inventory: inventory,
    audit: audit,
  );

  StoreCore._(this.db);

  static Future<StoreCore> open(String path) async {
    return StoreCore._(StoreDatabase.open(path));
  }

  /// برای تست‌ها — دیتابیس درون‌حافظه‌ای
  factory StoreCore.inMemory() => StoreCore._(StoreDatabase.inMemory());

  void close() => db.close();
}
