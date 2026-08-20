import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';
import '../../../core/app_theme.dart';
import '../../../core/persian_utils.dart';
import '../../../game/game_controller.dart';
import '../../../game_engine/scoring/score_manager.dart';
import 'overlay_scaffold.dart';

/// برگهٔ نتیجهٔ پایان دست.
class RoundResultSheet extends StatelessWidget {
  const RoundResultSheet({
    super.key,
    required this.controller,
    required this.result,
    required this.onNext,
    required this.onExit,
  });

  final GameController controller;
  final RoundResult result;
  final VoidCallback onNext;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final weWon = result.winnerTeamIndex == 0;
    final title = weWon ? AppStrings.roundWon : AppStrings.roundLost;

    return GameOverlayScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: weWon ? AppTheme.gold : Colors.white70,
            ),
          ),
          if (result.isKoot || result.isHakimKoot) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.gold.withOpacity(0.5)),
              ),
              child: Text(
                result.isHakimKoot
                    ? AppStrings.hakimKoot
                    : AppStrings.koot,
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _resultCell(
                  AppStrings.yourTeam, result.winnerTeamIndex == 0
                      ? result.winnerTricks
                      : result.loserTricks),
              const SizedBox(width: 18),
              Text(
                '×',
                style:
                    TextStyle(fontSize: 20, color: Colors.white.withOpacity(0.4)),
              ),
              const SizedBox(width: 18),
              _resultCell(
                  AppStrings.opponentTeam, result.winnerTeamIndex == 1
                      ? result.winnerTricks
                      : result.loserTricks),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${AppStrings.score}: '
            '${toPersianDigits(controller.scoreUs)} — ${toPersianDigits(controller.scoreThem)}',
            style: const TextStyle(fontSize: 13, color: Colors.white60),
          ),
          Text(
            '+${toPersianDigits(result.pointsAwarded)} '
            'برای ${result.winnerTeamIndex == 0 ? AppStrings.yourTeam : AppStrings.opponentTeam}',
            style: TextStyle(
              fontSize: 12.5,
              color: weWon ? AppTheme.gold : Colors.white54,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onExit,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                  child: const Text(AppStrings.exit),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onNext,
                  child: const Text(AppStrings.nextRound),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultCell(String label, int tricks) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11.5, color: Colors.white54)),
        const SizedBox(height: 2),
        Text(
          toPersianDigits(tricks),
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
