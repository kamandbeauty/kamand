import 'package:flutter_test/flutter_test.dart';
import 'package:hokm/game_engine/models/team.dart';
import 'package:hokm/game_engine/scoring/score_manager.dart';

void main() {
  const scorer = ScoreManager();

  group('Round settlement', () {
    test('normal round win gives 1 point', () {
      final r = scorer.settleRound(
          tricksTeam0: 7, tricksTeam1: 6, hakimTeamIndex: 0);
      expect(r.winnerTeamIndex, 0);
      expect(r.pointsAwarded, 1);
      expect(r.isKoot, isFalse);
      expect(r.isHakimKoot, isFalse);
    });

    test('challenger team can win the round', () {
      final r = scorer.settleRound(
          tricksTeam0: 4, tricksTeam1: 9, hakimTeamIndex: 0);
      expect(r.winnerTeamIndex, 1);
      expect(r.pointsAwarded, 1);
    });

    test('7-0 is koot → 2 points for hakim team', () {
      final r = scorer.settleRound(
          tricksTeam0: 13, tricksTeam1: 0, hakimTeamIndex: 0);
      expect(r.pointsAwarded, 2);
      expect(r.isKoot, isTrue);
      expect(r.isHakimKoot, isFalse);
    });

    test('7-0 against the hakim team is hakim-koot → 3 points', () {
      final r = scorer.settleRound(
          tricksTeam0: 0, tricksTeam1: 13, hakimTeamIndex: 0);
      expect(r.pointsAwarded, 3);
      expect(r.isKoot, isTrue);
      expect(r.isHakimKoot, isTrue);
    });

    test('8-5 win is a normal 1 point', () {
      final r = scorer.settleRound(
          tricksTeam0: 8, tricksTeam1: 5, hakimTeamIndex: 1);
      expect(r.pointsAwarded, 1);
      expect(r.winnerTeamIndex, 0);
    });
  });

  group('Match progression', () {
    test('match ends when target reached', () {
      final teams = [
        Team(index: 0, playerIds: const ['a', 'b']),
        Team(index: 1, playerIds: const ['c', 'd']),
      ];
      for (var i = 0; i < 7; i++) {
        final r = scorer.settleRound(
            tricksTeam0: 7, tricksTeam1: 6, hakimTeamIndex: 0);
        final over = scorer.applyAndCheckMatchEnd(r, teams);
        expect(over, i == 6);
      }
      expect(scorer.matchWinnerIndex(teams), 0);
      expect(teams[0].matchScore, 7);
    });

    test('hakim-koot accelerates the match (3 points)', () {
      final teams = [
        Team(index: 0, playerIds: const ['a', 'b']),
        Team(index: 1, playerIds: const ['c', 'd'], matchScore: 5),
      ];
      final r = scorer.settleRound(
          tricksTeam0: 0, tricksTeam1: 13, hakimTeamIndex: 0);
      final over = scorer.applyAndCheckMatchEnd(r, teams);
      expect(teams[1].matchScore, 8);
      expect(over, isTrue);
      expect(scorer.matchWinnerIndex(teams), 1);
    });

    test('not over below target', () {
      final teams = [
        Team(index: 0, playerIds: const ['a', 'b'], matchScore: 4),
        Team(index: 1, playerIds: const ['c', 'd'], matchScore: 3),
      ];
      expect(scorer.isMatchOver(teams), isFalse);
      expect(scorer.matchWinnerIndex(teams), isNull);
    });

    test('custom target respected', () {
      const short = ScoreManager(matchTarget: 3);
      final teams = [
        Team(index: 0, playerIds: const ['a', 'b'], matchScore: 2),
        Team(index: 1, playerIds: const ['c', 'd']),
      ];
      final r = short.settleRound(
          tricksTeam0: 7, tricksTeam1: 6, hakimTeamIndex: 1);
      expect(short.applyAndCheckMatchEnd(r, teams), isTrue);
    });
  });
}
