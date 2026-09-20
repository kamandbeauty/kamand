class InvoiceItemModel {
  final String id;
  final String title;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  final double buyPrice; // قیمت خرید برای محاسبه سود
  final String productId;

  InvoiceItemModel({
    required this.id,
    required this.title,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
    this.buyPrice = 0,
    this.productId = '',
  });

  double get profitPerUnit => unitPrice - buyPrice;
  double get totalBuyPrice => buyPrice * quantity;
  double get totalProfit => (unitPrice - buyPrice) * quantity;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'totalPrice': totalPrice,
    'buyPrice': buyPrice,
    'productId': productId,
  };

  factory InvoiceItemModel.fromMap(Map<String, dynamic> map) => InvoiceItemModel(
    id: map['id'] ?? '',
    title: map['title'] ?? '',
    quantity: (map['quantity'] ?? 1).toDouble(),
    unit: map['unit'] ?? 'عدد',
    unitPrice: (map['unitPrice'] ?? 0).toDouble(),
    totalPrice: (map['totalPrice'] ?? 0).toDouble(),
    buyPrice: (map['buyPrice'] ?? 0).toDouble(),
    productId: map['productId'] ?? '',
  );
}
