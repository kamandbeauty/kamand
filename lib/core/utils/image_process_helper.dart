import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// CPU-heavy image work runs in a background isolate. This prevents large
/// camera photos from blocking Flutter's UI thread or leaving a blank screen.
Uint8List _processImageBytes(Map<String, Object> payload) {
  final bytes = payload['bytes']! as Uint8List;
  final kind = payload['kind']! as String;
  final removeWhite = payload['removeWhite']! as bool;
  final maxSide = payload['maxSide']! as int;

  var decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width < 1 || decoded.height < 1) {
    throw const FormatException('تصویر قابل خواندن نیست');
  }

  decoded = ImageProcessHelper.cropNormalized(
    decoded,
    left: payload['left']! as double,
    top: payload['top']! as double,
    right: payload['right']! as double,
    bottom: payload['bottom']! as double,
  );

  // Resize before allocating an RGBA work buffer. A modern camera image can
  // otherwise require hundreds of MB while background removal is in progress.
  if (decoded.width > maxSide || decoded.height > maxSide) {
    decoded = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxSide)
        : img.copyResize(decoded, height: maxSide);
  }

  if (removeWhite && kind != 'logo') {
    decoded = ImageProcessHelper.removeNearWhiteBackground(
      decoded,
      threshold: 220,
      softness: 40,
    );
  }

  return Uint8List.fromList(img.encodePng(decoded));
}

/// پردازش تصویر مهر/امضا: کراپ + حذف پس‌زمینه سفید/روشن
class ImageProcessHelper {
  /// حذف پس‌زمینه روشن با آستانه قابل تنظیم + حفظ کانال آلفا
  static img.Image removeNearWhiteBackground(
    img.Image src, {
    int threshold = 225,
    int softness = 35,
  }) {
    final out = img.Image(
      width: src.width,
      height: src.height,
      numChannels: 4,
    );

    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final px = src.getPixel(x, y);
        final r = px.r.toInt();
        final g = px.g.toInt();
        final b = px.b.toInt();
        final aIn = px.a.toInt();
        final luma = 0.299 * r + 0.587 * g + 0.114 * b;
        final maxC = r > g ? (r > b ? r : b) : (g > b ? g : b);
        final minC = r < g ? (r < b ? r : b) : (g < b ? g : b);
        final saturation = maxC - minC;

        var aOut = aIn;
        final isBright = luma >= threshold || minC >= threshold - 10;
        final isPaleGray = luma >= threshold - softness && saturation < 28;

        if (isBright && saturation < 40) {
          aOut = 0;
        } else if (isPaleGray) {
          final opacity = ((threshold - luma) / softness).clamp(0.0, 1.0);
          aOut = (opacity * aIn).round().clamp(0, 255);
        }
        out.setPixelRgba(x, y, r, g, b, aOut);
      }
    }
    return out;
  }

  static img.Image cropNormalized(
    img.Image src, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    final l = (left.clamp(0.0, 1.0) * src.width)
        .round()
        .clamp(0, src.width - 1);
    final t = (top.clamp(0.0, 1.0) * src.height)
        .round()
        .clamp(0, src.height - 1);
    final r = (right.clamp(0.0, 1.0) * src.width)
        .round()
        .clamp(l + 1, src.width);
    final b = (bottom.clamp(0.0, 1.0) * src.height)
        .round()
        .clamp(t + 1, src.height);
    return img.copyCrop(src, x: l, y: t, width: r - l, height: b - t);
  }

  /// پردازش کامل و ذخیره دائمی PNG شفاف
  static Future<String> processAndSave({
    required Uint8List bytes,
    required String kind,
    double left = 0,
    double top = 0,
    double right = 1,
    double bottom = 1,
    bool removeWhite = true,
    int maxSide = 900,
  }) async {
    if (bytes.isEmpty) throw const FormatException('فایل تصویر خالی است');

    final encoded = await compute(_processImageBytes, <String, Object>{
      'bytes': bytes,
      'kind': kind,
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
      'removeWhite': removeWhite,
      'maxSide': maxSide,
    });

    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'branding'));
    if (!await folder.exists()) await folder.create(recursive: true);

    final outPath = p.join(
      folder.path,
      '${kind}_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    final output = File(outPath);
    await output.writeAsBytes(encoded, flush: true);
    if (!await output.exists() || await output.length() == 0) {
      throw const FileSystemException('ذخیره فایل تصویر کامل نشد');
    }
    return outPath;
  }
}
