import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/prefs_store.dart';
import '../models/bank_card_model.dart';

final bankCardListProvider = StateNotifierProvider<BankCardListNotifier, List<BankCardModel>>((ref) {
  return BankCardListNotifier();
});

final selectedBankCardProvider = StateNotifierProvider<SelectedBankCardNotifier, BankCardModel?>((ref) {
  final notifier = SelectedBankCardNotifier(ref);
  ref.listen<List<BankCardModel>>(bankCardListProvider, (_, cards) {
    notifier.sync(cards);
  }, fireImmediately: true);
  return notifier;
});

class BankCardListNotifier extends StateNotifier<List<BankCardModel>> {
  BankCardListNotifier() : super(const []) {
    _hydrate();
  }

  Future<void> _hydrate() async {
    state = await PrefsStore.loadBankCards();
  }

  void _persist() {
    PrefsStore.saveBankCards(state);
  }

  void addCard(BankCardModel c) {
    state = [...state, c];
    _persist();
  }

  void updateCard(BankCardModel c) {
    state = [for (final e in state) if (e.id == c.id) c else e];
    _persist();
  }

  void deleteCard(String id) {
    state = state.where((e) => e.id != id).toList();
    _persist();
  }
}

class SelectedBankCardNotifier extends StateNotifier<BankCardModel?> {
  final Ref ref;
  String? _selectedId;

  SelectedBankCardNotifier(this.ref) : super(null) {
    _loadSelectedId();
  }

  Future<void> _loadSelectedId() async {
    _selectedId = await PrefsStore.loadSelectedBankCardId();
    sync(ref.read(bankCardListProvider));
  }

  void sync(List<BankCardModel> cards) {
    if (cards.isEmpty) {
      state = null;
      return;
    }
    final selected = cards.where((c) => c.id == _selectedId).toList();
    if (selected.isNotEmpty) {
      state = selected.first;
    } else if (state == null) {
      // اگر انتخاب قبلی وجود نداشت، اولین کارت انتخاب می‌شود.
      state = cards.first;
      _selectedId = cards.first.id;
      PrefsStore.saveSelectedBankCardId(cards.first.id);
    }
  }

  void select(BankCardModel card) {
    _selectedId = card.id;
    state = card;
    PrefsStore.saveSelectedBankCardId(card.id);
  }
}

// Helper: detect bank by BIN (first 6 digits)
String detectBankName(String cardNumber){
  final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
  if(digits.length < 6) return '';
  final bin = digits.substring(0,6);
  const map = {
    '610433': 'بانک ملت',
    '603799': 'بانک ملی',
    '589210': 'بانک سپه',
    '627648': 'بانک توسعه صادرات',
    '627961': 'بانک صنعت و معدن',
    '603770': 'بانک کشاورزی',
    '628023': 'بانک مسکن',
    '627760': 'بانک پست بانک',
    '502229': 'بانک پاسارگاد',
    '627412': 'بانک اقتصاد نوین',
    '622106': 'بانک پارسیان',
    '627488': 'بانک کارآفرین',
    '621986': 'بانک سامان',
    '639346': 'بانک سینا',
    '639607': 'بانک سرمایه',
    '502806': 'بانک شهر',
    '502908': 'بانک توسعه تعاون',
    '603769': 'بانک صادرات',
    '627353': 'بانک تجارت',
    '589463': 'بانک رفاه',
    '627381': 'بانک انصار',
    '505785': 'بانک ایران زمین',
    '636214': 'بانک آینده',
    '636949': 'بانک حکمت',
    '505416': 'بانک گردشگری',
    '606373': 'بانک قرض الحسنه مهر',
  };
  if(map.containsKey(bin)) return map[bin]!;
  final bin4 = digits.substring(0,4);
  const map4 = {'6104':'بانک ملت','6037':'بانک ملی','5892':'بانک سپه'};
  return map4[bin4] ?? 'بانک ${bin.substring(0,4)}';
}

String bankLogoAsset(String bankName){
  if(bankName.contains('ملت')) return 'assets/images/banks/mellat.webp';
  if(bankName.contains('ملی')) return 'assets/images/banks/melli.webp';
  if(bankName.contains('صادرات')) return 'assets/images/banks/saderat.webp';
  if(bankName.contains('تجارت')) return 'assets/images/banks/tejarat.webp';
  if(bankName.contains('سپه')) return 'assets/images/banks/sepah.webp';
  if(bankName.contains('کشاورزی')) return 'assets/images/banks/keshavarzi.webp';
  if(bankName.contains('پارسیان')) return 'assets/images/banks/parsian.webp';
  if(bankName.contains('مسکن')) return 'assets/images/banks/maskan.webp';
  if(bankName.contains('پست بانک')) return 'assets/images/banks/post.webp';
  if(bankName.contains('اقتصاد نوین')) return 'assets/images/banks/eghtesad.webp';
  if(bankName.contains('کارآفرین')) return 'assets/images/banks/karafarin.webp';
  if(bankName.contains('سینا')) return 'assets/images/banks/sina.webp';
  if(bankName.contains('سرمایه')) return 'assets/images/banks/sarmayeh.webp';
  if(bankName.contains('شهر')) return 'assets/images/banks/shahr.webp';
  if(bankName.contains('دی')) return 'assets/images/banks/day.webp';
  if(bankName.contains('پاسارگاد')) return 'assets/images/banks/pasargad.webp';
  if(bankName.contains('سامان')) return 'assets/images/banks/saman.webp';
  if(bankName.contains('انصار')) return 'assets/images/banks/ansar.webp';
  if(bankName.contains('توسعه تعاون')) return 'assets/images/banks/taavon.webp';
  if(bankName.contains('قوامین')) return 'assets/images/banks/ghavamin.webp';
  if(bankName.contains('حکمت')) return 'assets/images/banks/hekmat.webp';
  if(bankName.contains('ایران زمین')) return 'assets/images/banks/iranzamin.webp';
  if(bankName.contains('گردشگری')) return 'assets/images/banks/gardeshgari.webp';
  if(bankName.contains('صنعت و معدن')) return 'assets/images/banks/sanatmadan.webp';
  if(bankName.contains('توسعه صادرات')) return 'assets/images/banks/toseesaderat.webp';
  if(bankName.contains('مهر اقتصاد')) return 'assets/images/banks/mehreEghtesad.webp';
  if(bankName.contains('ایران ونزوئلا') || bankName.contains('ایران و ونزوئلا')) return 'assets/images/banks/iranvenezuela.webp';
  if(bankName.contains('رسالت')) return 'assets/images/banks/resalat.webp';
  if(bankName.contains('ملل')) return 'assets/images/banks/melal.webp';
  if(bankName.contains('آینده')) return 'assets/images/banks/ayandeh.webp';
  return '';
}

Color bankColor(String bankName){
  const colors = {
    'بانک ملت': Color(0xFFD32F2F),
    'بانک ملی': Color(0xFF2E7D32),
    'بانک پاسارگاد': Color(0xFFF9A825),
    'بانک پارسیان': Color(0xFF1565C0),
    'بانک سامان': Color(0xFF0288D1),
    'بانک سپه': Color(0xFF37474F),
    'بانک تجارت': Color(0xFF00897B),
    'بانک صادرات': Color(0xFF283593),
    'بانک سینا': Color(0xFFAD1457),
    'بانک شهر': Color(0xFF2E7D32),
  };
  return colors[bankName] ?? const Color(0xFF607D8B);
}
