import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// جمع‌کنندهٔ خطاهای اجرایی برای گزارش‌دهی به توسعه‌دهنده.
///
/// همهٔ خطاهای رخ‌داده روی دستگاهِ کاربر (از جمله خطاهای Flutter و
/// خطاهای async) فقط به‌صورت محلی ذخیره می‌شوند؛ هیچ داده‌ای به‌صورت
/// خودکار به اینترنت فرستاده نمی‌شود. کاربر می‌تواند از بخش
/// «تنظیمات → گزارش مشکل» گزارش را خودش به هر روشی (واتساپ، تلگرام،
/// ایمیل و…) برای توسعه‌دهنده بفرستد.
class ErrorReporter {
  ErrorReporter._();

  static const String _kErrorLog = 'error_log_v1';

  /// بیشینهٔ خطاهای نگه‌داری‌شده (قدیمی‌ترها حذف می‌شوند)
  static const int maxEntries = 20;

  static bool _initialized = false;

  /// آیا خطای گزارش‌نشده‌ای وجود دارد؟ (از روی کش درون حافظه)
  static int get pendingCount => _pending.length;
  static List<String> _pending = [];

  /// نصب گیرنده‌های خطا — فقط یک‌بار و قبل از runApp صدا زده می‌شود.
  static void init() {
    if (_initialized) return;
    _initialized = true;

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      record(details.exceptionAsString(), details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      record(error.toString(), stack);
      // true یعنی خطا «رسیدگی شده» و اپ کرش نمی‌کند؛
      // خطاهای جدی سیستمی همچنان توسط سیستم‌عامل گزارش می‌شوند.
      return true;
    };

    _restore();
  }

  /// ثبت یک خطا (زمان + پیام + سر تِرِیِس پشته) — بدون اختلال در UI
  static void record(String message, [StackTrace? stack]) {
    final time = DateTime.now().toIso8601String().substring(0, 19);
    final sb = StringBuffer('$time\n$message');
    if (stack != null) {
      final lines = stack.toString().trim().split('\n');
      sb.write('\n${lines.take(6).join('\n')}');
    }
    final entry = sb.toString();
    _pending.insert(0, entry);
    if (_pending.length > maxEntries) {
      _pending = _pending.sublist(0, maxEntries);
    }
    _save();
  }

  /// متن کامل گزارش برای ارسال به توسعه‌دهنده
  static String buildReport({required String appVersion}) {
    final sb = StringBuffer()
      ..writeln('گزارش خطای برنامهٔ «دیوان و فال حافظ»')
      ..writeln('نسخهٔ برنامه: $appVersion')
      ..writeln('زمان گزارش: ${DateTime.now().toIso8601String().substring(0, 19)}')
      ..writeln('تعداد خطاها: ${_pending.length}')
      ..writeln('─' * 24);
    for (var i = 0; i < _pending.length; i++) {
      sb
        ..writeln('\nخطای ${i + 1}:')
        ..writeln(_pending[i]);
    }
    if (_pending.isEmpty) sb.write('\nخطایی ثبت نشده است.');
    return sb.toString();
  }

  /// پاک کردن همهٔ خطاهای ثبت‌شده (معمولاً پس از ارسال گزارش)
  static Future<void> clear() async {
    _pending = [];
    await _save();
  }

  static Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pending = prefs.getStringList(_kErrorLog) ?? [];
    } catch (_) {
      // خواندن از حافظه شکست خورد؛ از صفر شروع می‌کنیم
      _pending = [];
    }
  }

  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kErrorLog, _pending);
    } catch (_) {
      // اگر ذخیره نشد، گزارش در همین اجرا در حافظه می‌ماند
    }
  }
}
