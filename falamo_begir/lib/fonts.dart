import 'package:flutter/material.dart';

/// استایل متن با فونت داخلی «وزیرمتن».
///
/// فونت داخل assets برنامه قرار دارد؛ برخلاف google_fonts
/// برای اولین اجرا به اینترنت نیاز ندارد و متون فارسی
/// همیشه (حتی آفلاین) با تایپوگرافی درست نمایش داده می‌شوند.
TextStyle vazirText({
  FontWeight? fontWeight,
  double? fontSize,
  Color? color,
}) {
  return TextStyle(
    fontFamily: 'Vazirmatn',
    fontWeight: fontWeight,
    fontSize: fontSize,
    color: color,
  );
}
