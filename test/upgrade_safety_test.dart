import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:factor_ruby/core/constants/app_constants.dart';
import 'package:factor_ruby/core/utils/prefs_store.dart';

/// این تست‌ها «قراردادهای به‌روزرسانی بدون حذف نصب» را قفل می‌کنند.
///
/// اپلیکیشن روبی روی گوشی کاربران نصب است؛ اگر روزی کسی یکی از این موارد را
/// عوض کند، اندروید اجازه‌ی به‌روزرسانی نمی‌دهد یا همه‌ی اطلاعات کاربر از بین
/// می‌رود. این تست‌ها قبل از انتشار جلوی آن را می‌گیرند.
void main() {
  group('کلیدهای ذخیره‌سازی روی گوشی کاربران', () {
    test('کلیدهای SharedPreferences همان مقادیر نسخه‌ی نصب‌شده است', () {
      // این رشته‌ها روی گوشی کاربران وجود دارند و هرگز نباید تغییر کنند.
      expect(PrefsStore.kUser, 'ruby_user_v1');
      expect(PrefsStore.kBusiness, 'ruby_business_v1');
      expect(PrefsStore.kSettings, 'ruby_settings_v1');
      expect(PrefsStore.kInvoices, 'ruby_invoices_v1');
      expect(PrefsStore.kCustomers, 'ruby_customers_v1');
      expect(PrefsStore.kProducts, 'ruby_products_v1');
      expect(PrefsStore.kDraft, 'ruby_invoice_draft_v1');
      expect(PrefsStore.kBankCards, 'ruby_bank_cards_v1');
      expect(PrefsStore.kSelectedBankCard, 'ruby_selected_bank_card_v1');
    });

    test('همه‌ی داده‌های کاربر در پشتیبان‌گیری و بازگردانی دیده می‌شوند', () {
      for (final key in <String>[
        PrefsStore.kUser,
        PrefsStore.kBusiness,
        PrefsStore.kSettings,
        PrefsStore.kInvoices,
        PrefsStore.kCustomers,
        PrefsStore.kProducts,
        PrefsStore.kDraft,
        PrefsStore.kBankCards,
        PrefsStore.kSuppliers,
        PrefsStore.kExpenses,
      ]) {
        expect(
          PrefsStore.listKeys.contains(key) || PrefsStore.mapKeys.contains(key),
          isTrue,
          reason: '$key باید در پشتیبان‌گیری/بازگردانی کامل لحاظ شود',
        );
      }
    });
  });

  group('هویت برنامه در اندروید', () {
    late String gradle;

    setUpAll(() {
      gradle = File('android/app/build.gradle.kts').readAsStringSync();
    });

    test('applicationId و namespace همان مقدار منتشرشده است', () {
      expect(AppConstants.androidApplicationId, 'com.ruby.factor_ruby');
      expect(gradle.contains('applicationId = "com.ruby.factor_ruby"'), isTrue,
          reason: 'تغییر applicationId یعنی کاربر مجبور به حذف نصب می‌شود');
      expect(gradle.contains('namespace = "com.ruby.factor_ruby"'), isTrue);
    });

    test('minSdk بالاتر نرفته و از نسخه‌ی flutter خوانده می‌شود', () {
      expect(gradle.contains('minSdk = 21'), isTrue,
          reason: 'بالا بردن minSdk باعث می‌شود بعضی کاربران نتوانند به‌روزرسانی کنند');
    });

    test('versionCode و versionName از pubspec می‌آید', () {
      expect(gradle.contains('versionCode = flutter.versionCode'), isTrue);
      expect(gradle.contains('versionName = flutter.versionName'), isTrue);
    });

    test('خروجی release قابل دیباگ نیست', () {
      expect(gradle.contains('isDebuggable = false'), isTrue);
    });
  });

  group('نسخه‌ها با هم می‌خوانند', () {
    test('نسخه‌ی pubspec با AppConstants یکی است و از ۱.۰.۴+۴ بزرگ‌تر است', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(r'^version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)',
              multiLine: true)
          .firstMatch(pubspec);
      expect(match, isNotNull, reason: 'نسخه در pubspec.yaml پیدا نشد');

      final name = '${match!.group(1)}.${match.group(2)}.${match.group(3)}';
      final build = int.parse(match.group(4)!);

      expect(AppConstants.appVersion, name, reason: 'نوار نسخه‌ی برنامه با pubspec یکی باشد');
      expect(build, greaterThan(4),
          reason: 'versionCode باید از نسخه‌ی نصب‌شده (۱.۰.۴+۴) بزرگ‌تر باشد تا اندروید به‌روزرسانی را بپذیرد');
    });
  });

  group('مهاجرت هیچ‌وقت داده‌ای را پاک نمی‌کند', () {
    List<File> migrationSources() => <File>[
          File('lib/database/app_database.dart'),
          File('lib/core/migration/app_migration.dart'),
          File('lib/core/migration/migration_steps.dart'),
        ];

    test('دستورهای مخرب SQL در کد مهاجرت وجود ندارد', () {
      for (final file in migrationSources()) {
        final source = file.readAsStringSync().toUpperCase();
        for (final forbidden in <String>['DROP TABLE', 'DELETE FROM', 'TRUNCATE', 'VACUUM']) {
          expect(source.contains(forbidden), isFalse,
              reason: '${file.path} نباید «$forbidden» داشته باشد؛ داده‌ی کاربر باید دست‌نخورده بماند');
        }
      }
    });

    test('مهاجرت داده‌های ذخیره‌شده را حذف نمی‌کند', () {
      final source = File('lib/core/migration/migration_steps.dart').readAsStringSync();
      expect(source.contains('PrefsStore.clear'), isFalse);
      final prefs = File('lib/core/utils/prefs_store.dart').readAsStringSync();
      expect(prefs.contains('.clear()'), isFalse,
          reason: 'پاک کردن کل SharedPreferences یعنی از بین رفتن اطلاعات کاربر');
    });

    test('مهاجرت گام‌به‌گام و قابل ازسرگیری است', () {
      final source = File('lib/core/migration/app_migration.dart').readAsStringSync();
      expect(source.contains('kMigrationLedger'), isTrue,
          reason: 'دفتر مهاجرت باید ذخیره شود تا اجرای نیمه‌کاره از همان‌جا ادامه یابد');
      expect(source.contains('completed'), isTrue);
    });
  });
}
