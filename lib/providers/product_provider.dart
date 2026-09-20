import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_model.dart';
import '../core/utils/prefs_store.dart';
import '../database/app_database.dart';

final productListProvider =
    StateNotifierProvider<ProductListNotifier, List<ProductModel>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProductListNotifier(db);
});

class ProductListNotifier extends StateNotifier<List<ProductModel>> {
  final AppDatabase? db;
  late final Future<void> _hydrated;

  ProductListNotifier([this.db]) : super(const []) {
    _hydrated = _hydrate();
  }

  Future<void> ensureLoaded() => _hydrated;

  Future<void> _hydrate() async {
    state = await PrefsStore.loadProducts();
  }

  void _persist() {
    PrefsStore.saveProducts(state);
  }

  void addProduct(ProductModel product) {
    // optimistic immediate
    state = [...state, product];
    _hydrated.then((_) {
      if (!state.any((p) => p.id == product.id)) {
        state = [...state, product];
      }
      _persist();
      db?.persistProductRecord(product.id, product.code, product.name, product.sellPrice);
    });
  }

  void updateProduct(ProductModel product) {
    state = [
      for (final item in state)
        if (item.id == product.id) product else item,
    ];
    _hydrated.then((_) {
      state = [
        for (final item in state)
          if (item.id == product.id) product else item,
      ];
      _persist();
      db?.persistProductRecord(product.id, product.code, product.name, product.sellPrice);
    });
  }

  void deleteProduct(String id) {
    state = state.where((item) => item.id != id).toList();
    _hydrated.then((_) {
      state = state.where((item) => item.id != id).toList();
      _persist();
    });
  }
}
