import 'dart:convert';

import 'package:factor_ruby/core/utils/prefs_store.dart';
import 'package:factor_ruby/models/app_settings_model.dart';
import 'package:factor_ruby/models/invoice_model.dart';
import 'package:factor_ruby/models/user_model.dart';
import 'package:factor_ruby/providers/app_providers.dart';
import 'package:factor_ruby/providers/bank_card_provider.dart';
import 'package:factor_ruby/providers/invoice_provider.dart';
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

  test('bank logo assets include the correct official logos', () {
    expect(bankLogoAsset('بانک توسعه صادرات'), endsWith('toseesaderat.webp'));
    expect(bankLogoAsset('بانک صادرات'), endsWith('/saderat.webp'));
    expect(bankLogoAsset('بانک رفاه کارگران'), endsWith('/refah.png'));
    expect(
      bankLogoAsset('بانک قرض الحسنه مهر'),
      endsWith('/mehriran.png'),
    );
    expect(
      bankLogoAsset('بانک قرض‌الحسنه مهر ایران'),
      endsWith('/mehriran.png'),
    );
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

  test('cash conversion settles the resulting sales invoice', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = InvoiceListNotifier();
    await notifier.ensureLoaded();
    await notifier.saveInvoice(
      invoice(type: 'proforma', status: 'proforma'),
    );

    await notifier.convertProformaToInvoice(
      'src',
      paymentType: 'cash',
    );

    final converted = notifier.state.single;
    expect(converted.type, 'sale');
    expect(converted.paymentType, 'cash');
    expect(converted.paidAmount, 80);
    expect(converted.remainingAmount, 0);
    expect(converted.status, 'paid');
    notifier.dispose();
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
    expect(detectBankName('6037981234567890'), isEmpty);
  });

  test('invoice visibility toggles preserve unrelated settings', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = SettingsNotifier();

    await notifier.updateSettings(
      notifier.state.copyWith(
        startingInvoiceNum: 42,
        accentColor: 0xFF123456,
        showStamp: true,
        showSignature: true,
        showCardNum: true,
      ),
    );

    await notifier.updateInvoiceVisibility(showStamp: false);
    expect(notifier.state.showStamp, isFalse);
    expect(notifier.state.showSignature, isFalse);
    expect(notifier.state.showCardNum, isTrue);
    expect(notifier.state.startingInvoiceNum, 42);
    expect(notifier.state.accentColor, 0xFF123456);

    await notifier.updateInvoiceVisibility(showCardNum: false);
    expect(notifier.state.showStamp, isFalse);
    expect(notifier.state.showCardNum, isFalse);
    expect(notifier.state.startingInvoiceNum, 42);
    notifier.dispose();
  });

  test('clearing a draft also clears its recovery shadow copy', () async {
    SharedPreferences.setMockInitialValues({});
    await PrefsStore.saveDraft(invoice());
    expect(await PrefsStore.loadDraft(), isNotNull);

    await PrefsStore.clearDraft();

    expect(await PrefsStore.loadDraft(), isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('ruby_invoice_draft_v1'), isFalse);
    expect(
      preferences.containsKey('ruby_invoice_draft_v1_last_good'),
      isFalse,
    );
  });

  test('ledger recovers when primary value is missing', () async {
    final encoded = jsonEncode({
      'inv-1': {
        'customerId': 'c1',
        'impact': 25.0,
        'referenceImpact': 30.0,
      },
    });
    SharedPreferences.setMockInitialValues({
      'ruby_invoice_balance_ledger_v1_last_good': encoded,
    });

    final ledger = await PrefsStore.loadInvoiceBalanceLedger();

    expect(ledger['inv-1']?['customerId'], 'c1');
    expect(ledger['inv-1']?['impact'], 25.0);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('ruby_invoice_balance_ledger_v1'),
      encoded,
    );
  });

  test('signature and stamp settings deserialize independently', () {
    final settings = AppSettingsModel.fromMap({
      'startingInvoiceNum': 1,
      'templateStyle': 'modern',
      'showLogo': true,
      'showCardNum': true,
      'showStamp': false,
      'showSignature': true,
      'officialInvoiceEnabled': true,
      'defaultTaxRate': 10,
      'themeMode': 'light',
      'autoBackup': true,
      'pinCode': '',
      'pinEnabled': false,
    });

    expect(settings.showStamp, isFalse);
    expect(settings.showSignature, isTrue);
    expect(settings.officialInvoiceEnabled, isTrue);
    expect(settings.defaultTaxRate, 10);
  });

  test('premium and official invoice fields survive persistence', () {
    final user = UserModel.fromMap({
      'id': 'u1',
      'name': 'کاربر',
      'country': 'ایران',
      'province': '',
      'city': 'تهران',
      'usageType': 'store',
      'isOnboarded': true,
      'isPremium': true,
    });
    expect(user.isPremium, isTrue);
    expect(UserModel.fromMap(user.toMap()).isPremium, isTrue);

    final map = invoice().toMap()
      ..addAll({
        'isOfficial': true,
        'taxRate': 10.0,
        'taxAmount': 10.0,
        'sellerNationalId': '123',
        'buyerNationalId': '456',
      });
    final restored = InvoiceModel.fromMap(map);
    expect(restored.isOfficial, isTrue);
    expect(restored.taxRate, 10);
    expect(restored.taxAmount, 10);
    expect(restored.sellerNationalId, '123');
    expect(restored.buyerNationalId, '456');
  });
}
