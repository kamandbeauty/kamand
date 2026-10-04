import 'package:flutter/material.dart';

/// دکمه‌های هماهنگ با تم اصلی اپ (لاجورد + طلایی) برای همهٔ صفحات داخلی —
/// جایگزین نارنجی/زردِ قدیمی؛ صفحهٔ اصلی سبک اختصاصی خودش را دارد.
class AppThemeButton {
  AppThemeButton._();

  /// لاجوردِ اصلی تم (هم‌خانوادهٔ پس‌زمینهٔ خانه)
  static const Color navy = Color(0xFF14263D);

  /// طلاییِ تم (هم‌خانوادهٔ قاب‌ها و لهجه‌ها)
  static const Color gold = Color(0xFFF0B45C);

  /// سبک مشترک دکمه‌های داخلی: بدنهٔ لاجورد، حاشیهٔ ظریف طلایی، سایهٔ نرم
  static ButtonStyle style({
    double radius = 10,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 18,
      vertical: 12,
    ),
  }) {
    return ElevatedButton.styleFrom(
      foregroundColor: gold,
      backgroundColor: navy,
      shadowColor: Colors.black54,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: gold.withOpacity(0.45), width: 1.2),
      ),
      padding: padding,
    );
  }

  /// دکمهٔ آیکون‌دار هدر (بازگشت و…)
  static Widget icon({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 36,
    double radius = 10,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: ElevatedButton(
        onPressed: onPressed,
        style: style(radius: radius, padding: EdgeInsets.zero),
        child: Icon(icon, color: gold),
      ),
    );
  }
}
