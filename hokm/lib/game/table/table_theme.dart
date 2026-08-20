import 'dart:ui';

import '../../storage/settings_model.dart';

/// پالت رنگی میز — هر تم یک حس متفاوت (رویه‌ای، بدون بافت تصویری).
///
/// نسخهٔ بازطراحی‌شده: علاوه بر رنگ‌های قبلی، رنگ‌های نقشِ گره‌چینی،
/// لعابِ فیروزه‌ای و هالهٔ نورِ میز هم اضافه شده‌اند.
class TablePalette {
  const TablePalette({
    required this.feltCenter,
    required this.feltEdge,
    required this.rimOuter,
    required this.rimInner,
    required this.rimHighlight,
    required this.accent,
    required this.patternLines,
    this.medallion = const Color(0x33FFE7AE),
    this.glaze = const Color(0xFF2FA8A0),
    this.lightWash = const Color(0x1AFFFFFF),
  });

  /// مرکز روشنِ فرش.
  final Color feltCenter;

  /// لبهٔ تیرهٔ فرش.
  final Color feltEdge;

  /// بدنهٔ بیرونی میز.
  final Color rimOuter;
  final Color rimInner;

  /// برق لبهٔ داخلی.
  final Color rimHighlight;

  /// رنگ تأکید (خطوط دکور، گلوی نوبت).
  final Color accent;

  /// خطوط نقش‌مایهٔ ظریف فرش.
  final Color patternLines;

  /// رنگ شمسهٔ مرکزی میز.
  final Color medallion;

  /// لعابِ کاشیِ حاشیه.
  final Color glaze;

  /// شست‌وشوی نورِ متحرک روی فرش.
  final Color lightWash;

  static TablePalette of(TableTheme theme) => switch (theme) {
        // سبزِ کلاسیک، اما با لعاب فیروزه و تذهیب طلایی
        TableTheme.classicGreen => const TablePalette(
            feltCenter: Color(0xFF2C7F63),
            feltEdge: Color(0xFF0E3327),
            rimOuter: Color(0xFF2A1A10),
            rimInner: Color(0xFF6A4423),
            rimHighlight: Color(0xFFA9762F),
            accent: Color(0xFFE8C46B),
            patternLines: Color(0x1FFFF0C8),
            medallion: Color(0x3DFFE7AE),
            glaze: Color(0xFF2FA8A0),
            lightWash: Color(0x1AFFF6DF),
          ),
        // شبِ لاجوردیِ کاشیِ مسجد
        TableTheme.midnightBlue => const TablePalette(
            feltCenter: Color(0xFF23477F),
            feltEdge: Color(0xFF0A1428),
            rimOuter: Color(0xFF11121C),
            rimInner: Color(0xFF2F3550),
            rimHighlight: Color(0xFF6B76A6),
            accent: Color(0xFF9FD8FF),
            patternLines: Color(0x24CFE6FF),
            medallion: Color(0x3D9FE9FF),
            glaze: Color(0xFF3FB7C9),
            lightWash: Color(0x1AD8ECFF),
          ),
        // شنگرفِ قالیِ کاشان
        TableTheme.royalRed => const TablePalette(
            feltCenter: Color(0xFF8E2E38),
            feltEdge: Color(0xFF3B0F14),
            rimOuter: Color(0xFF1F120D),
            rimInner: Color(0xFF4E2F1C),
            rimHighlight: Color(0xFF9A6634),
            accent: Color(0xFFF6D28C),
            patternLines: Color(0x24FFDCB4),
            medallion: Color(0x42FFE0AA),
            glaze: Color(0xFF2B8F86),
            lightWash: Color(0x1AFFE9CF),
          ),
      };
}
