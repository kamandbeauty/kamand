import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';
import '../../../core/app_theme.dart';
import '../../../core/persian_utils.dart';
import '../../../game_engine/scoring/score_manager.dart';
import 'overlay_scaffold.dart';
import 'score_table.dart';

/// برگهٔ نتیجهٔ نهایی مسابقه.
class MatchResultSheet extends StatelessWidget {
  const MatchResultSheet({
    super.key,
    required this.winnerTeam,
    required this.scoreUs,
    required this.scoreThem,
    required this.onPlayAgain,
    required this.onHome,
    this.records = const [],
  });

  /// ۰ = تیم انسان، ۱ = حریف.
  final int winnerTeam;
  final int scoreUs;
  final int scoreThem;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  /// تاریخچهٔ دست‌ها برای نمایش جدول امتیازات (اختیاری).
  final List<RoundRecord> records;

  @override
  Widget build(BuildContext context) {
    final weWon = winnerTeam == 0;
    return GameOverlayScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            weWon ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
            size: 54,
            color: weWon ? AppTheme.gold : Colors.white38,
          ),
          const SizedBox(height: 10),
          Text(
            weWon ? AppStrings.matchWon : AppStrings.matchLost,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: weWon ? AppTheme.gold : Colors.white70,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${toPersianDigits(scoreUs)} — ${toPersianDigits(scoreThem)}',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          Text(
            '${AppStrings.yourTeam} / ${AppStrings.opponentTeam}',
            style: const TextStyle(fontSize: 11.5, color: Colors.white54),
          ),
          if (records.isNotEmpty) ...[
            const SizedBox(height: 14),
            ScoreTable(records: records),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onHome,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                  child: const Text(AppStrings.backToHome),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onPlayAgain,
                  child: const Text(AppStrings.playAgain),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
