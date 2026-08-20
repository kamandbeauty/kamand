import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';
import '../../../core/app_theme.dart';
import '../../../core/persian_utils.dart';
import '../../../game/game_controller.dart';
import '../../../game_engine/scoring/score_manager.dart';
import 'overlay_scaffold.dart';
import 'score_table.dart';

/// برگهٔ گزارش پایان دست — جدول امتیازاتِ همهٔ دست‌ها از دید تیم شما.
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
              fontSize: 22,
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
          const SizedBox(height: 10),
          // عنوان جدول
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.table_chart_rounded,
                  size: 15, color: AppTheme.gold.withOpacity(0.8)),
              const SizedBox(width: 6),
              const Text(
                AppStrings.scoreTableTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ScoreTable(records: controller.roundRecords),
          const SizedBox(height: 10),
          Text(
            '+${toPersianDigits(result.pointsAwarded)} امتیاز '
            'برای ${result.winnerTeamIndex == 0 ? AppStrings.yourTeam : AppStrings.opponentTeam}',
            style: TextStyle(
              fontSize: 12.5,
              color: weWon ? AppTheme.gold : Colors.white54,
            ),
          ),
          const SizedBox(height: 18),
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
}
