import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/persistent_list.dart';
import '../core/utils/prefs_store.dart';
import '../database/app_database.dart';
import '../models/product_model.dart';

final productListProvider =
    StateNotifierProvider<ProductListNotifier, List<ProductModel>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProductListNotifier(db);
});

class ProductListNotifier extends PersistentListNotifier<ProductModel> {
  ProductListNotifier([this.db]);

  final AppDatabase? db;

  @override
  Future<List<ProductModel>> readFromStorage() => PrefsStore.loadProducts();

  @override
  Future<void> writeToStorage(List<ProductModel> items) async {
    await PrefsStore.saveProducts(items);
    await db?.mirrorProducts(items);
  }

  void addProduct(ProductModel product) {
    mutate(
      (products) => products.any((item) => item.id == product.id)
          ? products
          : [...products, product],
    );
  }

  void updateProduct(ProductModel product) {
    mutate(
      (products) => [
        for (final item in products)
          if (item.id == product.id) product else item,
      ],
    );
  }

  void deleteProduct(String id) {
    mutate((products) => products.where((item) => item.id != id).toList());
  }
}
