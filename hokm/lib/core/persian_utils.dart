/// ابزارهای فارسی — تبدیل اعداد و رشته‌های مشترک UI.
library;

const _enDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
const _faDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

/// تبدیل ارقام لاتین به فارسی.
String toPersianDigits(Object value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (final ch in text.codeUnits) {
    final c = String.fromCharCode(ch);
    final idx = _enDigits.indexOf(c);
    buffer.write(idx >= 0 ? _faDigits[idx] : c);
  }
  return buffer.toString();
}
