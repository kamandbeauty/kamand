import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../storage/settings_model.dart';

/// لودرِ تصاویر اختیاریِ بازی — «لایهٔ هنریِ قابل‌تعویض».
///
/// قرارداد ساده: اگر فایلِ تصویر در مسیر قراردادیِ `assets/images/art/...`
/// وجود داشته باشد، از همان استفاده می‌شود؛ در غیر این صورت رندر رویه‌ای
/// (procedural) پیش‌فرض فعال می‌ماند. هیچ استثنایی به بیرون نشت نمی‌کند.
///
/// نام فایل‌ها در `assets/images/art/README.md` مستند شده است.
class GameArt {
  GameArt._();

  static final GameArt instance = GameArt._();

  final Map<String, ui.Image> _images = <String, ui.Image>{};
  bool _loaded = false;

  static const _base = 'assets/images/art';

  /// بک‌گراند فرشِ میز به‌ازای هر تم.
  static const Map<TableTheme, String> tableFiles = {
    TableTheme.classicGreen: '$_base/table/felt-green.jpg',
    TableTheme.midnightBlue: '$_base/table/felt-midnight.jpg',
    TableTheme.royalRed: '$_base/table/felt-royal.jpg',
  };

  /// تصویر پشت کارت به‌ازای هر طرح.
  static const Map<CardBackStyle, String> backFiles = {
    CardBackStyle.classic: '$_base/card/back-classic.jpg',
    CardBackStyle.persianTile: '$_base/card/back-persian-tile.jpg',
    CardBackStyle.diagonal: '$_base/card/back-diagonal.jpg',
  };

  /// بافت کاغذیِ ملایم روی روی کارت (اختیاری).
  static const String facePaperFile = '$_base/card/face-paper.jpg';

  /// بارگذاری همهٔ تصاویر موجود — فراخوانی نبودِ فایل مجاز است.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final paths = <String>[
      ...tableFiles.values,
      ...backFiles.values,
      facePaperFile,
    ];
    await Future.wait(paths.map(_tryLoad));
  }

  Future<void> _tryLoad(String path) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      final frame = await codec.getNextFrame();
      _images[path] = frame.image;
    } on Object {
      // فایل نیست یا خوانده نشد — رندر رویه‌ای جایگزین می‌ماند.
      debugPrint('GameArt: asset not available → $path (procedural fallback)');
    }
  }

  ui.Image? tableImage(TableTheme theme) => _images[tableFiles[theme]];

  ui.Image? cardBackImage(CardBackStyle style) => _images[backFiles[style]];

  ui.Image? get facePaperImage => _images[facePaperFile];

  /// برش cover-fit: منبع را طوری می‌برد که دقیقاً مقصد را بپوشاند.
  static ui.Rect coverSrc(ui.Image image, ui.Rect dst) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final imgRatio = imgW / imgH;
    final dstRatio = dst.width / dst.height;
    if (imgRatio > dstRatio) {
      final w = imgH * dstRatio;
      return ui.Rect.fromLTWH((imgW - w) / 2, 0, w, imgH);
    }
    final h = imgW / dstRatio;
    return ui.Rect.fromLTWH(0, (imgH - h) / 2, imgW, h);
  }
}
