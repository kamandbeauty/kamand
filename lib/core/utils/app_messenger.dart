import 'package:flutter/material.dart';

/// پیام‌های سراسری برنامه (مثلاً نتیجه‌ی به‌روزرسانی داده‌ها هنگام باز شدن
/// نسخه‌ی جدید) از روی این کلید نمایش داده می‌شوند تا وابسته به صفحه‌ی
/// جاری نباشند.
class AppMessenger {
  AppMessenger._();

  static final GlobalKey<ScaffoldMessengerState> key =
      GlobalKey<ScaffoldMessengerState>();

  static void show(String message, {bool isError = false}) {
    final messenger = key.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFB91C1C) : null,
        duration: const Duration(seconds: 6),
      ),
    );
  }
}
