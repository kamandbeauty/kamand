class ExpenseModel {
  final String id;
  final String title;
  final double amount;
  final String category; // اجاره، حقوق، حمل، خرید، سایر
  final String date; // شمسی
  final String notes;
  final String invoiceId; // اگر به فاکتور خرید مرتبط باشد
  final String createdAt;

  ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.notes,
    required this.invoiceId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'amount': amount,
    'category': category,
    'date': date,
    'notes': notes,
    'invoiceId': invoiceId,
    'createdAt': createdAt,
  };

  factory ExpenseModel.fromMap(Map<String, dynamic> map) => ExpenseModel(
    id: map['id'] ?? '',
    title: map['title'] ?? '',
    amount: (map['amount'] ?? 0).toDouble(),
    category: map['category'] ?? 'سایر',
    date: map['date'] ?? '',
    notes: map['notes'] ?? '',
    invoiceId: map['invoiceId'] ?? '',
    createdAt: map['createdAt'] ?? '',
  );

  ExpenseModel copyWith({
    String? title,
    double? amount,
    String? category,
    String? date,
    String? notes,
  }) {
    return ExpenseModel(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      invoiceId: invoiceId,
      createdAt: createdAt,
    );
  }
}
