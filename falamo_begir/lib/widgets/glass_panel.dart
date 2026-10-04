import 'dart:ui';

import 'package:flutter/material.dart';

/// قاب شیشه‌ای (گلس‌مورفیسم) برای محتوای قرارگرفته روی تصویر پس‌زمینه —
/// عنوان‌ها، هدر و متن اشعار را از نقش‌های پس‌زمینه جدا و خوانا می‌کند.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.tint = Colors.white,
    this.tintOpacity = 0.16,
    this.borderOpacity = 0.38,
    this.radius = 20,
    this.blur = 14,
    this.padding,
    this.margin,
    this.shadowOpacity = 0.25,
  });

  final Widget child;

  /// رنگ تنت شیشه
  final Color tint;
  final double tintOpacity;
  final double borderOpacity;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double shadowOpacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(shadowOpacity),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tint.withOpacity(tintOpacity + 0.08),
                  tint.withOpacity(tintOpacity),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(borderOpacity),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
