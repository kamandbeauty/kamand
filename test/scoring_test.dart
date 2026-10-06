import 'package:flutter_test/flutter_test.dart';
import 'package:shelem/game/scoring.dart';

void main() {
  group('امتیازدهی راند', () {
    test('قرارداد انجام شد: عددِ خوانده‌شده اضافه می‌شود', () {
      final RoundOutcome o = scoreRound(
        hakemTeam: 0,
        contract: 115,
        hakemPoints: 120,
        opponentPoints: 45,
        hakemWonAllTricks: false,
      );
      expect(o.contractMade, isTrue);
      expect(o.hakemDelta, 115);
      expect(o.opponentDelta, 45);
      expect(o.yasa, isFalse);
    });

    test('گزینهٔ امتیاز واقعی به‌جای عددِ قرارداد', () {
      final RoundOutcome o = scoreRound(
        hakemTeam: 1,
        contract: 100,
        hakemPoints: 130,
        opponentPoints: 35,
        hakemWonAllTricks: false,
        rules: const ScoringRules(hakemAward: HakemAward.actualPoints),
      );
      expect(o.hakemDelta, 130);
      expect(o.deltaFor(1), 130);
      expect(o.deltaFor(0), 35);
    });

    test('شکستِ ساده: منفیِ عددِ قرارداد', () {
      final RoundOutcome o = scoreRound(
        hakemTeam: 0,
        contract: 120,
        hakemPoints: 110,
        opponentPoints: 55,
        hakemWonAllTricks: false,
      );
      expect(o.contractMade, isFalse);
      expect(o.yasa, isFalse);
      expect(o.hakemDelta, -120);
      expect(o.opponentDelta, 55);
    });

    test('یاسا: کمتر از تیم مقابل ⇒ منفیِ دوبرابر', () {
      final RoundOutcome o = scoreRound(
        hakemTeam: 0,
        contract: 100,
        hakemPoints: 70,
        opponentPoints: 95,
        hakemWonAllTricks: false,
      );
      expect(o.yasa, isTrue);
      expect(o.hakemDelta, -200);
      expect(o.opponentDelta, 95);
    });

    test('یاسا با قانون «کمتر از نصف قرارداد»', () {
      const ScoringRules r =
          ScoringRules(yasa: YasaRule.lessThanHalfContract);
      expect(
        scoreRound(
          hakemTeam: 0,
          contract: 160,
          hakemPoints: 75,
          opponentPoints: 90,
          hakemWonAllTricks: false,
          rules: r,
        ).hakemDelta,
        -320,
      );
      expect(
        scoreRound(
          hakemTeam: 0,
          contract: 160,
          hakemPoints: 85,
          opponentPoints: 80,
          hakemWonAllTricks: false,
          rules: r,
        ).hakemDelta,
        -160,
      );
    });

    test('خاموش بودن یاسا', () {
      final RoundOutcome o = scoreRound(
        hakemTeam: 0,
        contract: 100,
        hakemPoints: 20,
        opponentPoints: 145,
        hakemWonAllTricks: false,
        rules: const ScoringRules(yasa: YasaRule.off),
      );
      expect(o.yasa, isFalse);
      expect(o.hakemDelta, -100);
    });

    test('شلم (گرفتن تمام دست‌ها) ⇒ دو برابر قرارداد', () {
      final RoundOutcome o = scoreRound(
        hakemTeam: 0,
        contract: 120,
        hakemPoints: 165,
        opponentPoints: 0,
        hakemWonAllTricks: true,
      );
      expect(o.slam, isTrue);
      expect(o.hakemDelta, 240);
      expect(o.opponentDelta, 0);
    });

    test('شلم با پاداشِ ثابت ۳۳۰', () {
      final RoundOutcome o = scoreRound(
        hakemTeam: 0,
        contract: 110,
        hakemPoints: 165,
        opponentPoints: 0,
        hakemWonAllTricks: true,
        rules: const ScoringRules(slamAward: SlamAward.fixed330),
      );
      expect(o.hakemDelta, 330);
    });

    test('شلمِ اعلام‌شده فقط با گرفتن همهٔ دست‌ها موفق است', () {
      expect(
        scoreRound(
          hakemTeam: 0,
          contract: kShelemBid,
          hakemPoints: 165,
          opponentPoints: 0,
          hakemWonAllTricks: true,
        ).hakemDelta,
        330,
      );
      final RoundOutcome failed = scoreRound(
        hakemTeam: 0,
        contract: kShelemBid,
        hakemPoints: 160,
        opponentPoints: 5,
        hakemWonAllTricks: false,
      );
      expect(failed.contractMade, isFalse);
      expect(failed.hakemDelta, -330);
      expect(failed.opponentDelta, 5);
    });

    test('سرشلم ۶۶۰ امتیاز مثبت یا منفی دارد', () {
      expect(
        scoreRound(
          hakemTeam: 1,
          contract: kSarShelemBid,
          hakemPoints: 165,
          opponentPoints: 0,
          hakemWonAllTricks: true,
        ).hakemDelta,
        660,
      );
      expect(
        scoreRound(
          hakemTeam: 1,
          contract: kSarShelemBid,
          hakemPoints: 100,
          opponentPoints: 65,
          hakemWonAllTricks: false,
        ).hakemDelta,
        -660,
      );
    });

    test('گزینهٔ «تیم مقابل فقط در صورت شکستِ حاکم امتیاز می‌گیرد»', () {
      final RoundOutcome o = scoreRound(
        hakemTeam: 0,
        contract: 100,
        hakemPoints: 120,
        opponentPoints: 45,
        hakemWonAllTricks: false,
        rules: const ScoringRules(opponentAlwaysScores: false),
      );
      expect(o.opponentDelta, 0);
    });

    test('سریال‌سازی نتیجهٔ راند', () {
      final RoundOutcome o = scoreRound(
        hakemTeam: 0,
        contract: 105,
        hakemPoints: 110,
        opponentPoints: 55,
        hakemWonAllTricks: false,
      );
      final RoundOutcome back = RoundOutcome.fromJson(o.toJson());
      expect(back.hakemDelta, o.hakemDelta);
      expect(back.contract, o.contract);
      expect(back.contractMade, o.contractMade);
    });
  });
}
