class InvoiceItemModel {
  final String id;
  final String title;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;

  InvoiceItemModel({
    required this.id,
    required this.title,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'totalPrice': totalPrice,
  };

  factory InvoiceItemModel.fromMap(Map<String, dynamic> map) => InvoiceItemModel(
    id: map['id'] ?? '',
    title: map['title'] ?? '',
    quantity: (map['quantity'] ?? 1).toDouble(),
    unit: map['unit'] ?? 'عدد',
    unitPrice: (map['unitPrice'] ?? 0).toDouble(),
    totalPrice: (map['totalPrice'] ?? 0).toDouble(),
  );
}
