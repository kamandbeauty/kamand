class ExpenseIncomeModel {
  final String id;
  final String title;
  final String category;
  final double amount;
  final String date;
  final String notes;
  final bool isIncome;

  ExpenseIncomeModel({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.notes,
    required this.isIncome,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'category': category,
    'amount': amount,
    'date': date,
    'notes': notes,
    'isIncome': isIncome,
  };

  factory ExpenseIncomeModel.fromMap(Map<String, dynamic> map) => ExpenseIncomeModel(
    id: map['id'] ?? '',
    title: map['title'] ?? '',
    category: map['category'] ?? 'عمومی',
    amount: (map['amount'] ?? 0).toDouble(),
    date: map['date'] ?? '',
    notes: map['notes'] ?? '',
    isIncome: map['isIncome'] ?? false,
  );
}
