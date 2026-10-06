/// نرمال‌سازی متن فارسی/عربی برای جستجوی قابل‌اتکا در دیوان.
///
/// بسیاری از ناموفق بودن‌های جستجو به تفاوتِ حروف هم‌ریخت برمی‌گردد —
/// مثلاً کاربر «ي» عربی یا «ك» عربی تایپ می‌کند درحالی‌که متن با
/// «ی» و «ک» فارسی ذخیره شده. این تابع متن را به قالب یکپارچه می‌رساند:
///
/// * یکدست‌سازی حروف هم‌ریخت (ي/ی، ك/ک، ة/ه، أ/ا و مانند آن‌ها)
/// * حذف اعراب عربی و کشیدهٔ حروف (ـ)
/// * تبدیل نیم‌فاصله/اتصال غیرقابل‌مشاهده به فاصلهٔ معمولی
/// * تبدیل ارقام فارسی و عربی به ارقام لاتین
/// * فشرده‌سازی فاصله‌های پیاپی و trim
library;

/// نسخهٔ نرمال‌شدهٔ [input] برای جستجو و مقایسه
String normalizePersian(String input) {
  var text = input;

  const replacements = <String, String>{
    // ی و ک عربی → فارسی
    'ي': 'ی',
    'ى': 'ی',
    'ئ': 'ی',
    'ك': 'ک',
    // ه‌های عربی → فارسی
    'ة': 'ه',
    'ۀ': 'ه',
    'ھ': 'ه',
    // همزه‌های بالای الف → الف ساده
    'أ': 'ا',
    'إ': 'ا',
    'ٱ': 'ا',
    // واو همزه‌دار
    'ؤ': 'و',
  };
  replacements.forEach((from, to) {
    text = text.replaceAll(from, to);
  });

  // حذف اعراب عربی (فتحه..تنوین..سکون)، تلفیق U+0670 (الف خنجریه)
  // و کشیدهٔ حروف (تطویل)
  text = text.replaceAll(RegExp('[ً-ْٰـ]'), '');

  // نیم‌فاصله و سایر جداکننده‌های نامرئی → فاصلهٔ معمولی
  // (اسکیپ یونیکد: کدپوینت‌های کنترلیِ جهت نباید خام در سورس باشند)
  text = text.replaceAll(
      RegExp('[\\u200C\\u200D\\u200E\\u200F\\u202A-\\u202E\\u2066-\\u2069]'),
      ' ');

  // ارقام فارسی و عربی → لاتین تا جستجوی شمارهٔ شعر فارسی هم کار کند
  text = text.replaceAllMapped(RegExp('[۰-۹٠-٩]'), (match) {
    final unit = match.group(0)!.codeUnitAt(0);
    // الفبای فارسی از U+06F0 و عربی از U+0660 شروع می‌شوند
    if (unit >= 0x06F0 && unit <= 0x06F9) return '${unit - 0x06F0}';
    return '${unit - 0x0660}';
  });

  // فشرده‌سازی فاصله‌های پیاپی
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// آیا [haystack] (متن شعر/عنوان) شامل عبارت جستجوی [query] هست؟
/// هر دو ورودی پیش از مقایسه نرمال می‌شوند.
bool persianContains(String haystack, String query) =>
    normalizePersian(haystack).contains(normalizePersian(query));

/// تبدیل ارقام لاتین هر رشته به ارقام فارسی برای نمایش
String toPersianDigits(String input) {
  const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    final code = c.codeUnitAt(0);
    if (code >= 0x30 && code <= 0x39) {
      buffer.write(fa[code - 0x30]);
    } else {
      buffer.write(c);
    }
  }
  return buffer.toString();
}
