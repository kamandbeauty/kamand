import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// پردازش تصویر مهر/امضا: کراپ + حذف پس‌زمینه سفید/روشن
class ImageProcessHelper {
  /// حذف پس‌زمینه روشن با آستانه قابل تنظیم + حفظ کانال آلفا
  static img.Image removeNearWhiteBackground(
    img.Image src, {
    int threshold = 225,
    int softness = 35,
  }) {
    // خروجی حتماً RGBA تا شفافیت ذخیره شود
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

        // روشنایی (luma تقریبی)
        final luma = (0.299 * r + 0.587 * g + 0.114 * b);
        // نزدیکی به خاکستری روشن (پس‌زمینه کاغذ/اسکن)
        final maxC = r > g ? (r > b ? r : b) : (g > b ? g : b);
        final minC = r < g ? (r < b ? r : b) : (g < b ? g : b);
        final saturation = maxC - minC;

        int aOut = aIn;

        // سفید / نزدیک سفید / خاکستری خیلی روشن با اشباع کم → شفاف
        final isBright = luma >= threshold || (minC >= threshold - 10);
        final isPaleGray = luma >= (threshold - softness) && saturation < 28;

        if (isBright && saturation < 40) {
          aOut = 0;
        } else if (isPaleGray) {
          // لبه نرم
          final t = ((threshold - luma) / softness).clamp(0.0, 1.0);
          aOut = (t * aIn).round().clamp(0, 255);
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
    final l = (left.clamp(0.0, 1.0) * src.width).round().clamp(0, src.width - 1);
    final t = (top.clamp(0.0, 1.0) * src.height).round().clamp(0, src.height - 1);
    final r = (right.clamp(0.0, 1.0) * src.width).round().clamp(l + 1, src.width);
    final b = (bottom.clamp(0.0, 1.0) * src.height).round().clamp(t + 1, src.height);
    return img.copyCrop(src, x: l, y: t, width: r - l, height: b - t);
  }

  /// دیتای ورودی برای isolate
  static Future<Uint8List> _processInIsolate(Map<String, dynamic> params) async {
    final bytes = params['bytes'] as Uint8List;
    final left = params['left'] as double;
    final top = params['top'] as double;
    final right = params['right'] as double;
    final bottom = params['bottom'] as double;
    final removeWhite = params['removeWhite'] as bool;
    final kind = params['kind'] as String;
    final maxSide = params['maxSide'] as int;

    var decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('تصویر قابل خواندن نیست');
    }

    // تبدیل به RGBA
    if (decoded.numChannels < 4) {
      final rgba = img.Image(
        width: decoded.width,
        height: decoded.height,
        numChannels: 4,
      );
      for (var y = 0; y < decoded.height; y++) {
        for (var x = 0; x < decoded.width; x++) {
          final px = decoded.getPixel(x, y);
          rgba.setPixelRgba(x, y, px.r.toInt(), px.g.toInt(), px.b.toInt(), 255);
        }
      }
      decoded = rgba;
    }

    decoded = cropNormalized(
      decoded,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );

    // لوگو باید دقیقاً با پس‌زمینهٔ اصلی خودش ذخیره شود؛ حذف سفید فقط برای
    // مهر و امضا انجام می‌شود تا رنگ‌ها و جزئیات سفید لوگو از بین نرود.
    if (removeWhite && kind != 'logo') {
      // آستانه پایین‌تر برای اسکن‌های خاکستری
      decoded = removeNearWhiteBackground(decoded, threshold: 220, softness: 40);
      // پاس دوم برای سفیدهای باقی‌مانده
      decoded = removeNearWhiteBackground(decoded, threshold: 235, softness: 20);
    }

    if (decoded.width > maxSide || decoded.height > maxSide) {
      if (decoded.width >= decoded.height) {
        decoded = img.copyResize(decoded, width: maxSide);
      } else {
        decoded = img.copyResize(decoded, height: maxSide);
      }
    }

    return Uint8List.fromList(img.encodePng(decoded));
  }

  /// پردازش کامل و ذخیره دائمی PNG شفاف - با isolate برای جلوگیری از هنگ
  static Future<String> processAndSave({
    required Uint8List bytes,
    required String kind, // stamp | signature | logo
    double left = 0,
    double top = 0,
    double right = 1,
    double bottom = 1,
    bool removeWhite = true,
    int maxSide = 700, // کاهش از 900 به 700 برای سرعت بیشتر
  }) async {
    // پردازش سنگین در isolate جداگانه تا UI هنگ نکند
    final Uint8List pngBytes;
    try {
      pngBytes = await compute(_processInIsolate, {
        'bytes': bytes,
        'kind': kind,
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
        'removeWhite': removeWhite,
        'maxSide': maxSide,
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('پردازش تصویر زمان‌بر شد، لطفاً عکس کوچک‌تری انتخاب کنید'),
      );
    } catch (e) {
      // اگر isolate fail شد، در main thread با سایز کوچک‌تر تلاش کن
      if (e.toString().contains('زمان‌بر') || e.toString().contains('Timeout')) {
        rethrow;
      }
      // fallback: پردازش در main با maxSide کوچک‌تر
      try {
        final fallbackBytes = await _processInIsolate({
          'bytes': bytes,
          'kind': kind,
          'left': left,
          'top': top,
          'right': right,
          'bottom': bottom,
          'removeWhite': removeWhite,
          'maxSide': 500,
        });
        // ادامه با fallbackBytes
        final dir = await getApplicationDocumentsDirectory();
        final folder = Directory(p.join(dir.path, 'branding'));
        if (!await folder.exists()) {
          await folder.create(recursive: true);
        }
        final outPath = p.join(
          folder.path,
          '${kind}_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await File(outPath).writeAsBytes(fallbackBytes);
        // cleanup async و بدون مسدود کردن
        _cleanupOldFilesAsync(folder, kind, outPath);
        return outPath;
      } catch (_) {
        rethrow;
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
    await File(outPath).writeAsBytes(pngBytes);

    // پاکسازی فایل‌های قدیمی به صورت async و بدون مسدود کردن UI
    _cleanupOldFilesAsync(folder, kind, outPath);

    return outPath;
  }

  /// پاکسازی async بدون استفاده از Sync که باعث هنگ می‌شود
  static void _cleanupOldFilesAsync(Directory folder, String kind, String outPath) {
    // بدون await - در background اجرا شود
    Future(() async {
      try {
        final files = <File>[];
        await for (final entity in folder.list()) {
          if (entity is File) {
            final name = p.basename(entity.path);
            if (name.startsWith('${kind}_') && name.endsWith('.png')) {
              files.add(entity);
            }
          }
        }
        if (files.length <= 5) return;

        // گرفتن lastModified به صورت async
        final filesWithTime = <MapEntry<File, DateTime>>[];
        for (final f in files) {
          try {
            final stat = await f.lastModified();
            filesWithTime.add(MapEntry(f, stat));
          } catch (_) {}
        }
        filesWithTime.sort((a, b) => b.value.compareTo(a.value));

        if (filesWithTime.length > 5) {
          for (final entry in filesWithTime.skip(5)) {
            try {
              if (entry.key.path != outPath) {
                await entry.key.delete();
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    });
  }
}
