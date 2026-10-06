import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 42, this.showName = false, this.light = false});

  final double size;
  final bool showName;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final foreground = light ? Colors.white : const Color(0xFF176B67);
    final textColor = light ? Colors.white : const Color(0xFF253238);
    final logo = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .12),
      decoration: BoxDecoration(
        color: light ? Colors.white.withAlpha(41) : const Color(0xFFE2F2EF),
        borderRadius: BorderRadius.circular(size * .28),
        border: light ? Border.all(color: Colors.white.withAlpha(46)) : null,
      ),
      child: Image.asset(
        'assets/images/nameology_logo.png',
        fit: BoxFit.contain,
        color: light ? Colors.white : null,
        colorBlendMode: light ? BlendMode.srcIn : null,
        errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome, color: foreground, size: size * .52),
      ),
    );
    if (!showName) return logo;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 10),
        Text('علم اسامی', style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: size * .40)),
      ],
    );
  }
}
