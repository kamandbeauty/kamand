import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:fale_hafez/fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'themed_button.dart';

/// اشتراک تصویریِ صفحه: تصویر به‌اشتراک‌گذاشته‌شده اسکرین‌شاتِ
/// خودِ صفحهٔ جاری است (محتوای داخلِ یک [RepaintBoundary]).
class SharePage {
  SharePage._();

  static const _cream = Color.fromRGBO(248, 239, 222, 1);
  static const _textOnCream = Color.fromRGBO(74, 43, 16, 1);

  /// سقف عرض خروجی به پیکسل: روی دستگاه‌های ضعیف، راستر ۲× از صفحهٔ
  /// بزرگ می‌توانست ده‌ها مگابایت RAM پیکسل ببلعد و به OOM منجر شود؛
  /// تصویر ۲۰۴۸ پیکسل عرض برای موبایل/تلگرام باکیفیت‌_491 باقیست و
  /// در چشم معمول با ۲× تفاوتی ندارد.
  static const int _maxOutputWidthPx = 2048;

  /// نسبتِ پیکسلِ موثر برای خروجی: تا سقف [pixelRatio] استفاده می‌شود،
  /// ولی وقتی عرضِ راستر با آن از [_maxOutputWidthPx] عبور کند، نسبت
  /// آن‌قدر پایین می‌آید که خروجی باز هم باکیفیت (حداقل ۱×) و از نظر
  /// حافظه امن می‌ماند. تصرف نرمال (صفحهٔ موبایل) بدون کاهش کیفیت می‌ماند.
  @visibleForTesting
  static double effectivePixelRatio(double logicalWidth,
      {double pixelRatio = 2.0}) {
    assert(logicalWidth > 0);
    final maxByMemory = _maxOutputWidthPx / logicalWidth;
    return (pixelRatio > maxByMemory ? maxByMemory : pixelRatio)
        .clamp(1.0, pixelRatio)
        .toDouble();
  }

  /// ثبتِ تصویر PNG از محتوای داخلِ [RepaintBoundary] با کلیدِ [key].
  ///
  /// نکتهٔ مدیریت‌حافظه: تصویرِ نهایی حداکثر [_maxOutputWidthPx] پیکسل
  /// عرض دارد تا به اشتراک‌گذاری‌های پیاپی (و دستگاه‌های کم‌حافظه) فشار
  /// حافظه ایجاد نکنند؛ عضو `ui.Image` بلافاصله پس از استخراج بایت‌ها
  /// dispose می‌شود تا بافرِ GPU زود آزاد شود.
  static Future<Uint8List?> capture(GlobalKey key,
      {double pixelRatio = 2.0}) async {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final boundary = ctx.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    final effective =
        effectivePixelRatio(boundary.size.width, pixelRatio: pixelRatio);
    final image = await boundary.toImage(pixelRatio: effective);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return null;
    return data.buffer.asUint8List();
  }

  /// اشتراک مستقیم تصویرِ صفحه (برمی‌گرداند آیا موفق بود یا نه).
  static Future<bool> _shareImageBytes(Uint8List png, String fileName) async {
    await Share.shareXFiles([
      XFile.fromData(
        png,
        mimeType: 'image/png',
        name: fileName,
        length: png.length,
      ),
    ]);
    return true;
  }

  /// شیتِ انتخاب: پیش‌نمایشِ تصویرِ صفحه + اشتراک تصویری / متنی
  static Future<void> showSheet({
    required BuildContext context,
    required GlobalKey key,
    required String fileName,
    required VoidCallback onShareText,
  }) async {
    final png = await capture(key);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'اشتراک صفحه',
                    textAlign: TextAlign.center,
                    style: vazirText(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _textOnCream,
                    ),
                  ),
                  if (png != null) ...[
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(png, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: AppThemeButton.labeled(
                          label: 'اشتراک تصویری',
                          icon: Icons.image_outlined,
                          onPressed: png == null
                              ? null
                              : () async {
                                  await _shareImageBytes(png, fileName);
                                  if (sheetCtx.mounted) {
                                    Navigator.of(sheetCtx).pop();
                                  }
                                },
                          height: 50,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppThemeButton.labeled(
                          label: 'اشتراک متنی',
                          icon: Icons.text_fields,
                          onPressed: () {
                            Navigator.of(sheetCtx).pop();
                            onShareText();
                          },
                          height: 50,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      child: Text(
                        'بستن',
                        style: vazirText(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textOnCream.withOpacity(0.65),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
