import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// پردازش تصویر مهر/امضا: کراپ + حذف پس‌زمینه سفید/نزدیک‌سفید
class ImageProcessHelper {
  /// حذف پیکسل‌های نزدیک سفید (شفاف‌سازی)
  static img.Image removeNearWhiteBackground(
    img.Image src, {
    int threshold = 238,
  }) {
    final out = img.Image.from(src);
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final px = out.getPixel(x, y);
        final r = px.r.toInt();
        final g = px.g.toInt();
        final b = px.b.toInt();
        // نزدیک سفید یا خاکستری خیلی روشن
        if (r >= threshold && g >= threshold && b >= threshold) {
          out.setPixelRgba(x, y, r, g, b, 0);
        } else {
          // کمی soft edge برای مرزها
          final minC = r < g ? (r < b ? r : b) : (g < b ? g : b);
          if (minC > threshold - 25) {
            final a = ((threshold - minC) / 25.0 * 255).clamp(0, 255).toInt();
            out.setPixelRgba(x, y, r, g, b, a);
          }
        }
      }
    }
    return out;
  }

  /// کراپ نرمال‌شده (مقادیر 0..1 نسبت به عرض/ارتفاع)
  static img.Image cropNormalized(
    img.Image src, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    final l = (left.clamp(0.0, 1.0) * src.width).round().clamp(0, src.width - 1);
    final t = (top.clamp(0.0, 1.0) * src.height).round().clamp(0, src.height - 1);
    final r = (right.clamp(0.0, 1.0) * src.width).round().clamp(l + 1, src.width);
    final b = (bottom.clamp(0.0, 1.0) * src.height).round().clamp(t + 1, src.height);
    return img.copyCrop(src, x: l, y: t, width: r - l, height: b - t);
  }

  /// پردازش کامل و ذخیره دائمی در پوشه اپ
  static Future<String> processAndSave({
    required Uint8List bytes,
    required String kind, // stamp | signature | logo
    double left = 0,
    double top = 0,
    double right = 1,
    double bottom = 1,
    bool removeWhite = true,
    int maxSide = 800,
  }) async {
    var decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('تصویر قابل خواندن نیست');
    }

    decoded = cropNormalized(
      decoded,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );

    if (removeWhite) {
      decoded = removeNearWhiteBackground(decoded);
    }

    // resize if too large
    if (decoded.width > maxSide || decoded.height > maxSide) {
      if (decoded.width >= decoded.height) {
        decoded = img.copyResize(decoded, width: maxSide);
      } else {
        decoded = img.copyResize(decoded, height: maxSide);
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'branding'));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final outPath = p.join(
      folder.path,
      '${kind}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    final file = File(outPath);
    await file.writeAsBytes(img.encodePng(decoded));
    return outPath;
  }
}
