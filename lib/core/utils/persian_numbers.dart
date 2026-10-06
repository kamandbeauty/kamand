/// Persian digit + number formatting helpers used across the UI.
///
/// All user-facing numbers go through this class so the app consistently
/// renders Persian digits (۰۱۲۳۴۵۶۷۸۹).
class PersianNumbers {
  PersianNumbers._();

  static const List<String> _en = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  ];
  static const List<String> _fa = [
    '۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹',
  ];

  /// Converts any Latin digits found in [input] into Persian digits.
  static String toPersian(String input) {
    var result = input;
    for (var i = 0; i < _en.length; i++) {
      result = result.replaceAll(_en[i], _fa[i]);
    }
    return result;
  }

  static String toPersianNum(num input) => toPersian(input.toString());

  /// Formats an integer with thousand separators, in Persian digits.
  static String format(int value) {
    final s = value.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final remaining = s.length - i;
      buf.write(s[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buf.write('٬');
      }
    }
    return '${value < 0 ? '−' : ''}${toPersian(buf.toString())}';
  }

  /// "۸۲٪" — score display with Persian percent sign.
  static String percent(int score) => '${toPersian(score.toString())}٪';

  /// Zero-padded two-digit Persian number, e.g. 5 → "۰۵".
  static String twoDigits(int value) =>
      toPersian(value.toString().padLeft(2, '0'));

  /// Parses Persian or Latin digits from user input into an int, or null.
  static int? tryParse(String input) {
    var latin = input.trim();
    for (var i = 0; i < _fa.length; i++) {
      latin = latin.replaceAll(_fa[i], _en[i]);
    }
    // Also tolerate Arabic-Indic digits.
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (var i = 0; i < arabic.length; i++) {
      latin = latin.replaceAll(arabic[i], _en[i]);
    }
    return int.tryParse(latin);
  }
}
