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

  Future<void> _persist() async {
    await PrefsStore.saveProducts(state);
  }

  Future<void> addProduct(ProductModel product) async {
    await _hydrated;
    state = [...state, product];
    await _persist();
    db?.persistProductRecord(product.id, product.code, product.name, product.sellPrice);
  }

  Future<void> updateProduct(ProductModel product) async {
    await _hydrated;
    state = [
      for (final item in state)
        if (item.id == product.id) product else item,
    ];
    await _persist();
    db?.persistProductRecord(product.id, product.code, product.name, product.sellPrice);
  }

  Future<void> deleteProduct(String id) async {
    await _hydrated;
    state = state.where((item) => item.id != id).toList();
    await _persist();
  }
}
