import 'package:fale_hafez/data/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// لایهٔ کم‌نورِ «حالت مطالعهٔ شبانه» — روی پس‌زمینهٔ تصویری قرار
/// می‌گیرد و با فعال‌بودن، تصویر را برای خواندن در تاریکی کم‌رنگ می‌کند.
/// بی‌اثر روی لمس (IgnorePointer) و با تغییر نرم.
class NightOverlay extends StatelessWidget {
  const NightOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsService>();
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => IgnorePointer(
        child: AnimatedOpacity(
          opacity: settings.nightMode ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: Container(color: const Color(0xB3000012)),
        ),
      ),
    );
  }
}
