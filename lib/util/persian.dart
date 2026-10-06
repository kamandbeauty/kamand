/// کمک‌تابع‌های نمایش فارسی.
library;

const String _digits = '۰۱۲۳۴۵۶۷۸۹';

/// تبدیل ارقام لاتین به فارسی.
String fa(Object value) => value.toString().replaceAllMapped(
      RegExp(r'\d'),
      (Match m) => _digits[int.parse(m.group(0)!)],
    );

/// نمایش امتیاز با علامت (مثلاً «−۱۶۵» یا «+۱۲۵»).
String faSigned(int value) {
  if (value == 0) return '۰';
  final String body = fa(value.abs());
  return value > 0 ? '+$body' : '−$body';
}
