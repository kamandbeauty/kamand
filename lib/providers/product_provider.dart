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

  // قلاب‌های لایهٔ فروشگاه (اختیاری؛ برای همگام‌سازی موجودی)
  void Function(String productId)? _onProductAdded;

  ProductListNotifier([this.db]) : super(const []) {
    _hydrate();
  }

  void attachHooks({void Function(String productId)? onProductAdded}) {
    _onProductAdded = onProductAdded;
  }

  /// تطبیق قلم فاکتور با کاتالوگ بر اساس نام
  String? findProductIdByTitle(String title) {
    final t = title.trim();
    if (t.isEmpty) return null;
    for (final p in state) {
      if (p.name.trim() == t) return p.id;
    }
    return null;
  }

  /// همگام‌سازی فیلد نمایشی موجودی با مقدار مشتق از InventoryRepository
  void applyDerivedStock(Map<String, double> stockByProductId) {
    var changed = false;
    final next = <ProductModel>[
      for (final item in state)
        () {
          final s = stockByProductId[item.id];
          if (s != null && s != item.stock) {
            changed = true;
            return ProductModel(
              id: item.id,
              code: item.code,
              name: item.name,
              unit: item.unit,
              buyPrice: item.buyPrice,
              sellPrice: item.sellPrice,
              stock: s,
              notes: item.notes,
            );
          }
          return item;
        }(),
    ];
    if (changed) {
      state = next;
      _persist();
    }
  }

  Future<void> _hydrate() async {
    state = await PrefsStore.loadProducts();
  }

  void _persist() {
    PrefsStore.saveProducts(state);
  }

  void addProduct(ProductModel product) {
    state = [...state, product];
    _persist();
    db?.persistProductRecord(product.id, product.code, product.name, product.sellPrice);
    _onProductAdded?.call(product.id);
  }

  void updateProduct(ProductModel product) {
    state = [
      for (final item in state)
        if (item.id == product.id) product else item,
    ];
    _persist();
    db?.persistProductRecord(product.id, product.code, product.name, product.sellPrice);
  }

  void deleteProduct(String id) {
    state = state.where((item) => item.id != id).toList();
    _persist();
  }
}
