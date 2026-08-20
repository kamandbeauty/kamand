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

const _faOrdinals = [
  'اول', 'دوم', 'سوم', 'چهارم', 'پنجم', // ۵
  'ششم', 'هفتم', 'هشتم', 'نهم', 'دهم', // ۱۰
  'یازدهم', 'دوازدهم', 'سیزدهم', 'چهاردهم', 'پانزدهم', // ۱۵
  'شانزدهم', 'هفدهم', 'هجدهم', 'نوزدهم', 'بیستم', // ۲۰
];

/// ترتیبی فارسی: ۱ → «اول»، ۲ → «دوم»، … (خارج از بازه: «۲۱م»).
String persianOrdinal(int n) {
  if (n >= 1 && n <= _faOrdinals.length) return _faOrdinals[n - 1];
  return '${toPersianDigits(n)}م';
}
