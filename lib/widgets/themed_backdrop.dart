import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Theme-driven backdrop behind every route of the app.
///
/// For the velvet-night skin (the design-reference look) it layers:
///  * the generated midnight-nebula artwork, full-bleed under the UI
///    (the skin's scaffold is transparent so it shows through), and
///  * the ornamental cream hairline frame with antique-gold corner
///    accents — the tarot-card signature of the reference screens.
///
/// Other skins declare neither, so this widget passes the child through
/// untouched (zero extra cost).
class ThemedBackdrop extends StatelessWidget {
  const ThemedBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<SkyPalette>();
    final asset = palette?.backgroundAsset;
    final frame = palette?.ornateFrame ?? false;
    if (asset == null && !frame) return child;

    return Stack(
      children: [
        if (asset != null)
          Positioned.fill(
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            ),
          ),
        child,
        if (frame)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                foregroundPainter: _OrnateFramePainter(
                  cream: palette?.star.withValues(alpha: 1) ??
                      AppTheme.darkText,
                  gold: palette?.starGold.withValues(alpha: 1) ??
                      AppTheme.gold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Hairline cream frame + gold corner accents — painted, no assets.
class _OrnateFramePainter extends CustomPainter {
  _OrnateFramePainter({required this.cream, required this.gold});

  final Color cream;
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 9.0;
    const radius = 20.0;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final rrect =
        RRect.fromRectAndRadius(rect, const Radius.circular(radius));

    // Main hairline — warm moonlit cream, like the reference frame.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = cream.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Inner whisper line — antique gold.
    final inner = RRect.fromRectAndRadius(
      rect.deflate(4),
      const Radius.circular(radius - 3),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..color = gold.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Gold corner accents riding along the frame edges.
    final tick = Paint()
      ..color = gold.withValues(alpha: 0.55)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    const len = 24.0;
    const off = 34.0;
    void line(Offset a, Offset b) => canvas.drawLine(a, b, tick);

    // top & bottom edges
    line(Offset(rect.left + off, rect.top),
        Offset(rect.left + off + len, rect.top));
    line(Offset(rect.right - off - len, rect.top),
        Offset(rect.right - off, rect.top));
    line(Offset(rect.left + off, rect.bottom),
        Offset(rect.left + off + len, rect.bottom));
    line(Offset(rect.right - off - len, rect.bottom),
        Offset(rect.right - off, rect.bottom));
    // left & right edges
    line(Offset(rect.left, rect.top + off),
        Offset(rect.left, rect.top + off + len));
    line(Offset(rect.left, rect.bottom - off - len),
        Offset(rect.left, rect.bottom - off));
    line(Offset(rect.right, rect.top + off),
        Offset(rect.right, rect.top + off + len));
    line(Offset(rect.right, rect.bottom - off - len),
        Offset(rect.right, rect.bottom - off));
  }

  @override
  bool shouldRepaint(covariant _OrnateFramePainter old) =>
      old.cream != cream || old.gold != gold;
}
