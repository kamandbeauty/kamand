class UserModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String authProvider;
  final String country;
  final String province;
  final String city;
  final String usageType;
  final bool isOnboarded;
  final bool isPremium;
  final String premiumExpiresAt;

  bool get hasActivePremium {
    if (!isPremium) return false;
    if (premiumExpiresAt.trim().isEmpty) return true;
    final expiresAt = DateTime.tryParse(premiumExpiresAt);
    return expiresAt != null && expiresAt.isAfter(DateTime.now().toUtc());
  }

  UserModel({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.authProvider = '',
    required this.country,
    required this.province,
    required this.city,
    required this.usageType,
    required this.isOnboarded,
    this.isPremium = false,
    this.premiumExpiresAt = '',
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? authProvider,
    String? country,
    String? province,
    String? city,
    String? usageType,
    bool? isOnboarded,
    bool? isPremium,
    String? premiumExpiresAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      authProvider: authProvider ?? this.authProvider,
      country: country ?? this.country,
      province: province ?? this.province,
      city: city ?? this.city,
      usageType: usageType ?? this.usageType,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      isPremium: isPremium ?? this.isPremium,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'authProvider': authProvider,
        'country': country,
        'province': province,
        'city': city,
        'usageType': usageType,
        'isOnboarded': isOnboarded,
        'isPremium': isPremium,
        'premiumExpiresAt': premiumExpiresAt,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        phone: map['phone'] ?? '',
        email: map['email'] ?? '',
        authProvider: map['authProvider'] ?? '',
        country: map['country'] ?? 'ایران',
        province: map['province'] ?? '',
        city: map['city'] ?? '',
        usageType: map['usageType'] ?? 'store',
        isOnboarded: map['isOnboarded'] ?? false,
        isPremium: map['isPremium'] ?? false,
        premiumExpiresAt: map['premiumExpiresAt'] ?? '',
      );
}
