class AppSettingsModel {
  final int startingInvoiceNum;
  final String templateStyle;
  final bool showLogo;
  final bool showCardNum;
  final bool showStamp;
  final bool showSignature;
  final String themeMode; // light, dark, system
  final bool autoBackup;
  final String pinCode;
  final bool pinEnabled;
  /// رنگ اصلی اپ/فاکتور به صورت 0xAARRGGBB (مثلاً 0xFF5E9ED9)
  final int accentColor;

  AppSettingsModel({
    required this.startingInvoiceNum,
    required this.templateStyle,
    required this.showLogo,
    required this.showCardNum,
    this.showStamp = true,
    this.showSignature = true,
    required this.themeMode,
    required this.autoBackup,
    required this.pinCode,
    required this.pinEnabled,
    this.accentColor = 0xFF5E9ED9,
  });

  AppSettingsModel copyWith({
    int? startingInvoiceNum,
    String? templateStyle,
    bool? showLogo,
    bool? showCardNum,
    bool? showStamp,
    bool? showSignature,
    String? themeMode,
    bool? autoBackup,
    String? pinCode,
    bool? pinEnabled,
    int? accentColor,
  }) {
    return AppSettingsModel(
      startingInvoiceNum: startingInvoiceNum ?? this.startingInvoiceNum,
      templateStyle: templateStyle ?? this.templateStyle,
      showLogo: showLogo ?? this.showLogo,
      showCardNum: showCardNum ?? this.showCardNum,
      showStamp: showStamp ?? this.showStamp,
      showSignature: showSignature ?? this.showSignature,
      themeMode: themeMode ?? this.themeMode,
      autoBackup: autoBackup ?? this.autoBackup,
      pinCode: pinCode ?? this.pinCode,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  Map<String, dynamic> toMap() => {
        'startingInvoiceNum': startingInvoiceNum,
        'templateStyle': templateStyle,
        'showLogo': showLogo,
        'showCardNum': showCardNum,
        'showStamp': showStamp,
        'showSignature': showSignature,
        'themeMode': themeMode,
        'autoBackup': autoBackup,
        'pinCode': pinCode,
        'pinEnabled': pinEnabled,
        'accentColor': accentColor,
      };

  factory AppSettingsModel.fromMap(Map<String, dynamic> map) => AppSettingsModel(
        startingInvoiceNum: map['startingInvoiceNum'] ?? 1,
        templateStyle: map['templateStyle'] ?? 'modern',
        showLogo: map['showLogo'] ?? true,
        showCardNum: map['showCardNum'] ?? true,
        showStamp: map['showStamp'] ?? true,
        showSignature: map['showStamp'] ?? map['showSignature'] ?? true,
        themeMode: map['themeMode'] ?? 'light',
        autoBackup: map['autoBackup'] ?? true,
        pinCode: map['pinCode'] ?? '',
        pinEnabled: map['pinEnabled'] ?? false,
        accentColor: map['accentColor'] is int
            ? map['accentColor'] as int
            : int.tryParse('${map['accentColor']}') ?? 0xFF5E9ED9,
      );
}
