import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../database/app_database.dart';
import '../utils/prefs_store.dart';
import 'migration_models.dart';
import 'migration_steps.dart';

/// گزارش مهاجرت داده برای نمایش در تنظیمات و پیام‌های برنامه.
final migrationReportProvider = Provider<MigrationReport>((ref) => AppMigration.instance.lastReport);

/// مدیر مهاجرت داده‌ها برای به‌روزرسانی «بدون حذف نصب».
///
/// مسئله‌ای که این کلاس حل می‌کند: اپلیکیشن روبی از قبل روی گوشی کاربران نصب
/// است. اندروید هنگام به‌روزرسانی برنامه، داده‌های داخل حافظه‌ی برنامه
/// (SharedPreferences و فایل SQLite) را نگه می‌دارد؛ پس نسخه‌ی تازه موظف است
/// داده‌ی نسخه‌ی قدیمی را بخواند، ساختارش را کامل کند و چیزی از دست ندهد.
/// این کلاس:
///
///   • قبل از هر تغییر، یک پشتیبان خودکار روی حافظه‌ی گوشی می‌سازد؛
///   • گام‌های مهاجرت را به ترتیب و با شماره‌گذاری اجرا می‌کند؛
///   • بعد از هر گام موفق، «دفتر مهاجرت» را ذخیره می‌کند تا اگر برنامه
///     وسط کار بسته شد، اجرای بعدی از همان‌جا ادامه دهد (بدون تکرار داده)؛
///   • در صورت خطا هیچ داده‌ای را پاک نمی‌کند و برنامه با داده‌ی فعلی بالا
///     می‌آید؛ گام ناموفق در اجرای بعدی دوباره تلاش می‌شود.
class AppMigration {
  AppMigration._();

  static final AppMigration instance = AppMigration._();

  /// نسخه‌ی ساختار داده‌ی این نسخه از برنامه.
  static const int dataVersion = PrefsStore.schemaVersion;

  /// مهلت کل مهاجرت؛ اگر طول کشید، برنامه بدون قفل شدن بالا می‌آید و
  /// ادامه‌ی مهاجرت در اجرای بعدی انجام می‌شود.
  static const Duration startupTimeout = Duration(seconds: 25);

  MigrationReport _lastReport = MigrationReport.none();

  MigrationReport get lastReport => _lastReport;

  /// اجرای ایمن مهاجرت در زمان باز شدن برنامه. هرگز استثنا پرتاب نمی‌کند.
  Future<MigrationReport> runOnStartup({AppDatabase? database}) async {
    try {
      final report = await ensureMigrated(database: database).timeout(
        startupTimeout,
        onTimeout: () => _lastReport,
      );
      _lastReport = report;
      return report;
    } catch (error, stack) {
      debugPrint('AppMigration.runOnStartup failed: $error\n$stack');
      final report = MigrationReport(
        fromDataVersion: 0,
        toDataVersion: dataVersion,
        didRun: false,
        hadLegacyData: true,
        errors: <String>['اجرای به‌روزرسانی داده‌ها با خطا مواجه شد: $error'],
        finishedAt: DateTime.now(),
      );
      _lastReport = report;
      return report;
    }
  }

