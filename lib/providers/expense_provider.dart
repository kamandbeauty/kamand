import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_model.dart';
import '../core/utils/prefs_store.dart';

final expenseListProvider =
    StateNotifierProvider<ExpenseListNotifier, List<ExpenseModel>>((ref) {
  return ExpenseListNotifier();
});

class ExpenseListNotifier extends StateNotifier<List<ExpenseModel>> {
  late final Future<void> _hydrated;

  ExpenseListNotifier() : super(const []) {
    _hydrated = _hydrate();
  }

  Future<void> ensureLoaded() => _hydrated;

  Future<void> _hydrate() async {
    state = await PrefsStore.loadExpenses();
  }

  void _persist() {
    PrefsStore.saveExpenses(state);
  }

  Future<void> addExpense(ExpenseModel expense) async {
    await _hydrated;
    state = [...state, expense];
    await PrefsStore.saveExpenses(state);
  }

  void updateExpense(ExpenseModel expense) {
    state = [
      for (final item in state)
        if (item.id == expense.id) expense else item,
    ];
    _hydrated.then((_) {
      state = [
        for (final item in state)
          if (item.id == expense.id) expense else item,
      ];
      _persist();
    });
    _persist();
  }

  void deleteExpense(String id) {
    state = state.where((item) => item.id != id).toList();
    _hydrated.then((_) {
      state = state.where((item) => item.id != id).toList();
      _persist();
    });
    _persist();
  }

  // خلاصه‌ها
  double get totalAmount => state.fold(0, (sum, e) => sum + e.amount);

  double totalByCategory(String category) {
    return state.where((e) => e.category == category).fold(0, (s, e) => s + e.amount);
  }

  Map<String, double> get categorySummary {
    final map = <String, double>{};
    for (final e in state) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }
}
