class BusinessProfileModel {
  final String id;
  final String shopName;
  final String phone;
  final String address;
  final String taxId;
  final String nationalId;
  final String economicCode;
  final String registrationNumber;
  final String postalCode;
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
    this.nationalId = '',
    this.economicCode = '',
    this.registrationNumber = '',
    this.postalCode = '',
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
    String? nationalId,
    String? economicCode,
    String? registrationNumber,
    String? postalCode,
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
      nationalId: nationalId ?? this.nationalId,
      economicCode: economicCode ?? this.economicCode,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      postalCode: postalCode ?? this.postalCode,
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
        'nationalId': nationalId,
        'economicCode': economicCode,
        'registrationNumber': registrationNumber,
        'postalCode': postalCode,
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
        nationalId: map['nationalId'] ?? '',
        economicCode: map['economicCode'] ?? map['taxId'] ?? '',
        registrationNumber: map['registrationNumber'] ?? '',
        postalCode: map['postalCode'] ?? '',
        logoPath: map['logoPath'] ?? '',
        stampPath: map['stampPath'] ?? '',
        signaturePath: map['signaturePath'] ?? '',
        bankCards: List<String>.from(map['bankCards'] ?? []),
      );
}
