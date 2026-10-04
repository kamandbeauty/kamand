import 'package:flutter/material.dart';

/// استایل متن برنامه با قلم انتخابی کاربر.
///
/// خانوادهٔ قلم عمداً مشخص نمی‌شود تا از قلم تم برنامه
/// (که با انتخاب کاربر در تنظیمات تغییر می‌کند) تبعیت کند.
TextStyle vazirText({
  FontWeight? fontWeight,
  double? fontSize,
  Color? color,
  double? height,
  String? fontFamily,
}) {
  return TextStyle(
    fontFamily: fontFamily,
    fontWeight: fontWeight,
    fontSize: fontSize,
    color: color,
    height: height,
  );
}

/// قلم‌های داخلی قابل انتخاب برای اشعار و رابط برنامه
const Map<String, String> poemFontFamilies = {
  'vazirmatn': 'Vazirmatn',
  'sahel': 'Sahel',
  'shabnam': 'Shabnam',
  'nastaliq': 'Nastaliq',
};

/// نام فارسی قلم‌ها برای نمایش در تنظیمات
const Map<String, String> poemFontLabels = {
  'vazirmatn': 'وزیرمتن',
  'sahel': 'ساحل',
  'shabnam': 'شبنم',
  'nastaliq': 'نستعلیق',
};

const String defaultPoemFontKey = 'vazirmatn';

/// نام خانوادهٔ قلم متناسب با کلید ذخیره‌شده در تنظیمات
String poemFontFamily(String key) =>
    poemFontFamilies[key] ?? poemFontFamilies[defaultPoemFontKey]!;
