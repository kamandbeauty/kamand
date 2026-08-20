import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';
import '../../../core/app_theme.dart';
import '../../../core/persian_utils.dart';
import '../../../game/game_controller.dart';
import 'suit_icon.dart';

/// HUD بالای صفحه: خروج، امتیازها، حکم و شمارهٔ دست.
class ScoreHud extends StatelessWidget {
  const ScoreHud({super.key, required this.controller, required this.onExit});

  final GameController controller;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // خروج
          _RoundIconButton(
            icon: Icons.arrow_forward_rounded,
            tooltip: AppStrings.exit,
            onTap: onExit,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _TeamChip(
                    label: AppStrings.yourTeam,
                    score: controller.scoreUs,
                    tricks: controller.tricksUs,
                    highlight: true,
                  ),
                ),
                const SizedBox(width: 8),
                _TrumpChip(controller: controller),
                const SizedBox(width: 8),
                Expanded(
                  child: _TeamChip(
                    label: AppStrings.opponentTeam,
                    score: controller.scoreThem,
                    tricks: controller.tricksThem,
                    highlight: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton(
      {required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: Colors.white70),
        ),
      ),
    );
  }
}

class _TeamChip extends StatelessWidget {
  const _TeamChip({
    required this.label,
    required this.score,
    required this.tricks,
    required this.highlight,
  });

  final String label;
  final int score;
  final int tricks;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        highlight ? AppTheme.gold.withOpacity(0.65) : Colors.white12;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xD0121D16)
            : const Color(0xD012141B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: highlight ? AppTheme.gold : Colors.white70,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _miniMetric(AppStrings.score, '$score'),
              Container(
                width: 1,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Colors.white24,
              ),
              _miniMetric(AppStrings.tricks, '$tricks'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    return Row(
      children: [
        Text(
          '$label ',
          style: const TextStyle(fontSize: 9.5, color: Colors.white54),
        ),
        Text(
          toPersianDigits(value),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _TrumpChip extends StatelessWidget {
  const _TrumpChip({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final trump = controller.trump;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: trump == null
          ? const SizedBox(width: 40, key: ValueKey('empty'))
          : Container(
              key: ValueKey(trump),
              padding:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xE01D1A10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.gold.withOpacity(0.8)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.gold.withOpacity(0.25),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    AppStrings.trumpLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: AppTheme.gold.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  SuitIcon(suit: trump, size: 22),
                ],
              ),
            ),
    );
  }
}
