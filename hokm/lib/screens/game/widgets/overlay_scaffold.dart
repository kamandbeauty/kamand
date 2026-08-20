import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

/// چارچوب مشترک اورلی‌های تمام‌صفحهٔ بازی — پس‌زمینهٔ محو + کارت مرکزی.
class GameOverlayScaffold extends StatelessWidget {
  const GameOverlayScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.72),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.gold.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
