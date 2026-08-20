import 'dart:ui';

import '../../storage/settings_model.dart';

/// پالت رنگی میز — هر تم یک حس متفاوت (رویه‌ای، بدون بافت تصویری).
class TablePalette {
  const TablePalette({
    required this.feltCenter,
    required this.feltEdge,
    required this.rimOuter,
    required this.rimInner,
    required this.rimHighlight,
    required this.accent,
    required this.patternLines,
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

  static TablePalette of(TableTheme theme) => switch (theme) {
        TableTheme.classicGreen => const TablePalette(
            feltCenter: Color(0xFF2F7A4F),
            feltEdge: Color(0xFF14422A),
            rimOuter: Color(0xFF3A2415),
            rimInner: Color(0xFF6B4423),
            rimHighlight: Color(0xFF8F612F),
            accent: Color(0xFFE7C77B),
            patternLines: Color(0x1AFFF3D0),
          ),
        TableTheme.midnightBlue => const TablePalette(
            feltCenter: Color(0xFF2C4E86),
            feltEdge: Color(0xFF121F3D),
            rimOuter: Color(0xFF1A1A24),
            rimInner: Color(0xFF3A3F5C),
            rimHighlight: Color(0xFF5A6287),
            accent: Color(0xFF9CC3FF),
            patternLines: Color(0x1ABCDBFF),
          ),
        TableTheme.royalRed => const TablePalette(
            feltCenter: Color(0xFF8A3038),
            feltEdge: Color(0xFF471318),
            rimOuter: Color(0xFF231510),
            rimInner: Color(0xFF4C2E1C),
            rimHighlight: Color(0xFF7A4E2D),
            accent: Color(0xFFF4CE84),
            patternLines: Color(0x1AFFD9B0),
          ),
      };
}
