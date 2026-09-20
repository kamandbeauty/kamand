class SupplierModel {
  final String id;
  final String name;
  final String phone;
  final String mobile;
  final String address;
  final String notes;
  final double balance; // بدهی ما به تامین کننده
  final String createdAt;

  SupplierModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.mobile,
    required this.address,
    required this.notes,
    required this.balance,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'mobile': mobile,
    'address': address,
    'notes': notes,
    'balance': balance,
    'createdAt': createdAt,
  };

  factory SupplierModel.fromMap(Map<String, dynamic> map) => SupplierModel(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    phone: map['phone'] ?? '',
    mobile: map['mobile'] ?? '',
    address: map['address'] ?? '',
    notes: map['notes'] ?? '',
    balance: (map['balance'] ?? 0).toDouble(),
    createdAt: map['createdAt'] ?? '',
  );

  SupplierModel copyWith({
    String? name,
    String? phone,
    String? mobile,
    String? address,
    String? notes,
    double? balance,
  }) {
    return SupplierModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      balance: balance ?? this.balance,
      createdAt: createdAt,
    );
  }
}
