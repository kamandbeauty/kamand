/// خروجی اجرای یک گام مهاجرت.
class MigrationStepOutcome {
  /// تعداد رکوردهایی که این گام تغییر داده است.
  final int changedRecords;

  /// هشدارها؛ اجرا را متوقف نمی‌کنند اما در گزارش ثبت می‌شوند.
  final List<String> warnings;

  const MigrationStepOutcome({this.changedRecords = 0, this.warnings = const <String>[]});
}

/// یک گام مهاجرت داده. هر گام باید **بی‌اثر (idempotent)** باشد، یعنی اجرای
/// دوباره‌ی آن روی همان داده هیچ تغییری ایجاد نکند. این ویژگی باعث می‌شود اگر
/// برنامه وسط مهاجرت بسته شود یا گوشی خاموش شود، در اجرای بعدی ادامه‌ی کار
/// بدون خراب شدن یا تکرارشدن داده انجام شود.
class MigrationStep {
  /// شماره‌ی یکتا و صعودی. برای افزودن گام تازه در آینده، شماره‌ی بزرگ‌تر بدهید.
  final int id;

  /// توضیح فارسی برای نمایش در گزارش مهاجرت.
  final String title;

  final Future<MigrationStepOutcome> Function() run;

  const MigrationStep({required this.id, required this.title, required this.run});
}

/// گزارش نهایی مهاجرت داده‌ها؛ در تنظیمات به کاربر نمایش داده می‌شود.
class MigrationReport {
  /// نسخه‌ی داده‌ی ذخیره‌شده پیش از اجرای مهاجرت.
  final int fromDataVersion;

  /// نسخه‌ی داده‌ی ذخیره‌شده پس از اجرای مهاجرت.
  final int toDataVersion;

  /// آیا این بار چیزی اجرا شد؟ (نصب‌های به‌روزشده در اولین اجرا true است)
  final bool didRun;

  /// آیا روی این دستگاه داده‌ی نسخه‌ی قبل وجود داشت؟
  final bool hadLegacyData;

  final List<String> appliedSteps;
  final List<String> warnings;
  final List<String> errors;

  /// تعداد کل رکوردهایی که به‌روزرسانی شدند.
  final int migratedRecords;

  /// مسیر پشتیبان خودکاری که پیش از مهاجرت ساخته شد.
  final String backupPath;

  final DateTime? finishedAt;

  const MigrationReport({
    required this.fromDataVersion,
    required this.toDataVersion,
    required this.didRun,
    required this.hadLegacyData,
    this.appliedSteps = const <String>[],
    this.warnings = const <String>[],
    this.errors = const <String>[],
    this.migratedRecords = 0,
    this.backupPath = '',
    this.finishedAt,
  });

  factory MigrationReport.none() => const MigrationReport(
        fromDataVersion: 0,
        toDataVersion: 0,
        didRun: false,
        hadLegacyData: false,
      );

  bool get hasIssues => errors.isNotEmpty || warnings.isNotEmpty;

  bool get hasError => errors.isNotEmpty;

  String get summary {
    if (errors.isNotEmpty) {
      return 'به‌روزرسانی داده‌ها با خطا مواجه شد (${errors.length} مورد). اطلاعات شما بدون تغییر باقی ماند.';
    }
    if (!didRun) return 'داده‌ها از قبل روی آخرین نسخه هستند.';
    return 'اطلاعات نسخه‌ی قبل با موفقیت منتقل شد'
        '${migratedRecords > 0 ? ' ($migratedRecords رکورد)' : ''}.';
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'fromDataVersion': fromDataVersion,
        'toDataVersion': toDataVersion,
        'didRun': didRun,
        'hadLegacyData': hadLegacyData,
        'appliedSteps': appliedSteps,
        'warnings': warnings,
        'errors': errors,
        'migratedRecords': migratedRecords,
        'backupPath': backupPath,
        'finishedAt': finishedAt?.toIso8601String(),
      };

  factory MigrationReport.fromMap(Map<String, dynamic> map) => MigrationReport(
        fromDataVersion: (map['fromDataVersion'] as num?)?.toInt() ?? 0,
        toDataVersion: (map['toDataVersion'] as num?)?.toInt() ?? 0,
        didRun: map['didRun'] == true,
        hadLegacyData: map['hadLegacyData'] == true,
        appliedSteps: _stringList(map['appliedSteps']),
        warnings: _stringList(map['warnings']),
        errors: _stringList(map['errors']),
        migratedRecords: (map['migratedRecords'] as num?)?.toInt() ?? 0,
        backupPath: '${map['backupPath'] ?? ''}',
        finishedAt: DateTime.tryParse('${map['finishedAt'] ?? ''}'),
      );

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value.map((item) => '$item').toList();
  }
}