  /// اجرای گام‌های باقی‌مانده‌ی مهاجرت.
  ///
  /// [force] همه‌ی گام‌ها را دوباره اجرا می‌کند (برای بازگردانی پشتیبان).
  /// چون هر گام بی‌اثر (idempotent) است، اجرای دوباره داده را خراب نمی‌کند.
  Future<MigrationReport> ensureMigrated({
    AppDatabase? database,
    bool force = false,
  }) async {
    final steps = buildMigrationSteps(database: database)..sort((a, b) => a.id.compareTo(b.id));
    final allIds = steps.map((step) => step.id).toList();

    final ledger = await PrefsStore.readRawMap(PrefsStore.kMigrationLedger) ?? <String, dynamic>{};
    final completed = _intSet(ledger['completed']);
    final storedVersion = _asInt(ledger['dataVersion'], fallback: 0);
    final hadLegacyData = await _hasUserData();

    if (!hadLegacyData && !force) {
      // نصب تازه: چیزی برای مهاجرت وجود ندارد.
      if (storedVersion != dataVersion || completed.length != allIds.length) {
        await _writeLedger(dataVersion, allIds.toSet(), backupPath: '');
      }
      return MigrationReport(
        fromDataVersion: 0,
        toDataVersion: dataVersion,
        didRun: false,
        hadLegacyData: false,
        finishedAt: DateTime.now(),
      );
    }

    final upToDate = storedVersion == dataVersion && completed.containsAll(allIds);
    if (upToDate && !force) {
      return MigrationReport(
        fromDataVersion: storedVersion,
        toDataVersion: dataVersion,
        didRun: false,
        hadLegacyData: true,
        appliedSteps: const <String>[],
        warnings: const <String>[],
        migratedRecords: _asInt(ledger['migratedRecords'], fallback: 0),
        backupPath: '${ledger['backupPath'] ?? ''}',
        finishedAt: DateTime.tryParse('${ledger['finishedAt'] ?? ''}'),
      );
    }

    final fromDataVersion = storedVersion == 0 ? 1 : storedVersion;
    final pending = force
        ? List<MigrationStep>.from(steps)
        : steps.where((step) => !completed.contains(step.id)).toList();

    final backupPath = await _createUpgradeBackup(fromDataVersion);

    final applied = <String>[];
    final warnings = <String>[];
    final errors = <String>[];
    var migratedRecords = 0;

    for (final step in pending) {
      try {
        final outcome = await step.run();
        applied.add(step.title);
        migratedRecords += outcome.changedRecords;
        warnings.addAll(outcome.warnings);
        completed.add(step.id);
        await _writeLedger(
          completed.containsAll(allIds) ? dataVersion : storedVersion,
          completed,
          backupPath: backupPath,
          migratedRecords: migratedRecords,
        );
      } catch (error, stack) {
        debugPrint('Migration step ${step.id} failed: $error\n$stack');
        errors.add('${step.title}: $error');
        // گام‌های بعدی اجرا نمی‌شوند تا وابستگی‌ها به‌هم نریزد؛ در اجرای
        // بعدی برنامه از همین گام ادامه داده می‌شود.
        break;
      }
    }

    final allDone = completed.containsAll(allIds);
    await _writeLedger(
      allDone ? dataVersion : fromDataVersion,
      completed,
      backupPath: backupPath,
      migratedRecords: migratedRecords,
    );

    final report = MigrationReport(
      fromDataVersion: fromDataVersion,
      toDataVersion: allDone ? dataVersion : fromDataVersion,
      didRun: applied.isNotEmpty,
      hadLegacyData: true,
      appliedSteps: applied,
      warnings: warnings,
      errors: errors,
      migratedRecords: migratedRecords,
      backupPath: backupPath,
      finishedAt: DateTime.now(),
    );

    _lastReport = report;
    await _logReport(database, report);
    return report;
  }

  /// اجرای دوباره‌ی مهاجرت پس از بازگردانی پشتیبان یا تغییر دستی داده‌ها.
  Future<MigrationReport> reapplyAfterRestore({AppDatabase? database}) {
    return ensureMigrated(database: database, force: true);
  }

  /// اطلاعات آخرین پشتیبان خودکار پیش از به‌روزرسانی داده.
  Future<Map<String, dynamic>?> lastBackupInfo() {
    return PrefsStore.readRawMap(PrefsStore.kLastUpgradeBackup);
  }

  /// بازگردانی آخرین پشتیبان خودکار.
  ///
  /// این مسیر برای پشتیبانی است: اگر کاربری بعد از به‌روزرسانی احساس کرد
  /// چیزی کم است، می‌تواند همه‌ی داده‌ی پیش از به‌روزرسانی را برگرداند.
  Future<MigrationReport> restoreLastUpgradeBackup({AppDatabase? database}) async {
    final info = await lastBackupInfo();
    final path = '${info?['path'] ?? ''}';
    if (path.isEmpty) {
      throw const FormatException('پشتیبان خودکاری برای بازیابی پیدا نشد.');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw const FormatException('فایل پشتیبان پیدا نشد.');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const FormatException('ساختار فایل پشتیبان معتبر نیست.');
    }
    await PrefsStore.importRawSnapshot(Map<String, dynamic>.from(decoded));
    final report = await ensureMigrated(database: database, force: true);
    await PrefsStore.writeRawJson(PrefsStore.kLastUpgradeBackup, <String, dynamic>{
      ...?info,
      'restoredAt': DateTime.now().toIso8601String(),
    });
    return report;
  }

