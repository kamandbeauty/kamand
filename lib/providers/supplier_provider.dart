import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplier_model.dart';
import '../core/utils/prefs_store.dart';
import '../database/app_database.dart';

final supplierListProvider =
    StateNotifierProvider<SupplierListNotifier, List<SupplierModel>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SupplierListNotifier(db);
});

class SupplierListNotifier extends StateNotifier<List<SupplierModel>> {
  final AppDatabase? db;
  late final Future<void> _hydrated;

  SupplierListNotifier([this.db]) : super(const []) {
    _hydrated = _hydrate();
  }

  Future<void> ensureLoaded() => _hydrated;

  Future<void> _hydrate() async {
    state = await PrefsStore.loadSuppliers();
  }

  Future<void> _persist() async {
    await PrefsStore.saveSuppliers(state);
  }

  Future<void> addSupplier(SupplierModel supplier) async {
    await _hydrated;
    state = [...state, supplier];
    await PrefsStore.saveSuppliers(state);
  }

  Future<void> updateSupplier(SupplierModel supplier) async {
    await _hydrated;
    state = [
      for (final item in state)
        if (item.id == supplier.id) supplier else item,
    ];
    await _persist();
  }

  Future<void> deleteSupplier(String id) async {
    await _hydrated;
    state = state.where((item) => item.id != id).toList();
    await _persist();
  }

  Future<void> updateBalance(String id, double delta) async {
    await _hydrated;
    state = state.map((item) {
      if (item.id != id) return item;
      return item.copyWith(balance: (item.balance + delta).clamp(0, double.infinity).toDouble());
    }).toList();
    await _persist();
  }

  Future<void> recordPayment(String id, double amount) async {
    await _hydrated;
    if (amount <= 0) return;
    state = state.map((item) {
      if (item.id != id) return item;
      return item.copyWith(balance: (item.balance - amount).clamp(0, double.infinity).toDouble());
    }).toList();
    await _persist();
  }
}
