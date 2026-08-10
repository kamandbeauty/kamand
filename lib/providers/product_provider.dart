import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_model.dart';

final productListProvider =
    StateNotifierProvider<ProductListNotifier, List<ProductModel>>((ref) {
  return ProductListNotifier();
});

class ProductListNotifier extends StateNotifier<List<ProductModel>> {
  ProductListNotifier()
      : super([
          ProductModel(
            id: 'p1',
            code: '101',
            name: 'دان قهوه اسپرسو برزیل (۱ کیلویی)',
            unit: 'بسته',
            buyPrice: 380000,
            sellPrice: 520000,
            stock: 24,
            notes: 'برشتگی مدیوم دارک',
          ),
          ProductModel(
            id: 'p2',
            code: '102',
            name: 'ماگ سرامیکی طرح فیدا',
            unit: 'عدد',
            buyPrice: 85000,
            sellPrice: 140000,
            stock: 50,
            notes: 'گنجایش ۳۵۰ سی‌سی',
          ),
          ProductModel(
            id: 'p3',
            code: '103',
            name: 'دستگاه اسپرسوساز خانگی مدل FID-200',
            unit: 'دستگاه',
            buyPrice: 4200000,
            sellPrice: 5800000,
            stock: 6,
            notes: 'دارای ۱۸ ماه گارانتی شرکتی',
          ),
          ProductModel(
            id: 'p4',
            code: '104',
            name: 'خدمات سرویس و نگه‌داری دوره‌ای',
            unit: 'ساعت',
            buyPrice: 0,
            sellPrice: 350000,
            stock: 999,
            notes: 'توسط تکنسین مجرب',
          ),
        ]);

  void addProduct(ProductModel product) {
    state = [...state, product];
  }

  void updateProduct(ProductModel product) {
    state = [
      for (final item in state)
        if (item.id == product.id) product else item,
    ];
  }

  void deleteProduct(String id) {
    state = state.where((item) => item.id != id).toList();
  }
}
