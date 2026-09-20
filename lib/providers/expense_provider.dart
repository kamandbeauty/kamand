import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/persistent_list.dart';
import '../core/utils/prefs_store.dart';
import '../database/app_database.dart';
import '../models/expense_model.dart';

final expenseListProvider =
    StateNotifierProvider<ExpenseListNotifier, List<ExpenseModel>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ExpenseListNotifier(db);
});

class ExpenseListNotifier extends PersistentListNotifier<ExpenseModel> {
  ExpenseListNotifier([this.db]);

  final AppDatabase? db;

  @override
  Future<List<ExpenseModel>> readFromStorage() => PrefsStore.loadExpenses();

  @override
  Future<void> writeToStorage(List<ExpenseModel> items) async {
    await PrefsStore.saveExpenses(items);
    await db?.mirrorExpenses(items);
  }

  Future<void> addExpense(ExpenseModel expense) => mutateAsync(
        (expenses) => expenses.any((item) => item.id == expense.id)
            ? expenses
            : [...expenses, expense],
      );

  void updateExpense(ExpenseModel expense) {
    mutate(
      (expenses) => [
        for (final item in expenses)
          if (item.id == expense.id) expense else item,
      ],
    );
  }

  void deleteExpense(String id) {
    mutate((expenses) => expenses.where((item) => item.id != id).toList());
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
