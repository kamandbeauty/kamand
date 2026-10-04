import 'dart:ui';

import 'package:fale_hafez/fonts.dart';
import 'package:flutter/material.dart';

/// دکمهٔ شیشه‌ای (گلس‌مورفیسم): نیمه‌شفاف با تاری پس‌زمینه،
/// حاشیهٔ نورانی و سایهٔ نرم — برای استفاده روی تصاویر پس‌زمینهٔ مینیاتوری.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconSize = 26,
    this.fontSize = 18,
    this.fontWeight = FontWeight.w800,
    this.height = 60,
    this.radius = 20,
    this.tint = Colors.white,
    this.tintOpacity = 0.16,
    this.borderOpacity = 0.38,
    this.textColor = Colors.white,
    this.iconColor = Colors.white,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double iconSize;
  final double fontSize;
  final FontWeight fontWeight;
  final double height;
  final double radius;

  /// رنگ تنت شیشه (پیش‌فرض سفید؛ برای دکمهٔ اصلی طلایی شود)
  final Color tint;
  final double tintOpacity;
  final double borderOpacity;

  /// رنگ متن و آیکون (پیش‌فرض سفید؛ روی زمینهٔ روشن تیره شود)
  final Color textColor;
  final Color iconColor;

  /// اگر true باشد کل عرض موجود را می‌گیرد
  final bool expand;

  static const List<Shadow> _textShadow = [
    Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
  ];

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              child: Ink(
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      tint.withOpacity(enabled ? tintOpacity + 0.10 : 0.06),
                      tint.withOpacity(enabled ? tintOpacity : 0.04),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(
                        enabled ? borderOpacity : borderOpacity / 2),
                    width: 1.6,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          color: iconColor.withOpacity(enabled ? 1 : 0.5),
                          size: iconSize,
                          shadows: _textShadow,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        label,
                        textDirection: TextDirection.rtl,
                        style: vazirText(
                          fontSize: fontSize,
                          fontWeight: fontWeight,
                          color: textColor.withOpacity(enabled ? 1 : 0.55),
                        ).copyWith(shadows: _textShadow),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// دکمهٔ دایره‌ای شیشه‌ای برای نوار بالایی (موسیقی، درباره و...)
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 46,
    this.iconSize = 24,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              child: Ink(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withOpacity(0.16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 1.4,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: iconSize,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
