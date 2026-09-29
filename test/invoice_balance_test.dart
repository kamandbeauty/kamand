import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:factor_ruby/core/utils/prefs_store.dart';
import 'package:factor_ruby/models/customer_model.dart';
import 'package:factor_ruby/models/invoice_model.dart';
import 'package:factor_ruby/providers/customer_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  InvoiceModel invoice({
    required String id,
    double remaining = 100,
    double previousDebt = 0,
    String type = 'sale',
    String paymentType = 'non_cash',
  }) {
    return InvoiceModel(
      id: id,
      number: '1',
      customerId: 'customer-1',
      customerName: 'مشتری',
      customerPhone: '09120000000',
      type: type,
      paymentType: paymentType,
      status: remaining == 0 ? 'paid' : 'unpaid',
      date: '1405/01/01',
      items: const [],
      subtotal: remaining,
      discountPercent: 0,
      discountAmount: 0,
      shippingFee: 0,
      previousDebt: previousDebt,
      deposit: 0,
      totalAmount: remaining,
      paidAmount: 0,
      remainingAmount: remaining,
      notes: '',
      cardNumber: '',
      createdAt: '1405/01/01',
    );
  }

  CustomerModel customer({double balance = 0}) => CustomerModel(
        id: 'customer-1',
        name: 'مشتری',
        mobile: '09120000000',
        phone: '',
        address: '',
        notes: '',
        balance: balance,
        createdAt: '1405/01/01',
      );

  test('previous debt is not counted twice', () {
    expect(invoice(id: '1', remaining: 150, previousDebt: 50).customerBalanceImpact, 100);
    expect(invoice(id: '2', type: 'proforma').customerBalanceImpact, 0);
    expect(invoice(id: '3', paymentType: 'cash').customerBalanceImpact, 0);
  });

  test('new invoice balance is added, edited by delta, and removed', () async {
    SharedPreferences.setMockInitialValues({});
    await PrefsStore.saveCustomers([customer()]);
    final notifier = CustomerListNotifier();
    await notifier.ensureLoaded();

    final first = invoice(id: 'new', remaining: 100);
    await notifier.applyInvoiceChange(null, first);
    expect(notifier.state.single.balance, 100);

    final edited = invoice(id: 'new', remaining: 140);
    await notifier.applyInvoiceChange(first, edited);
    expect(notifier.state.single.balance, 140);

    await notifier.applyInvoiceChange(edited, null);
    expect(notifier.state.single.balance, 0);
    notifier.dispose();
  });

  test('legacy invoice establishes a baseline without changing old balances', () async {
    SharedPreferences.setMockInitialValues({});
    await PrefsStore.saveCustomers([customer(balance: 75)]);
    final notifier = CustomerListNotifier();
    await notifier.ensureLoaded();

    final oldInvoice = invoice(id: 'legacy', remaining: 100);
    final firstEdit = invoice(id: 'legacy', remaining: 120);
    await notifier.applyInvoiceChange(oldInvoice, firstEdit);
    expect(notifier.state.single.balance, 75);

    final secondEdit = invoice(id: 'legacy', remaining: 130);
    await notifier.applyInvoiceChange(firstEdit, secondEdit);
    expect(notifier.state.single.balance, 85);
    notifier.dispose();
  });
}
