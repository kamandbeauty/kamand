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
    '610433': 'بانک ملت',
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
  // for now return generic — in real app map to assets
  return '';
}
