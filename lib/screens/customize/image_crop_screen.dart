import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_process_helper.dart';

const _orange = AppTheme.RubyPrimary;

/// صفحه کراپ ساده + حذف پس‌زمینه سفید برای مهر / امضا
class ImageCropScreen extends StatefulWidget {
  final String imagePath;
  final String kind; // stamp | signature
  final String title;

  const ImageCropScreen({
    super.key,
    required this.imagePath,
    required this.kind,
    required this.title,
  });

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  // crop rect in 0..1 relative to image display area
  double _left = 0.05;
  double _top = 0.05;
  double _right = 0.95;
  double _bottom = 0.95;
  bool _removeWhite = true;
  bool _busy = false;
  Uint8List? _previewBytes;
  Size? _imgSize;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final decoded = await decodeImageFromList(bytes);
    if (!mounted) return;
    setState(() {
      _previewBytes = bytes;
      _imgSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
    });
  }

  Future<void> _confirm() async {
    if (_busy || _previewBytes == null) return;
    setState(() => _busy = true);
    try {
      final path = await ImageProcessHelper.processAndSave(
        bytes: _previewBytes!,
        kind: widget.kind,
        left: _left,
        top: _top,
        right: _right,
        bottom: _bottom,
        removeWhite: _removeWhite,
      );
      if (!mounted) return;
      Navigator.pop(context, path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در پردازش تصویر: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        actions: [
          TextButton(
            onPressed: _busy ? null : _confirm,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('تایید', style: TextStyle(color: _orange, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _previewBytes == null
                ? const Center(child: CircularProgressIndicator(color: _orange))
                : LayoutBuilder(
                    builder: (ctx, box) {
                      return Center(
                        child: AspectRatio(
                          aspectRatio: (_imgSize?.aspectRatio ?? 1).clamp(0.4, 2.5),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(_previewBytes!, fit: BoxFit.contain),
                              // dim outside crop
                              IgnorePointer(
                                child: CustomPaint(
                                  painter: _CropOverlayPainter(
                                    left: _left,
                                    top: _top,
                                    right: _right,
                                    bottom: _bottom,
                                  ),
                                ),
                              ),
                              // draggable handles via GestureDetector on corners conceptually —
                              // use four edge sliders conceptually with pan on center + corners
                              _CropGestureLayer(
                                left: _left,
                                top: _top,
                                right: _right,
                                bottom: _bottom,
                                onChanged: (l, t, r, b) {
                                  setState(() {
                                    _left = l;
                                    _top = t;
                                    _right = r;
                                    _bottom = b;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: _orange,
                  title: const Text(
                    'حذف پس‌زمینه سفید',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'پیکسل‌های سفید/روشن شفاف می‌شوند',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  value: _removeWhite,
                  onChanged: (v) => setState(() => _removeWhite = v),
                ),
                const SizedBox(height: 8),
                const Text(
                  'گوشه‌های کادر را بکشید تا ناحیه مهر/امضا انتخاب شود',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _busy ? 'در حال پردازش…' : 'اعمال کراپ و ذخیره',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  final double left, top, right, bottom;
  _CropOverlayPainter({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addRect(Offset.zero & size);
    final crop = Path()
      ..addRect(Rect.fromLTRB(
        left * size.width,
        top * size.height,
        right * size.width,
        bottom * size.height,
      ));
    final dim = Path.combine(PathOperation.difference, outer, crop);
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.55));
    final border = Paint()
      ..color = _orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromLTRB(
        left * size.width,
        top * size.height,
        right * size.width,
        bottom * size.height,
      ),
      border,
    );
    // corner handles
    final handle = Paint()..color = _orange;
    for (final o in [
      Offset(left * size.width, top * size.height),
      Offset(right * size.width, top * size.height),
      Offset(left * size.width, bottom * size.height),
      Offset(right * size.width, bottom * size.height),
    ]) {
      canvas.drawCircle(o, 8, handle);
      canvas.drawCircle(o, 8, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) =>
      old.left != left || old.top != top || old.right != right || old.bottom != bottom;
}

class _CropGestureLayer extends StatefulWidget {
  final double left, top, right, bottom;
  final void Function(double l, double t, double r, double b) onChanged;
  const _CropGestureLayer({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.onChanged,
  });

  @override
  State<_CropGestureLayer> createState() => _CropGestureLayerState();
}

class _CropGestureLayerState extends State<_CropGestureLayer> {
  int? _corner; // 0 tl 1 tr 2 bl 3 br 4 move

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      Offset p(double nx, double ny) => Offset(nx * w, ny * h);

      return GestureDetector(
        onPanStart: (d) {
          final pos = d.localPosition;
          final corners = [
            p(widget.left, widget.top),
            p(widget.right, widget.top),
            p(widget.left, widget.bottom),
            p(widget.right, widget.bottom),
          ];
          for (var i = 0; i < 4; i++) {
            if ((corners[i] - pos).distance < 28) {
              _corner = i;
              return;
            }
          }
          final rect = Rect.fromLTRB(
            widget.left * w,
            widget.top * h,
            widget.right * w,
            widget.bottom * h,
          );
          if (rect.contains(pos)) {
            _corner = 4;
          } else {
            _corner = null;
          }
        },
        onPanUpdate: (d) {
          if (_corner == null) return;
          final dx = d.delta.dx / w;
          final dy = d.delta.dy / h;
          var l = widget.left;
          var t = widget.top;
          var r = widget.right;
          var b = widget.bottom;
          const minSize = 0.12;
          switch (_corner) {
            case 0:
              l = (l + dx).clamp(0.0, r - minSize);
              t = (t + dy).clamp(0.0, b - minSize);
              break;
            case 1:
              r = (r + dx).clamp(l + minSize, 1.0);
              t = (t + dy).clamp(0.0, b - minSize);
              break;
            case 2:
              l = (l + dx).clamp(0.0, r - minSize);
              b = (b + dy).clamp(t + minSize, 1.0);
              break;
            case 3:
              r = (r + dx).clamp(l + minSize, 1.0);
              b = (b + dy).clamp(t + minSize, 1.0);
              break;
            case 4:
              var nl = l + dx;
              var nt = t + dy;
              var nr = r + dx;
              var nb = b + dy;
              if (nl < 0) {
                nr -= nl;
                nl = 0;
              }
              if (nt < 0) {
                nb -= nt;
                nt = 0;
              }
              if (nr > 1) {
                nl -= (nr - 1);
                nr = 1;
              }
              if (nb > 1) {
                nt -= (nb - 1);
                nb = 1;
              }
              l = nl.clamp(0.0, 1.0);
              t = nt.clamp(0.0, 1.0);
              r = nr.clamp(0.0, 1.0);
              b = nb.clamp(0.0, 1.0);
              break;
          }
          widget.onChanged(l, t, r, b);
        },
        onPanEnd: (_) => _corner = null,
        child: Container(color: Colors.transparent),
      );
    });
  }
}
