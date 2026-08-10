import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer_model.dart';

final customerListProvider =
    StateNotifierProvider<CustomerListNotifier, List<CustomerModel>>((ref) {
  return CustomerListNotifier();
});

class CustomerListNotifier extends StateNotifier<List<CustomerModel>> {
  CustomerListNotifier()
      : super([
          CustomerModel(
            id: 'c1',
            name: 'رضا محمدی',
            mobile: '09121112233',
            phone: '02144556677',
            address: 'تهران، سعادت‌آباد، خیابان سرو غربی، پلاک ۴۵',
            notes: 'مشتری خوش‌حساب، تحویل حضوری',
            balance: 1500000,
            createdAt: '1405/05/15',
          ),
          CustomerModel(
            id: 'c2',
            name: 'زهرا کاظمی',
            mobile: '09359876543',
            phone: '02122334455',
            address: 'اصفهان، خیابان چهارباغ عباسی، مجتمع کوثر',
            notes: 'ارسال با پست پیشتاز',
            balance: 0,
            createdAt: '1405/05/18',
          ),
          CustomerModel(
            id: 'c3',
            name: 'شرکت پویاتک',
            mobile: '09129998877',
            phone: '02188776655',
            address: 'مشهد، بلوار سجاد، بزرگمهر شمالی، پلاک ۸',
            notes: 'خریدار عمده قطعات الکترونیک',
            balance: 4200000,
            createdAt: '1405/05/19',
          ),
        ]);

  void addCustomer(CustomerModel customer) {
    state = [...state, customer];
  }

  void updateCustomer(CustomerModel customer) {
    state = [
      for (final item in state)
        if (item.id == customer.id) customer else item,
    ];
  }

  void deleteCustomer(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void recordPayment(String id, double amount) {
    state = [
      for (final item in state)
        if (item.id == id)
          CustomerModel(
            id: item.id,
            name: item.name,
            mobile: item.mobile,
            phone: item.phone,
            address: item.address,
            notes: item.notes,
            balance: (item.balance - amount) < 0 ? 0 : item.balance - amount,
            createdAt: item.createdAt,
          )
        else
          item,
    ];
  }
}
