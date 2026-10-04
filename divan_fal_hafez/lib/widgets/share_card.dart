import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:fale_hafez/widgets/themed_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

/// کارت تصویری اشتراک‌گذاری شعر/فال: کاغذِ کرم با قاب دوتاییِ طلایی،
/// متن شعر با قلم زیبا و امضای «دیوان و فال حافظ» — مناسب استوری و
/// وضعیت شبکه‌های اجتماعی.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.title,
    required this.verses,
    this.meaning,
    this.width = 340,
  });

  /// تیتر کارت - مثل «غزل ۴۸» یا «فالِ شما»
  final String title;

  /// متن شعر (چندخطی)
  final String verses;

  /// تعبیر فال (اختیاری)
  final String? meaning;

  /// عرض منطقی کارت هنگام رندر
  final double width;

  static const Color _paper = Color(0xFFF8EEDB);
  static const Color _ink = Color(0xFF4A2E12);
  static const Color _gold = Color(0xFFB8860B);

  @override
  Widget build(BuildContext context) {
    // تعبیر کوتاه‌نمايي‌شده تا کارت از حد استوری بیرون نزند
    final meaningText = meaning == null
        ? null
        : (meaning!.length > 280 ? '${meaning!.substring(0, 280)}…' : meaning);

    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _gold.withOpacity(0.85),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold.withOpacity(0.55), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ornament(),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: vazirText(
                fontFamily: 'Sahel',
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 1.2,
              width: width * 0.5,
              color: _gold.withOpacity(0.6),
            ),
            const SizedBox(height: 14),
            Text(
              verses,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: vazirText(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _ink,
                height: 2.1,
              ),
            ),
            if (meaningText != null && meaningText.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'تعبیر فال',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: vazirText(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _gold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                meaningText,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: vazirText(fontSize: 12.5, color: _ink, height: 1.9),
              ),
            ],
            const SizedBox(height: 16),
            _ornament(),
            const SizedBox(height: 8),
            Text(
              'دیوان و فال حافظ',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: vazirText(
                fontSize: 11.5,
                color: _ink.withOpacity(0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// لوزیِ زینتی طلایی (الماسِ کتابت)
  Widget _ornament() {
    return SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _DiamondPainter(_gold)),
    );
  }
}

class _DiamondPainter extends CustomPainter {
  const _DiamondPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.72, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.72, c.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(c, r * 0.22, Paint()..color = const Color(0xFFF8EEDB));
  }

  @override
  bool shouldRepaint(_DiamondPainter old) => old.color != color;
}

/// برگهٔ انتخاب نوع اشتراک: پیش‌نمایش کارت + دکمه‌های «اشتراک تصویری»
/// و «اشتراک متنی».
class ShareOptionsSheet extends StatefulWidget {
  const ShareOptionsSheet({
    super.key,
    required this.card,
    required this.fileName,
    this.onShareText,
  });

  final Widget card;
  final String fileName;

  /// اشتراک متنیِ سنتی (اختیاری)
  final VoidCallback? onShareText;

  static Future<void> show({
    required BuildContext context,
    required Widget card,
    required String fileName,
    VoidCallback? onShareText,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareOptionsSheet(
        card: card,
        fileName: fileName,
        onShareText: onShareText,
      ),
    );
  }

  @override
  State<ShareOptionsSheet> createState() => _ShareOptionsSheetState();
}

class _ShareOptionsSheetState extends State<ShareOptionsSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _busy = false;

  Future<Uint8List?> _capture() async {
    try {
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareImage() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) return;
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png', name: widget.fileName)],
        text: 'دیوان و فال حافظ',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF14263D).withOpacity(0.97),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: const Color(0xFFF0B45C).withOpacity(0.35), width: 1.2),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: RepaintBoundary(key: _cardKey, child: widget.card),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareImage,
                      style: AppThemeButton.style(),
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppThemeButton.gold),
                            )
                          : const Icon(Icons.image_outlined,
                              color: AppThemeButton.gold),
                      label: Text(
                        'اشتراک تصویری',
                        style: vazirText(
                            color: AppThemeButton.gold,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (widget.onShareText != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.onShareText,
                        style: AppThemeButton.style(),
                        icon: const Icon(Icons.text_fields,
                            color: AppThemeButton.gold),
                        label: Text(
                          'اشتراک متنی',
                          style: vazirText(
                              color: AppThemeButton.gold,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: Get.back,
                child: Text(
                  'بستن',
                  style: vazirText(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
