import 'package:factor_ruby/core/utils/prefs_store.dart';
import 'package:factor_ruby/models/bank_card_model.dart';
import 'package:factor_ruby/providers/bank_card_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BankCardModel card(String id) => BankCardModel(
        id: id,
        cardNumber: id == 'first'
            ? '6037997512345678'
            : '6104337912345678',
        sheba: '',
        bankName: id == 'first' ? 'بانک ملی' : 'بانک ملت',
        persianName: 'صاحب کارت',
      );

  test('persisted card selection is not overwritten during hydration', () async {
    SharedPreferences.setMockInitialValues({});
    await PrefsStore.saveBankCards([card('first'), card('second')]);
    await PrefsStore.saveSelectedBankCardId('second');

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(selectedBankCardProvider);
    await container.read(bankCardListProvider.notifier).ensureLoaded();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(container.read(selectedBankCardProvider)?.id, 'second');
  });

  test('deleted selection falls back to a card still in the list', () async {
    SharedPreferences.setMockInitialValues({});
    await PrefsStore.saveBankCards([card('first'), card('second')]);
    await PrefsStore.saveSelectedBankCardId('second');

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(selectedBankCardProvider);
    await container.read(bankCardListProvider.notifier).ensureLoaded();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await container.read(bankCardListProvider.notifier).deleteCard('second');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(container.read(selectedBankCardProvider)?.id, 'first');
  });
}
