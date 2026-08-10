import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bank_card_model.dart';

final bankCardListProvider = StateNotifierProvider<BankCardListNotifier, List<BankCardModel>>((ref)=> BankCardListNotifier());
final selectedBankCardProvider = StateProvider<BankCardModel?>((ref)=> null);

class BankCardListNotifier extends StateNotifier<List<BankCardModel>> {
  BankCardListNotifier(): super([]);

  void addCard(BankCardModel c){
    state = [...state, c];
  }
  void updateCard(BankCardModel c){
    state = [for(final e in state) if(e.id==c.id) c else e];
  }
  void deleteCard(String id){
    state = state.where((e)=> e.id != id).toList();
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
  // try 6 then 4
  if(map.containsKey(bin)) return map[bin]!;
  final bin4 = digits.substring(0,4);
  const map4 = {'6104':'بانک ملت','6037':'بانک ملی','5892':'بانک سپه'};
  return map4[bin4] ?? 'بانک ${bin.substring(0,4)}';
}

String bankLogoAsset(String bankName){
  if(bankName.contains('ملت')) return 'assets/images/banks/mellat.png';
  if(bankName.contains('ملی')) return 'assets/images/banks/melli.png';
  if(bankName.contains('صادرات')) return 'assets/images/banks/saderat.png';
  if(bankName.contains('تجارت')) return 'assets/images/banks/tejarat.png';
  if(bankName.contains('سپه')) return 'assets/images/banks/sepah.png';
  if(bankName.contains('کشاورزی')) return 'assets/images/banks/keshavarzi.png';
  if(bankName.contains('پارسیان')) return 'assets/images/banks/parsian.png';
  if(bankName.contains('مسکن')) return 'assets/images/banks/maskan.png';
  if(bankName.contains('پست بانک')) return 'assets/images/banks/post.png';
  if(bankName.contains('اقتصاد نوین')) return 'assets/images/banks/eghtesad.png';
  if(bankName.contains('کارآفرین')) return 'assets/images/banks/karafarin.png';
  if(bankName.contains('سینا')) return 'assets/images/banks/sina.png';
  if(bankName.contains('سرمایه')) return 'assets/images/banks/sarmayeh.png';
  if(bankName.contains('شهر')) return 'assets/images/banks/shahr.png';
  if(bankName.contains('دی')) return 'assets/images/banks/day.png';
  if(bankName.contains('پاسارگاد')) return 'assets/images/banks/pasargad.png';
  if(bankName.contains('سامان')) return 'assets/images/banks/saman.png';
  if(bankName.contains('انصار')) return 'assets/images/banks/ansar.png';
  if(bankName.contains('توسعه تعاون')) return 'assets/images/banks/taavon.png';
  if(bankName.contains('قوامین')) return 'assets/images/banks/ghavamin.png';
  if(bankName.contains('حکمت')) return 'assets/images/banks/hekmat.png';
  if(bankName.contains('ایران زمین')) return 'assets/images/banks/iranzamin.png';
  if(bankName.contains('گردشگری')) return 'assets/images/banks/gardeshgari.png';
  if(bankName.contains('صنعت و معدن')) return 'assets/images/banks/sanatmadan.png';
  if(bankName.contains('توسعه صادرات')) return 'assets/images/banks/toseesaderat.png';
  if(bankName.contains('مهر اقتصاد')) return 'assets/images/banks/mehreEghtesad.png';
  if(bankName.contains('ایران ونزوئلا') || bankName.contains('ایران و ونزوئلا')) return 'assets/images/banks/iranvenezuela.png';
  if(bankName.contains('رسالت')) return 'assets/images/banks/resalat.png';
  if(bankName.contains('ملل')) return 'assets/images/banks/melal.png';
  if(bankName.contains('آینده')) return 'assets/images/banks/ayandeh.png';
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
