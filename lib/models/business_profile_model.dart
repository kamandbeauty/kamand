class BusinessProfileModel {
  final String id;
  final String shopName;
  final String phone;
  final String address;
  final String taxId;
  final String logoPath;
  final List<String> bankCards;

  BusinessProfileModel({
    required this.id,
    required this.shopName,
    required this.phone,
    required this.address,
    required this.taxId,
    required this.logoPath,
    required this.bankCards,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'shopName': shopName,
    'phone': phone,
    'address': address,
    'taxId': taxId,
    'logoPath': logoPath,
    'bankCards': bankCards,
  };

  factory BusinessProfileModel.fromMap(Map<String, dynamic> map) => BusinessProfileModel(
    id: map['id'] ?? '',
    shopName: map['shopName'] ?? '',
    phone: map['phone'] ?? '',
    address: map['address'] ?? '',
    taxId: map['taxId'] ?? '',
    logoPath: map['logoPath'] ?? '',
    bankCards: List<String>.from(map['bankCards'] ?? []),
  );
}
