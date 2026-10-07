import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../data/content/traditions_content.dart';

/// Small shared building blocks for the tradition screens.

class DisclaimerCard extends StatelessWidget {
  const DisclaimerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              TraditionsContent.disclaimer,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.9,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                fontFamily: 'Vazirmatn',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paragraph of body text inside a glass card.
class BodyText extends StatelessWidget {
  const BodyText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 13.5,
        height: 2.05,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
        fontFamily: 'Vazirmatn',
      ),
    );
  }
}

/// Small tinted chip (nature labels, element labels, …).
class NatureChip extends StatelessWidget {
  const NatureChip(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? AppTheme.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: theme.brightness == Brightness.dark
              ? c
              : AppTheme.violetDeep,
          fontFamily: 'Vazirmatn',
        ),
      ),
    );
  }
}

/// Big circular emblem used as each tradition's hero mark.
class TraditionEmblem extends StatelessWidget {
  const TraditionEmblem({
    super.key,
    required this.child,
    this.accent = AppTheme.violet,
    this.size = 86,
  });

  final Widget child;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            accent.withValues(alpha: 0.30),
            AppTheme.gold.withValues(alpha: 0.18),
          ],
        ),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
      ),
      child: Center(child: child),
    );
  }
}

/// Persian digits helper for the tradition screens.
String faNum(Object value) => PersianNumbers.toPersian(value.toString());
