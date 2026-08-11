class BusinessProfileModel {
  final String id;
  final String shopName;
  final String phone;
  final String address;
  final String taxId;
  final String logoPath;
  final String stampPath;
  final String signaturePath;
  final List<String> bankCards;

  BusinessProfileModel({
    required this.id,
    required this.shopName,
    required this.phone,
    required this.address,
    required this.taxId,
    required this.logoPath,
    this.stampPath = '',
    this.signaturePath = '',
    required this.bankCards,
  });

  BusinessProfileModel copyWith({
    String? id,
    String? shopName,
    String? phone,
    String? address,
    String? taxId,
    String? logoPath,
    String? stampPath,
    String? signaturePath,
    List<String>? bankCards,
  }) {
    return BusinessProfileModel(
      id: id ?? this.id,
      shopName: shopName ?? this.shopName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      taxId: taxId ?? this.taxId,
      logoPath: logoPath ?? this.logoPath,
      stampPath: stampPath ?? this.stampPath,
      signaturePath: signaturePath ?? this.signaturePath,
      bankCards: bankCards ?? this.bankCards,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'shopName': shopName,
        'phone': phone,
        'address': address,
        'taxId': taxId,
        'logoPath': logoPath,
        'stampPath': stampPath,
        'signaturePath': signaturePath,
        'bankCards': bankCards,
      };

  factory BusinessProfileModel.fromMap(Map<String, dynamic> map) => BusinessProfileModel(
        id: map['id'] ?? '',
        shopName: map['shopName'] ?? '',
        phone: map['phone'] ?? '',
        address: map['address'] ?? '',
        taxId: map['taxId'] ?? '',
        logoPath: map['logoPath'] ?? '',
        stampPath: map['stampPath'] ?? '',
        signaturePath: map['signaturePath'] ?? '',
        bankCards: List<String>.from(map['bankCards'] ?? []),
      );
}
