import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:factor_ruby/core/utils/persistent_list.dart';
import 'package:factor_ruby/core/utils/prefs_store.dart';
import 'package:factor_ruby/providers/customer_provider.dart';
import 'package:factor_ruby/providers/invoice_provider.dart';

/// نگه‌دارنده‌ی آزمایشی با تأخیر در خواندن اولیه، برای شبیه‌سازی همان لحظه‌ای
/// که کاربر روی نسخه‌ی تازه کلیک می‌کند ولی داده هنوز از حافظه خوانده نشده است.
class _SlowNotifier extends PersistentListNotifier<int> {
  _SlowNotifier(this.initial, {this.delay = const Duration(milliseconds: 40)});

  final List<int> initial;
  final Duration delay;
  final List<List<int>> writes = <List<int>>[];

  @override
  Future<List<int>> readFromStorage() async {
    await Future<void>.delayed(delay);
    return List<int>.from(initial);
  }

  @override
  Future<void> writeToStorage(List<int> items) async {
    writes.add(List<int>.from(items));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('نوشتن/خواندن لیست‌های ذخیره‌شده', () {
    test('تغییر کاربر پیش از پایان خواندن اولیه گم نمی‌شود و دو بار اعمال نمی‌شود', () async {
      final notifier = _SlowNotifier(<int>[1, 2]);
      notifier.mutate((items) => [...items, 3]);
      await notifier.ensureLoaded();
      await notifier.flushWrites();

      expect(notifier.state, <int>[1, 2, 3]);
      expect(notifier.writes.last, <int>[1, 2, 3]);
    });

    test('چند تغییر سریع پیش از خواندن اولیه همه حفظ می‌شوند', () async {
      final notifier = _SlowNotifier(<int>[1]);
      notifier.mutate((items) => [...items, 2]);
      notifier.mutate((items) => [...items, 3]);
      notifier.mutate((items) => [...items, 4]);
      await notifier.ensureLoaded();
      await notifier.flushWrites();

      expect(notifier.state, <int>[1, 2, 3, 4]);
      expect(notifier.writes.last, <int>[1, 2, 3, 4]);
    });

    test('نوشتن‌ها به ترتیب انجام می‌شوند و آخرین وضعیت ذخیره می‌شود', () async {
      final notifier = _SlowNotifier(<int>[], delay: Duration.zero);
      await notifier.ensureLoaded();
      notifier.mutate((items) => [...items, 1]);
      notifier.mutate((items) => [...items, 2]);
      notifier.mutate((items) => [...items, 3]);
      await notifier.flushWrites();

      expect(notifier.state, <int>[1, 2, 3]);
      expect(notifier.writes.last, <int>[1, 2, 3]);
      expect(notifier.writes.length, 3, reason: 'هر تغییر یک نوشتن دارد');
    });
  });

  group('مانده‌حساب مشتریان', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PrefsStore.kCustomers: jsonEncode(<dynamic>[
          <String, dynamic>{
            'id': 'c1',
            'name': 'مشتری',
            'mobile': '',
            'phone': '',
            'address': '',
            'notes': '',
            'balance': 100000,
            'createdAt': '1403/01/01',
          },
        ]),
      });
    });

    test('افزایش مانده‌حساب فقط یک بار اعمال و ذخیره می‌شود', () async {
      final notifier = CustomerListNotifier();
      // بدون انتظار برای خواندن اولیه؛ دقیقاً همان حالتی که در نسخه‌ی قبل
      // باعث دو برابر شدن مبلغ می‌شد.
      notifier.updateBalance('c1', 50000);
      await notifier.ensureLoaded();
      await notifier.flushWrites();

      expect(notifier.state.first.balance, 150000);

      final stored = jsonDecode((await SharedPreferences.getInstance()).getString(PrefsStore.kCustomers)!);
      expect((stored as List).first['balance'], 150000);
    });

    test('ثبت دریافت از مشتری بیش از مانده‌حساب ثبت نمی‌شود', () async {
      final notifier = CustomerListNotifier();
      notifier.recordPayment('c1', 500000);
      await notifier.ensureLoaded();
      await notifier.flushWrites();

      expect(notifier.state.first.balance, 0);
    });
  });

  group('فاکتورها', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PrefsStore.kInvoices: jsonEncode(<dynamic>[
          <String, dynamic>{
            'id': 'inv-1',
            'number': '1001',
            'customerId': 'c1',
            'customerName': 'مشتری',
            'type': 'sale',
            'paymentType': 'non_cash',
            'status': 'unpaid',
            'date': '1403/01/01',
            'items': <dynamic>[],
            'totalAmount': 200000,
            'paidAmount': 0,
            'remainingAmount': 200000,
            'createdAt': '1403/01/01',
          },
        ]),
      });
    });

    test('ثبت دریافت روی فاکتور یک بار حساب می‌شود و به دیسک می‌رود', () async {
      final notifier = InvoiceListNotifier();
      notifier.recordPayment('inv-1', 50000);
      await notifier.ensureLoaded();
      await notifier.flushWrites();

      final invoice = notifier.state.first;
      expect(invoice.paidAmount, 50000);
      expect(invoice.remainingAmount, 150000);
      expect(invoice.status, 'partial');
    });

    test('پیش‌فاکتور با یک بار اجرا به فاکتور فروش تبدیل می‌شود', () async {
      final notifier = InvoiceListNotifier();
      notifier.convertProformaToInvoice('inv-1');
      await notifier.ensureLoaded();
      await notifier.flushWrites();
      notifier.convertProformaToInvoice('inv-1');
      await notifier.flushWrites();

      expect(notifier.state.first.type, 'sale');
      expect(notifier.state.first.paidAmount, 0);
    });
  });

  test('ProviderScope می‌تواند نگه‌دارنده‌ها را بسازد', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(customerListProvider), isEmpty);
  });
}
