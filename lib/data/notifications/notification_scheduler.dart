import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Abstraction over the platform daily-reminder scheduler.
///
/// Implemented natively (Kotlin + AlarmManager) behind a MethodChannel —
/// no third-party notification dependency. A no-op implementation is used
/// on unsupported platforms and in tests.
abstract class NotificationScheduler {
  Future<bool> initialize();
  Future<bool> requestPermission();
  Future<void> scheduleDaily(int hour, int minute);
  Future<void> cancel();
}

const MethodChannel _channel = MethodChannel('app/notifications');

class AndroidNotificationScheduler implements NotificationScheduler {
  const AndroidNotificationScheduler();

  @override
  Future<bool> initialize() async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('initialize');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> scheduleDaily(int hour, int minute) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('scheduleDaily', {
        'hour': hour,
        'minute': minute,
      });
    } on PlatformException {
      // Notification unavailable — handled gracefully (spec §36).
    } on MissingPluginException {
      // Tests / unsupported platform.
    }
  }

  @override
  Future<void> cancel() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('cancel');
    } on PlatformException {
      // ignore — best effort.
    } on MissingPluginException {
      // Tests / unsupported platform.
    }
  }
}

class NoopNotificationScheduler implements NotificationScheduler {
  const NoopNotificationScheduler();

  @override
  Future<bool> initialize() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleDaily(int hour, int minute) async {}

  @override
  Future<void> cancel() async {}
}
