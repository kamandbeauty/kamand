class AppSettingsModel {
  final int startingInvoiceNum;
  final String templateStyle;
  final bool showLogo;
  final bool showCardNum;
  final bool showStamp;
  final bool showSignature;
  final bool officialInvoiceEnabled;
  final double defaultTaxRate;
  final String themeMode; // light, dark, system
  final bool autoBackup;
  final String pinCode;
  final bool pinEnabled;
  /// رنگ اصلی اپ/فاکتور به صورت 0xAARRGGBB (مثلاً 0xFFF97316)
  final int accentColor;

  AppSettingsModel({
    required this.startingInvoiceNum,
    required this.templateStyle,
    required this.showLogo,
    required this.showCardNum,
    this.showStamp = true,
    this.showSignature = true,
    this.officialInvoiceEnabled = false,
    this.defaultTaxRate = 10,
    required this.themeMode,
    required this.autoBackup,
    required this.pinCode,
    required this.pinEnabled,
    this.accentColor = 0xFFF97316,
  });

  AppSettingsModel copyWith({
    int? startingInvoiceNum,
    String? templateStyle,
    bool? showLogo,
    bool? showCardNum,
    bool? showStamp,
    bool? showSignature,
    bool? officialInvoiceEnabled,
    double? defaultTaxRate,
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
      officialInvoiceEnabled:
          officialInvoiceEnabled ?? this.officialInvoiceEnabled,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
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
        'officialInvoiceEnabled': officialInvoiceEnabled,
        'defaultTaxRate': defaultTaxRate,
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
        showStamp: map['showStamp'] ?? map['showSignature'] ?? true,
        showSignature: map['showSignature'] ?? map['showStamp'] ?? true,
        officialInvoiceEnabled: map['officialInvoiceEnabled'] ?? false,
        defaultTaxRate: (map['defaultTaxRate'] is num)
            ? (map['defaultTaxRate'] as num).toDouble()
            : double.tryParse('${map['defaultTaxRate']}') ?? 10,
        themeMode: map['themeMode'] ?? 'light',
        autoBackup: map['autoBackup'] ?? true,
        pinCode: map['pinCode'] ?? '',
        pinEnabled: map['pinEnabled'] ?? false,
        accentColor: map['accentColor'] is int
            ? map['accentColor'] as int
            : int.tryParse('${map['accentColor']}') ?? 0xFFF97316,
      );
}
