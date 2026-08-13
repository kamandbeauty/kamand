import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer_model.dart';
import '../core/utils/prefs_store.dart';
import '../database/app_database.dart';

final customerListProvider =
    StateNotifierProvider<CustomerListNotifier, List<CustomerModel>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CustomerListNotifier(db);
});

class CustomerListNotifier extends StateNotifier<List<CustomerModel>> {
  final AppDatabase? db;
  late final Future<void> _hydrated;

  CustomerListNotifier([this.db]) : super(const []) {
    _hydrated = _hydrate();
  }

  Future<void> ensureLoaded() => _hydrated;

  Future<void> _hydrate() async {
    state = await PrefsStore.loadCustomers();
  }

  void _persist() {
    PrefsStore.saveCustomers(state);
  }

  Future<void> addCustomer(CustomerModel customer) async {
    // تضمین کن اولین ذخیره بعد از hydrate شدن فهرست قبلی انجام شود.
    await _hydrated;
    state = [...state, customer];
    await PrefsStore.saveCustomers(state);
    db?.persistCustomerRecord(customer.id, customer.name, customer.balance, customer.createdAt);
  }

  void updateCustomer(CustomerModel customer) {
    state = [
      for (final item in state)
        if (item.id == customer.id) customer else item,
    ];
    _persist();
    db?.persistCustomerRecord(customer.id, customer.name, customer.balance, customer.createdAt);
  }

  void deleteCustomer(String id) {
    state = state.where((item) => item.id != id).toList();
    _persist();
  }

  void recordPayment(String id, double amount) {
    state = state.map((item) {
      if (item.id != id) return item;
      return _withBalance(item, (item.balance - amount).clamp(0, double.infinity).toDouble());
    }).toList();
    _persist();
  }

  void updateBalance(String id, double delta) {
    state = state.map((item) {
      if (item.id != id) return item;
      return _withBalance(item, (item.balance + delta).clamp(0, double.infinity).toDouble());
    }).toList();
    _persist();
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
