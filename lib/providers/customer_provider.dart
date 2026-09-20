import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/persistent_list.dart';
import '../core/utils/prefs_store.dart';
import '../database/app_database.dart';
import '../models/customer_model.dart';

final customerListProvider =
    StateNotifierProvider<CustomerListNotifier, List<CustomerModel>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CustomerListNotifier(db);
});

class CustomerListNotifier extends PersistentListNotifier<CustomerModel> {
  CustomerListNotifier([this.db]);

  final AppDatabase? db;

  @override
  Future<List<CustomerModel>> readFromStorage() => PrefsStore.loadCustomers();

  @override
  Future<void> writeToStorage(List<CustomerModel> items) async {
    await PrefsStore.saveCustomers(items);
    await db?.mirrorCustomers(items);
  }

  Future<void> addCustomer(CustomerModel customer) => mutateAsync(
        (customers) => customers.any((item) => item.id == customer.id)
            ? customers
            : [...customers, customer],
      );

  void updateCustomer(CustomerModel customer) {
    mutate(
      (customers) => [
        for (final item in customers)
          if (item.id == customer.id) customer else item,
      ],
    );
  }

  void deleteCustomer(String id) {
    mutate((customers) => customers.where((item) => item.id != id).toList());
  }

  /// ثبت دریافت از مشتری؛ مانده‌حساب دقیقاً یک بار کم می‌شود.
  void recordPayment(String id, double amount) {
    if (amount <= 0) return;
    mutate(
      (customers) => [
        for (final item in customers)
          if (item.id == id)
            _withBalance(item, (item.balance - amount).clamp(0, double.infinity).toDouble())
          else
            item,
      ],
    );
  }

  /// افزایش مانده‌حساب مشتری (مثلاً هنگام ثبت فاکتور غیرنقدی).
  /// مقدار [delta] فقط یک بار اعمال می‌شود و در به‌روزرسانی نسخه دو برابر نمی‌شود.
  void updateBalance(String id, double delta) {
    if (delta == 0) return;
    mutate(
      (customers) => [
        for (final item in customers)
          if (item.id == id)
            _withBalance(item, (item.balance + delta).clamp(0, double.infinity).toDouble())
          else
            item,
      ],
    );
  }

  CustomerModel _withBalance(CustomerModel item, double balance) => CustomerModel(
        id: item.id,
        name: item.name,
        mobile: item.mobile,
        phone: item.phone,
        address: item.address,
        notes: item.notes,
        balance: balance,
        createdAt: item.createdAt,
      );
}
