import 'package:fale_hafez/fonts.dart';
import 'package:flutter/material.dart';

/// عنوان برند برنامه: «دیوان و فال حافظ»
///
/// روی پس‌زمینهٔ تیره با گرادیان طلایی درخشان و
/// روی پس‌زمینهٔ روشن با قهوه‌ای سوخته و هالهٔ سفید نمایش داده می‌شود.
class AppBrand extends StatelessWidget {
  const AppBrand({
    super.key,
    this.fontSize = 22,
    this.onDark = true,
  });

  final double fontSize;

  /// آیا پس‌زمینهٔ پشت عنوان تیره است؟
  final bool onDark;

  static const Color _darkBrown = Color.fromRGBO(107, 38, 15, 1);

  @override
  Widget build(BuildContext context) {
    const String title = 'دیوان و فال حافظ';

    if (!onDark) {
      return Text(
        title,
        textDirection: TextDirection.rtl,
        maxLines: 1,
        overflow: TextOverflow.visible,
        style: vazirText(
          fontFamily: 'Sahel',
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: _darkBrown,
        ).copyWith(shadows: const [
          Shadow(color: Colors.white70, blurRadius: 10),
        ]),
      );
    }

    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFF3C4),
          Color(0xFFF0B45C),
          Color(0xFFD98E2B),
        ],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(
        title,
        textDirection: TextDirection.rtl,
        maxLines: 1,
        overflow: TextOverflow.visible,
        style: vazirText(
          fontFamily: 'Sahel',
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ).copyWith(shadows: const [
          Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 2)),
          Shadow(color: Color(0x66FFB84D), blurRadius: 18),
        ]),
      ),
    );
  }
}
