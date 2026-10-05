import 'package:fale_hafez/fonts.dart';
import 'package:flutter/material.dart';

import 'themed_button.dart';

/// اشتراک صفحه: فقط به‌صورت متنی.
///
/// اشتراک تصویری (اسکرین‌شات صفحه) به درخواست صاحب‌اثر حذف شد؛
/// متنِ شعر/فال با همان تمِ اپلیکیشن از برگهٔ پایین به اشتراک گذاشته
/// می‌شود.
class SharePage {
  SharePage._();

  static const _cream = Color.fromRGBO(248, 239, 222, 1);
  static const _textOnCream = Color.fromRGBO(74, 43, 16, 1);

  /// شیتِ انتخاب: فقط اشتراکِ متنیٔ صفحه
  static Future<void> showSheet({
    required BuildContext context,
    required VoidCallback onShareText,
  }) async {
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
                  const SizedBox(height: 18),
                  AppThemeButton.labeled(
                    label: 'اشتراک متنی',
                    icon: Icons.text_fields,
                    onPressed: () {
                      Navigator.of(sheetCtx).pop();
                      onShareText();
                    },
                    height: 50,
                    fontSize: 15,
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
