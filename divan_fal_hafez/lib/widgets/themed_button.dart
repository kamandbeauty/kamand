import 'package:fale_hafez/fonts.dart';
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

  /// دکمهٔ برچسب‌دار فشردهٔ لاجورد+طلایی برای اقدام‌ها و پیمایش‌ها
  /// (طرح یکدستِ تم اپ — جایگزین دکمه‌های شیشه‌ایِ نارنجیِ قدیمی)
  static Widget labeled({
    required String label,
    IconData? icon,
    required VoidCallback? onPressed,
    double height = 48,
    double fontSize = 14,
    double radius = 12,
  }) {
    final enabled = onPressed != null;
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: gold,
          backgroundColor: navy,
          disabledForegroundColor: gold.withOpacity(0.35),
          disabledBackgroundColor: navy.withOpacity(0.45),
          shadowColor: Colors.black54,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(
              color: gold.withOpacity(enabled ? 0.45 : 0.18),
              width: 1.1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 18, color: gold.withOpacity(enabled ? 1 : 0.35)),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              textDirection: TextDirection.rtl,
              style: vazirText(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: gold.withOpacity(enabled ? 1 : 0.35),
              ),
            ),
          ],
        ),
      ),
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
