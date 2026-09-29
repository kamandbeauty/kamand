import 'package:factor_ruby/core/utils/persian_number_formatter.dart';
import 'package:factor_ruby/core/utils/prefs_store.dart';
import 'package:factor_ruby/core/utils/thousand_separator_formatter.dart';
import 'package:factor_ruby/models/customer_model.dart';
import 'package:factor_ruby/models/invoice_model.dart';
import 'package:factor_ruby/providers/invoice_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  InvoiceModel invoice({
    String id = 'invoice-1',
    double total = 80,
    double paid = 20,
    double remaining = 80,
  }) {
    return InvoiceModel(
      id: id,
      number: '۱۰۰۱',
      customerId: 'customer-1',
      customerName: 'مشتری',
      customerPhone: '09120000000',
      type: 'sale',
      paymentType: 'non_cash',
      status: 'partial',
      date: '۱۴۰۵/۰۱/۰۱',
      items: const [],
      subtotal: 100,
      discountPercent: 0,
      discountAmount: 0,
      shippingFee: 0,
      previousDebt: 0,
      deposit: 20,
      totalAmount: total,
      paidAmount: paid,
      remainingAmount: remaining,
      notes: '',
      cardNumber: '',
      createdAt: '۱۴۰۵/۰۱/۰۱',
    );
  }

  test('number formatter accepts Persian digits and separators', () {
    expect(ThousandSeparatorInputFormatter.parseToDouble('۱٬۲۳۴٫۵'), 1234.5);
    expect(ThousandSeparatorInputFormatter.parseToDouble('۱,۲۳۴.۵'), 1234.5);
    expect(
      ThousandSeparatorInputFormatter.formatDisplay('1234567'),
      '۱,۲۳۴,۵۶۷',
    );
    expect(PersianNumberFormatter.toPersian('Invoice 120'), 'Invoice ۱۲۰');
  });

  test('recording payment reduces remaining directly and not deposit twice', () async {
    SharedPreferences.setMockInitialValues({});
    await PrefsStore.saveInvoices([invoice()]);
    final notifier = InvoiceListNotifier();
    await notifier.ensureLoaded();

    await notifier.recordPayment('invoice-1', 10);

    expect(notifier.state.single.paidAmount, 30);
    expect(notifier.state.single.remainingAmount, 70);
    notifier.dispose();
  });

  test('malformed backup is rejected before existing data changes', () async {
    SharedPreferences.setMockInitialValues({});
    final existing = CustomerModel(
      id: 'existing',
      name: 'مشتری فعلی',
      mobile: '',
      phone: '',
      address: '',
      notes: '',
      balance: 42,
      createdAt: '1405/01/01',
    );
    await PrefsStore.saveCustomers([existing]);

    final malformed = <String, dynamic>{
      'schemaVersion': 2,
      'user': null,
      'business': null,
      'settings': null,
      'draft': null,
      'invoices': [
        {
          ...invoice().toMap(),
          'subtotal': 'not-a-number',
        },
      ],
      'customers': <dynamic>[],
      'products': <dynamic>[],
      'bankCards': <dynamic>[],
      'selectedBankCardId': null,
      'invoiceBalanceLedger': <String, dynamic>{},
    };

    await expectLater(
      PrefsStore.importAll(malformed),
      throwsA(anything),
    );
    final customers = await PrefsStore.loadCustomers();
    expect(customers.single.id, 'existing');
    expect(customers.single.balance, 42);
  });
}
