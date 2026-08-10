class UserModel {
  final String id;
  final String name;
  final String country;
  final String province;
  final String city;
  final String usageType;
  final bool isOnboarded;

  UserModel({
    required this.id,
    required this.name,
    required this.country,
    required this.province,
    required this.city,
    required this.usageType,
    required this.isOnboarded,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'country': country,
    'province': province,
    'city': city,
    'usageType': usageType,
    'isOnboarded': isOnboarded,
  };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    country: map['country'] ?? 'ایران',
    province: map['province'] ?? '',
    city: map['city'] ?? '',
    usageType: map['usageType'] ?? 'store',
    isOnboarded: map['isOnboarded'] ?? false,
  );
}
