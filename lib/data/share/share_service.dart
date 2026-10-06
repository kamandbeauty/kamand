import 'package:flutter/services.dart';

/// Shares text through the native Android share sheet via a private
/// MethodChannel — no third-party plugin dependency (spec §3/§59).
class ShareService {
  ShareService._();

  static const MethodChannel _channel = MethodChannel('app/share');

  /// Opens the system share sheet with [text]. Never throws — failures
  /// (e.g. no share target, or running in tests) are swallowed.
  static Future<void> share(String text, {String subject = 'طالع بین'}) async {
    try {
      await _channel.invokeMethod<bool>('shareText', {
        'text': text,
        'subject': subject,
      });
    } on MissingPluginException {
      // Not available (tests / unsupported platform) — ignore.
    } on PlatformException {
      // No share target available — ignore.
    } catch (_) {
      // Never let sharing break the screen.
    }
  }
}
