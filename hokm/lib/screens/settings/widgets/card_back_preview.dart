import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../game/cards/card_renderer.dart';
import '../../../storage/settings_model.dart';

/// پیش‌نمایش طرح پشت کارت در تنظیمات — با همان رندر واقعی.
class CardBackPreview extends StatelessWidget {
  const CardBackPreview({
    super.key,
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final CardBackStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.gold : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: AppTheme.gold.withOpacity(0.3),
                      blurRadius: 12)
                ]
              : null,
        ),
        child: CustomPaint(
          size: const Size(58, 82),
          painter: _PreviewPainter(style),
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.style);

  final CardBackStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawShadow(
        Path()
          ..addRRect(RRect.fromRectAndRadius(
              rect, Radius.circular(CardRenderer.radius(size.width)))),
        Colors.black,
        5,
        true);
    CardRenderer.paintBack(canvas, rect, style);
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.style != style;
}
