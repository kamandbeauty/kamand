class CustomerModel {
  final String id;
  final String name;
  final String mobile;
  final String phone;
  final String address;
  final String notes;
  final String nationalId;
  final String economicCode;
  final String postalCode;
  final double balance;
  final String createdAt;

  CustomerModel({
    required this.id,
    required this.name,
    required this.mobile,
    required this.phone,
    required this.address,
    required this.notes,
    this.nationalId = '',
    this.economicCode = '',
    this.postalCode = '',
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
    'nationalId': nationalId,
    'economicCode': economicCode,
    'postalCode': postalCode,
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
    nationalId: map['nationalId'] ?? '',
    economicCode: map['economicCode'] ?? '',
    postalCode: map['postalCode'] ?? '',
    balance: (map['balance'] ?? 0).toDouble(),
    createdAt: map['createdAt'] ?? '',
  );
}
