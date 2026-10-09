import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_providers.dart';

/// یک کمپینِ تبلیغاتی: گیف + لینکِ مقصد. صاحبِ اپ فایل
/// `assets/ads/campaigns.json` را با کمپین‌های واقعیِ خودش جایگزین
/// می‌کند — بدونِ نیاز به SDK یا وابستگیِ جدید.
class AdCampaign {
  const AdCampaign({required this.id, required this.gif, required this.link});

  factory AdCampaign.fromJson(Map<String, Object?> json) => AdCampaign(
        id: json['id'] as String? ?? '',
        gif: json['gif'] as String? ?? '',
        link: json['link'] as String? ?? '',
      );

  final String id;
  final String gif;
  final String link;

  bool get isValid => gif.isNotEmpty && link.isNotEmpty;
}

/// کمپین‌های تبلیغاتی از JSON باندل‌شده خوانده می‌شوند؛ هر خطا =
/// بدونِ تبلیغ (اپ هرگز به خاطرِ تبلیغ نمی‌شکند).
final adCampaignsProvider =
    FutureProvider.autoDispose<List<AdCampaign>>((ref) async {
  try {
    final raw = await rootBundle.loadString('assets/ads/campaigns.json');
    final list = jsonDecode(raw);
    if (list is! List<Object?>) return const [];
    return list
        .whereType<Map<String, Object?>>()
        .map(AdCampaign.fromJson)
        .where((c) => c.isValid)
        .toList();
  } catch (_) {
    return const [];
  }
});

/// بنرِ افقیِ نازکِ تبلیغات — گیفِ لینک‌دار با برچسبِ شفافِ «تبلیغ».
///
/// • برایِ کاربرانِ پرمیوم به‌کلی حذف می‌شود (سطرِ صفر).
/// • اگر کمپینی نباشد یا تصویر لود نشود، چیزی نمایش داده نمی‌شود.
/// • لمس = بازکردنِ لینک در مرورگرِ خارجی.
class AdBanner extends ConsumerWidget {
  const AdBanner({super.key, this.slot = 0});

  /// ایندکسِ انتخابِ کمپین برای این جایگاه (چرخشی وقتی چند کمپین هست).
  final int slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // پرمیوم = بدونِ تبلیغ. اینجا اولین و آخرین تصمیم همین است.
    if (ref.watch(entitlementProvider).hasPremium) {
      return const SizedBox.shrink();
    }
    final campaigns = ref.watch(adCampaignsProvider);
    return campaigns.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final ad = list[slot % list.length];
        return Semantics(
          label: 'تبلیغ — باز کردن لینک',
          button: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final uri = Uri.tryParse(ad.link);
                if (uri == null) return;
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {
                  // لینک در دسترس نیست — بی‌صدا رد می‌شویم.
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 64,
                      width: double.infinity,
                      child: Image.asset(
                        ad.gif,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                    PositionedDirectional(
                      top: 6,
                      start: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'تبلیغ',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
