class CustomerModel {
  final String id;
  final String name;
  final String mobile;
  final String phone;
  final String address;
  final String notes;
  final double balance;
  final String createdAt;

  CustomerModel({
    required this.id,
    required this.name,
    required this.mobile,
    required this.phone,
    required this.address,
    required this.notes,
    required this.balance,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'mobile': mobile,
    'phone': phone,
    'address': address,
    'notes': notes,
    'balance': balance,
    'createdAt': createdAt,
  };

  factory CustomerModel.fromMap(Map<String, dynamic> map) => CustomerModel(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    mobile: map['mobile'] ?? '',
    phone: map['phone'] ?? '',
    address: map['address'] ?? '',
    notes: map['notes'] ?? '',
    balance: (map['balance'] ?? 0).toDouble(),
    createdAt: map['createdAt'] ?? '',
  );
}
