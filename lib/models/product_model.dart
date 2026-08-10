class ProductModel {
  final String id;
  final String code;
  final String name;
  final String unit;
  final double buyPrice;
  final double sellPrice;
  final double stock;
  final String notes;

  ProductModel({
    required this.id,
    required this.code,
    required this.name,
    required this.unit,
    required this.buyPrice,
    required this.sellPrice,
    required this.stock,
    required this.notes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'name': name,
    'unit': unit,
    'buyPrice': buyPrice,
    'sellPrice': sellPrice,
    'stock': stock,
    'notes': notes,
  };

  factory ProductModel.fromMap(Map<String, dynamic> map) => ProductModel(
    id: map['id'] ?? '',
    code: map['code'] ?? '',
    name: map['name'] ?? '',
    unit: map['unit'] ?? 'عدد',
    buyPrice: (map['buyPrice'] ?? 0).toDouble(),
    sellPrice: (map['sellPrice'] ?? 0).toDouble(),
    stock: (map['stock'] ?? 0).toDouble(),
    notes: map['notes'] ?? '',
  );
}
