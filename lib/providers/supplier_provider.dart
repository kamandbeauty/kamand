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

  void _persist() {
    PrefsStore.saveSuppliers(state);
  }

  Future<void> addSupplier(SupplierModel supplier) async {
    await _hydrated;
    state = [...state, supplier];
    await PrefsStore.saveSuppliers(state);
  }

  void updateSupplier(SupplierModel supplier) {
    state = [
      for (final item in state)
        if (item.id == supplier.id) supplier else item,
    ];
    _hydrated.then((_) {
      state = [
        for (final item in state)
          if (item.id == supplier.id) supplier else item,
      ];
      _persist();
    });
    _persist();
  }

  void deleteSupplier(String id) {
    state = state.where((item) => item.id != id).toList();
    _hydrated.then((_) {
      state = state.where((item) => item.id != id).toList();
      _persist();
    });
    _persist();
  }

  void updateBalance(String id, double delta) {
    state = state.map((item) {
      if (item.id != id) return item;
      return item.copyWith(balance: (item.balance + delta).clamp(0, double.infinity).toDouble());
    }).toList();
    _hydrated.then((_) {
      state = state.map((item) {
        if (item.id != id) return item;
        return item.copyWith(balance: (item.balance + delta).clamp(0, double.infinity).toDouble());
      }).toList();
      _persist();
    });
    _persist();
  }

  void recordPayment(String id, double amount) {
    if (amount <= 0) return;
    state = state.map((item) {
      if (item.id != id) return item;
      return item.copyWith(balance: (item.balance - amount).clamp(0, double.infinity).toDouble());
    }).toList();
    _hydrated.then((_) {
      state = state.map((item) {
        if (item.id != id) return item;
        return item.copyWith(balance: (item.balance - amount).clamp(0, double.infinity).toDouble());
      }).toList();
      _persist();
    });
    _persist();
  }
}
