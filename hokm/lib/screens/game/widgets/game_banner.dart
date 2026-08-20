import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

/// بنر پیام وسط-بالای میز (مثل «حاکم: شما» یا «حکم: دل»).
class GameBanner extends StatelessWidget {
  const GameBanner({super.key, required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.38),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1).animate(anim),
              child: child,
            ),
          ),
          child: text == null
              ? const SizedBox.shrink(key: ValueKey('empty'))
              : Container(
                  key: ValueKey(text),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xE612151C),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: AppTheme.gold.withOpacity(0.55), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    text!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
