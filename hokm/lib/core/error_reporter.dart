import 'dart:ui';

import 'package:flutter/foundation.dart';

/// گزارش‌گر مرکزی خطاها — خطاهای فریم‌ورک (build/layout/paint) و
/// خطاهای asyncِ مهارنشده را در یک محل قابل‌مشاهده نگه می‌دارد تا
/// به‌جای «صفحهٔ خاکستری» در release، متن خطا دیده و گزارش شود.
///
/// رفتار کنسول (چاپ help خطا) دست‌نخورده می‌ماند.
class AppErrorReporter {
  AppErrorReporter._();

  /// آخرین خطای ثبت‌شده — UI می‌تواند آن را نشان دهد.
  static final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  static bool _installed = false;

  /// نصب یک‌بارهٔ handlerها (در main قبل از runApp).
  static void install() {
    if (_installed) return;
    _installed = true;

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      lastError.value = details.exceptionAsString();
      previous?.call(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      lastError.value = error.toString();
      debugPrint('Unhandled async error: $error\n$stack');
      // به رفتار پیش‌فرض ادامه بده.
      return false;
    };
  }
}
