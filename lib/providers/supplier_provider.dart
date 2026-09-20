import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/persistent_list.dart';
import '../core/utils/prefs_store.dart';
import '../database/app_database.dart';
import '../models/supplier_model.dart';

final supplierListProvider =
    StateNotifierProvider<SupplierListNotifier, List<SupplierModel>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SupplierListNotifier(db);
});

class SupplierListNotifier extends PersistentListNotifier<SupplierModel> {
  SupplierListNotifier([this.db]);

  final AppDatabase? db;

  @override
  Future<List<SupplierModel>> readFromStorage() => PrefsStore.loadSuppliers();

  @override
  Future<void> writeToStorage(List<SupplierModel> items) async {
    await PrefsStore.saveSuppliers(items);
    await db?.mirrorSuppliers(items);
  }

  Future<void> addSupplier(SupplierModel supplier) => mutateAsync(
        (suppliers) => suppliers.any((item) => item.id == supplier.id)
            ? suppliers
            : [...suppliers, supplier],
      );

  void updateSupplier(SupplierModel supplier) {
    mutate(
      (suppliers) => [
        for (final item in suppliers)
          if (item.id == supplier.id) supplier else item,
      ],
    );
  }

  void deleteSupplier(String id) {
    mutate((suppliers) => suppliers.where((item) => item.id != id).toList());
  }

  /// افزایش بدهی ما به تامین‌کننده (فاکتور خرید غیرنقدی).
  /// مقدار [delta] فقط یک بار اعمال می‌شود.
  void updateBalance(String id, double delta) {
    if (delta == 0) return;
    mutate(
      (suppliers) => [
        for (final item in suppliers)
          if (item.id == id)
            item.copyWith(balance: (item.balance + delta).clamp(0, double.infinity).toDouble())
          else
            item,
      ],
    );
  }

  /// پرداخت به تامین‌کننده؛ یک بار و بدون تکرار.
  void recordPayment(String id, double amount) {
    if (amount <= 0) return;
    mutate(
      (suppliers) => [
        for (final item in suppliers)
          if (item.id == id)
            item.copyWith(balance: (item.balance - amount).clamp(0, double.infinity).toDouble())
          else
            item,
      ],
    );
  }
}
