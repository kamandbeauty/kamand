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

  Future<void> _persist() async {
    await PrefsStore.saveCustomers(state);
  }

  Future<void> addCustomer(CustomerModel customer) async {
    await _hydrated;
    state = [...state, customer];
    await PrefsStore.saveCustomers(state);
    db?.persistCustomerRecord(customer.id, customer.name, customer.balance, customer.createdAt);
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    await _hydrated;
    state = [
      for (final item in state)
        if (item.id == customer.id) customer else item,
    ];
    await _persist();
    db?.persistCustomerRecord(customer.id, customer.name, customer.balance, customer.createdAt);
  }

  Future<void> deleteCustomer(String id) async {
    await _hydrated;
    state = state.where((item) => item.id != id).toList();
    await _persist();
  }

  Future<void> recordPayment(String id, double amount) async {
    await _hydrated;
    if (amount <= 0) return;
    state = state.map((item) {
      if (item.id != id) return item;
      return _withBalance(item, (item.balance - amount).clamp(0, double.infinity).toDouble());
    }).toList();
    await _persist();
  }

  Future<void> updateBalance(String id, double delta) async {
    await _hydrated;
    state = state.map((item) {
      if (item.id != id) return item;
      return _withBalance(item, (item.balance + delta).clamp(0, double.infinity).toDouble());
    }).toList();
    await _persist();
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
