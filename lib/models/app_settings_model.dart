class AppSettingsModel {
  final int startingInvoiceNum;
  final String templateStyle;
  final bool showLogo;
  final bool showCardNum;
  final String themeMode; // light, dark, system
  final bool autoBackup;
  final String pinCode;
  final bool pinEnabled;

  AppSettingsModel({
    required this.startingInvoiceNum,
    required this.templateStyle,
    required this.showLogo,
    required this.showCardNum,
    required this.themeMode,
    required this.autoBackup,
    required this.pinCode,
    required this.pinEnabled,
  });

  Map<String, dynamic> toMap() => {
    'startingInvoiceNum': startingInvoiceNum,
    'templateStyle': templateStyle,
    'showLogo': showLogo,
    'showCardNum': showCardNum,
    'themeMode': themeMode,
    'autoBackup': autoBackup,
    'pinCode': pinCode,
    'pinEnabled': pinEnabled,
  };

  factory AppSettingsModel.fromMap(Map<String, dynamic> map) => AppSettingsModel(
    startingInvoiceNum: map['startingInvoiceNum'] ?? 1004,
    templateStyle: map['templateStyle'] ?? 'modern',
    showLogo: map['showLogo'] ?? true,
    showCardNum: map['showCardNum'] ?? true,
    themeMode: map['themeMode'] ?? 'light',
    autoBackup: map['autoBackup'] ?? true,
    pinCode: map['pinCode'] ?? '',
    pinEnabled: map['pinEnabled'] ?? false,
  );
}
