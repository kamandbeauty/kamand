import 'package:flutter/services.dart';
import 'persian_number_formatter.dart';

/// جداکننده هزارگان هنگام تایپ (۱۲۳۴۵۶۷ → ۱,۲۳۴,۵۶۷)
class ThousandSeparatorInputFormatter extends TextInputFormatter {
  final bool allowDecimal;
  final bool persianDigits;

  ThousandSeparatorInputFormatter({
    this.allowDecimal = true,
    this.persianDigits = true,
  });

  static String faToEn(String s) {
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    var r = s;
    for (var i = 0; i < 10; i++) {
      r = r.replaceAll(fa[i], en[i]);
    }
    return r;
  }

  /// فقط ارقام (+ نقطه اعشار اختیاری)
  static String digitsOnly(String s, {bool allowDecimal = true}) {
    var t = faToEn(s).replaceAll(',', '').replaceAll('٬', '').replaceAll(' ', '');
    if (allowDecimal) {
      t = t.replaceAll(RegExp(r'[^0-9.]'), '');
      final parts = t.split('.');
      if (parts.length > 2) {
        t = '${parts.first}.${parts.sublist(1).join()}';
      }
    } else {
      t = t.replaceAll(RegExp(r'[^0-9]'), '');
    }
    return t;
  }

  /// فرمت نمایش با جداکننده
  static String formatDisplay(
    String raw, {
    bool allowDecimal = true,
    bool persianDigits = true,
  }) {
    final clean = digitsOnly(raw, allowDecimal: allowDecimal);
    if (clean.isEmpty) return '';

    String intPart;
    String? decPart;
    if (allowDecimal && clean.contains('.')) {
      final i = clean.indexOf('.');
      intPart = clean.substring(0, i);
      decPart = clean.substring(i + 1);
    } else {
      intPart = clean.replaceAll('.', '');
      decPart = null;
    }

    // جلوگیری از صفرهای پیشرو بی‌مورد ولی نگه داشتن "0"
    if (intPart.length > 1) {
      intPart = intPart.replaceFirst(RegExp(r'^0+'), '');
      if (intPart.isEmpty) intPart = '0';
    }

    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      final fromEnd = intPart.length - i;
      buf.write(intPart[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    var out = buf.toString();
    if (decPart != null) {
      out = '$out.$decPart';
    }
    if (persianDigits) {
      out = PersianNumberFormatter.toPersian(out);
    }
    return out;
  }

  static double? parseToDouble(String s) {
    final clean = digitsOnly(s, allowDecimal: true);
    if (clean.isEmpty) return null;
    return double.tryParse(clean);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatDisplay(
      newValue.text,
      allowDecimal: allowDecimal,
      persianDigits: persianDigits,
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// گروه‌بندی ۴تایی شماره کارت بدون برعکس شدن (LTR)
String formatCardGrouped(String cardNumber) {
  final d = ThousandSeparatorInputFormatter.faToEn(cardNumber)
      .replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return '';
  final buf = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i > 0 && i % 4 == 0) buf.write(' - ');
    buf.write(d[i]);
  }
  return PersianNumberFormatter.toPersian(buf.toString());
}
