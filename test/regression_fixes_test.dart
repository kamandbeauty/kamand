import 'package:factor_ruby/models/invoice_model.dart';
import 'package:factor_ruby/providers/bank_card_provider.dart';
import 'package:factor_ruby/providers/invoice_provider.dart';
import 'package:factor_ruby/screens/invoice/invoice_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  InvoiceModel invoice({
    String type = 'sale',
    String paymentType = 'non_cash',
    double paid = 50,
    double remaining = 50,
    String status = 'partial',
  }) {
    return InvoiceModel(
      id: 'src',
      number: '5',
      customerId: 'c1',
      customerName: 'مشتری',
      customerPhone: '',
      type: type,
      paymentType: paymentType,
      status: status,
      date: '1405/01/01',
      items: const [],
      subtotal: 100,
      discountPercent: 0,
      discountAmount: 0,
      shippingFee: 0,
      previousDebt: 0,
      deposit: 20,
      totalAmount: 80,
      paidAmount: paid,
      remainingAmount: remaining,
      notes: '',
      cardNumber: '',
      createdAt: '1405/01/01',
    );
  }

  test('unknown card BIN does not invent a bank name', () {
    expect(detectBankName('9999991234567890'), '');
    expect(detectBankName('6104337912345678'), 'بانک ملت');
  });

  test('bank names from BIN detection match the selectable bank list', () {
    expect(detectBankName('6277601234567890'), 'پست بانک');
    expect(detectBankName('6369491234567890'), 'بانک حکمت ایرانیان');
  });

  test('Tosee Saderat gets its own logo, not Saderat', () {
    expect(bankLogoAsset('بانک توسعه صادرات'), endsWith('toseesaderat.webp'));
    expect(bankLogoAsset('بانک صادرات'), endsWith('/saderat.webp'));
  });

  test('copying an invoice does not inherit recorded payments', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = InvoiceListNotifier();
    await notifier.ensureLoaded();

    final copy = await notifier.copyInvoice(invoice());

    expect(copy.paidAmount, 20); // only the deposit
    expect(copy.remainingAmount, 80);
    expect(copy.status, 'partial');
    notifier.dispose();
  });

  test('non-cash conversion restores the invoice balance and deposit', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = InvoiceListNotifier();
    await notifier.ensureLoaded();
    await notifier.saveInvoice(
      invoice(
        type: 'proforma',
        paymentType: 'cash',
        paid: 80,
        remaining: 0,
        status: 'proforma',
      ),
    );

    await notifier.convertProformaToInvoice(
      'src',
      paymentType: 'non_cash',
    );

    final converted = notifier.state.single;
    expect(converted.type, 'sale');
    expect(converted.paymentType, 'non_cash');
    expect(converted.paidAmount, 20);
    expect(converted.remainingAmount, 80);
    expect(converted.status, 'partial');
    notifier.dispose();
  });

  testWidgets('conversion asks for payment type and cancel changes nothing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = InvoiceListNotifier();
    await notifier.ensureLoaded();
    await notifier.saveInvoice(
      invoice(type: 'proforma', status: 'proforma'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invoiceListProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(home: InvoiceListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('تبدیل به فاکتور فروش'));
    await tester.pumpAndSettle();
    expect(find.text('نوع پرداخت فاکتور فروش'), findsOneWidget);
    expect(find.text('نقدی'), findsOneWidget);
    expect(find.text('غیرنقدی'), findsOneWidget);

    await tester.tap(find.text('انصراف'));
    await tester.pumpAndSettle();
    expect(notifier.state.single.type, 'proforma');

    await tester.tap(find.text('تبدیل به فاکتور فروش'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نقدی'));
    await tester.pumpAndSettle();

    final converted = notifier.state.single;
    expect(converted.type, 'sale');
    expect(converted.paymentType, 'cash');
    expect(converted.paidAmount, 80);
    expect(converted.remainingAmount, 0);
    expect(converted.status, 'paid');
  });

  test('recording a payment is capped at the remaining invoice balance', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = InvoiceListNotifier();
    await notifier.ensureLoaded();
    await notifier.saveInvoice(invoice());

    await notifier.recordPayment('src', 500);

    expect(notifier.state.single.paidAmount, 100);
    expect(notifier.state.single.remainingAmount, 0);
    expect(notifier.state.single.status, 'paid');
    notifier.dispose();
  });

  test('new supported BINs resolve to selectable bank names', () {
    expect(detectBankName('5029381234567890'), 'بانک دی');
    expect(detectBankName('5047061234567890'), 'بانک شهر');
    expect(detectBankName('6062561234567890'), 'موسسه ملل');
    expect(detectBankName('6063731234567890'), 'بانک قرض الحسنه مهر');
  });
}
