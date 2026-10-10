class UserModel {
  final String id;
  final String name;
  final String phone;
  final String country;
  final String province;
  final String city;
  final String usageType;
  final bool isOnboarded;
  final bool isPremium;

  UserModel({
    required this.id,
    required this.name,
    this.phone = '',
    required this.country,
    required this.province,
    required this.city,
    required this.usageType,
    required this.isOnboarded,
    this.isPremium = false,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? country,
    String? province,
    String? city,
    String? usageType,
    bool? isOnboarded,
    bool? isPremium,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      country: country ?? this.country,
      province: province ?? this.province,
      city: city ?? this.city,
      usageType: usageType ?? this.usageType,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      isPremium: isPremium ?? this.isPremium,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'country': country,
        'province': province,
        'city': city,
        'usageType': usageType,
        'isOnboarded': isOnboarded,
        'isPremium': isPremium,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        phone: map['phone'] ?? '',
        country: map['country'] ?? 'ایران',
        province: map['province'] ?? '',
        city: map['city'] ?? '',
        usageType: map['usageType'] ?? 'store',
        isOnboarded: map['isOnboarded'] ?? false,
        isPremium: map['isPremium'] ?? false,
      );
}