  // ---------------------------------------------------------------------------
  // داخلی
  // ---------------------------------------------------------------------------

  Future<bool> _hasUserData() async {
    final keys = await PrefsStore.storedKeys();
    const meaningful = <String>[
      PrefsStore.kUser,
      PrefsStore.kBusiness,
      PrefsStore.kSettings,
      PrefsStore.kInvoices,
      PrefsStore.kCustomers,
      PrefsStore.kProducts,
      PrefsStore.kBankCards,
      PrefsStore.kSuppliers,
      PrefsStore.kExpenses,
      PrefsStore.kDraft,
    ];
    return keys.any(meaningful.contains);
  }

  Future<void> _writeLedger(
    int version,
    Set<int> completed, {
    String backupPath = '',
    int migratedRecords = 0,
  }) async {
    final existing = await PrefsStore.readRawMap(PrefsStore.kMigrationLedger) ?? <String, dynamic>{};
    final completedList = completed.toList()..sort();
    await PrefsStore.writeRawJson(PrefsStore.kMigrationLedger, <String, dynamic>{
      ...existing,
      'dataVersion': version,
      'completed': completedList,
      'appVersion': dataVersion,
      'backupPath': backupPath.isEmpty ? '${existing['backupPath'] ?? ''}' : backupPath,
      'migratedRecords': migratedRecords > 0 ? migratedRecords : _asInt(existing['migratedRecords'], fallback: 0),
      'finishedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<String> _createUpgradeBackup(int fromVersion) async {
    try {
      final snapshot = await PrefsStore.exportRawSnapshot();
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        p.join(
          directory.path,
          'ruby-upgrade-backup-v${fromVersion}-to-v$dataVersion-'
          '${DateTime.now().millisecondsSinceEpoch}.json',
        ),
      );
      await file.writeAsString(jsonEncode(snapshot), flush: true);
      await _pruneBackups(directory, keep: 5);
      await PrefsStore.writeRawJson(PrefsStore.kLastUpgradeBackup, <String, dynamic>{
        'path': file.path,
        'fromVersion': fromVersion,
        'toVersion': dataVersion,
        'createdAt': DateTime.now().toIso8601String(),
      });
      return file.path;
    } catch (error) {
      // نبودِ پشتیبان نباید جلوی مهاجرت را بگیرد؛ فقط هشدار می‌دهیم.
      debugPrint('AppMigration: backup failed: $error');
      return '';
    }
  }

  Future<void> _pruneBackups(Directory directory, {required int keep}) async {
    try {
      final entries = await directory
          .list()
          .where((entity) => entity is File && p.basename(entity.path).startsWith('ruby-upgrade-backup-'))
          .cast<File>()
          .toList();
      if (entries.length <= keep) return;
      final withTime = <MapEntry<File, DateTime>>[];
      for (final file in entries) {
        try {
          withTime.add(MapEntry(file, (await file.stat()).modified));
        } catch (_) {}
      }
      withTime.sort((a, b) => b.value.compareTo(a.value));
      for (final entry in withTime.skip(keep)) {
        try {
          await entry.key.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _logReport(AppDatabase? database, MigrationReport report) async {
    if (database == null) return;
    try {
      await database.logEvent('migration_report', jsonEncode(report.toMap()));
    } catch (_) {}
  }

  Set<int> _intSet(dynamic value) {
    if (value is! List) return <int>{};
    return value.map((item) => _asInt(item, fallback: -1)).where((id) => id > 0).toSet();
  }

  int _asInt(dynamic value, {required int fallback}) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
