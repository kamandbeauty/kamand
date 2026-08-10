import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/financial_model.dart';

final financialListProvider =
    StateNotifierProvider<FinancialListNotifier, List<ExpenseIncomeModel>>((ref) {
  return FinancialListNotifier();
});

class FinancialListNotifier extends StateNotifier<List<ExpenseIncomeModel>> {
  FinancialListNotifier()
      : super([
          ExpenseIncomeModel(
            id: 'e1',
            title: 'اجاره دفتر و کارگاه',
            category: 'اجاره',
            amount: 8500000,
            date: '1405/05/01',
            notes: 'اجاره ماه مرداد',
            isIncome: false,
          ),
          ExpenseIncomeModel(
            id: 'e2',
            title: 'قبض برق و اینترنت',
            category: 'قبوض',
            amount: 950000,
            date: '1405/05/10',
            notes: 'پرداخت آنلاین',
            isIncome: false,
          ),
          ExpenseIncomeModel(
            id: 'e3',
            title: 'هزینه بسته بندی و کارتن',
            category: 'ملزومات',
            amount: 1200000,
            date: '1405/05/14',
            notes: 'خرید ۱۰۰ عدد کارتن',
            isIncome: false,
          ),
          ExpenseIncomeModel(
            id: 'inc1',
            title: 'مشاوره و راه‌اندازی کافه',
            category: 'خدمات',
            amount: 4500000,
            date: '1405/05/05',
            notes: 'پروژه کافه کاج',
            isIncome: true,
          ),
        ]);

  void addRecord(ExpenseIncomeModel item) {
    state = [...state, item];
  }

  void deleteRecord(String id) {
    state = state.where((item) => item.id != id).toList();
  }
}
