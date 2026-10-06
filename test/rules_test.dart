import 'package:flutter_test/flutter_test.dart';
import 'package:shelem/game/rules.dart';
import 'package:shelem/model/card.dart';

PlayingCard c(Suit s, int r) => PlayingCard(s, r);

void main() {
  group('دسته کارت و امتیازها', () {
    test('دستهٔ استاندارد ۵۲ برگ و با جوکر ۵۴ برگ است', () {
      expect(buildDeck().length, 52);
      expect(buildDeck(withJokers: true).length, 54);
      expect(buildDeck().toSet().length, 52);
    });

    test('مجموع امتیاز برگ‌ها ۱۰۰ و با جوکرها ۱۳۵ است', () {
      expect(cardPointsOf(buildDeck()), 100);
      expect(cardPointsOf(buildDeck(withJokers: true)), 135);
    });

    test('امتیاز تک‌تک برگ‌ها', () {
      expect(c(Suit.spades, 14).points, 10);
      expect(c(Suit.hearts, 10).points, 10);
      expect(c(Suit.clubs, 5).points, 5);
      expect(c(Suit.diamonds, 9).points, 0);
      expect(const PlayingCard(Suit.joker, kRedJokerRank).points, 20);
      expect(const PlayingCard(Suit.joker, kBlackJokerRank).points, 15);
    });
  });

  group('خالِ مؤثر و حکم', () {
    test('جوکر هم‌خالِ حکم به حساب می‌آید', () {
      const PlayingCard jk = PlayingCard(Suit.joker, kRedJokerRank);
      expect(effectiveSuit(jk, Suit.hearts), Suit.hearts);
      expect(isTrumpCard(jk, Suit.hearts), isTrue);
      expect(isTrumpCard(c(Suit.hearts, 2), Suit.hearts), isTrue);
      expect(isTrumpCard(c(Suit.spades, 14), Suit.hearts), isFalse);
    });
  });

  group('کارت‌های مجاز', () {
    final List<PlayingCard> hand = <PlayingCard>[
      c(Suit.spades, 5),
      c(Suit.spades, 13),
      c(Suit.hearts, 7),
      c(Suit.clubs, 14),
    ];

    test('شروع‌کنندهٔ دست هر کارتی می‌تواند بازی کند', () {
      expect(
        legalCards(hand: hand, leadSuit: null, trump: Suit.hearts).length,
        4,
      );
    });

    test('باید از خالِ زمین بازی کرد', () {
      final List<PlayingCard> legal =
          legalCards(hand: hand, leadSuit: Suit.spades, trump: Suit.hearts);
      expect(legal.length, 2);
      expect(legal.every((PlayingCard x) => x.suit == Suit.spades), isTrue);
    });

    test('نداشتنِ خالِ زمین یعنی آزادی کامل', () {
      final List<PlayingCard> legal =
          legalCards(hand: hand, leadSuit: Suit.diamonds, trump: Suit.hearts);
      expect(legal.length, 4);
    });
  });

  group('برندهٔ دست', () {
    test('بالاترین برگِ خالِ زمین برنده است', () {
      final List<PlayedCard> trick = <PlayedCard>[
        PlayedCard(0, c(Suit.spades, 9)),
        PlayedCard(1, c(Suit.spades, 13)),
        PlayedCard(2, c(Suit.spades, 4)),
        PlayedCard(3, c(Suit.hearts, 14)),
      ];
      expect(trickWinner(trick, Suit.clubs), 1);
      expect(trickScore(trick), 5 + 10); // ۵ امتیاز دست + آسِ دل
    });

    test('حکم از خالِ زمین بالاتر است', () {
      final List<PlayedCard> trick = <PlayedCard>[
        PlayedCard(0, c(Suit.spades, 14)),
        PlayedCard(1, c(Suit.clubs, 2)),
        PlayedCard(2, c(Suit.spades, 13)),
        PlayedCard(3, c(Suit.spades, 4)),
      ];
      expect(trickWinner(trick, Suit.clubs), 1);
    });

    test('حکمِ بالاتر، حکمِ پایین‌تر را می‌بُرد', () {
      final List<PlayedCard> trick = <PlayedCard>[
        PlayedCard(0, c(Suit.spades, 14)),
        PlayedCard(1, c(Suit.clubs, 2)),
        PlayedCard(2, c(Suit.spades, 13)),
        PlayedCard(3, c(Suit.clubs, 3)),
      ];
      expect(trickWinner(trick, Suit.clubs), 3);
    });

    test('جوکر قرمز بالاترین برگِ حکم است', () {
      final List<PlayedCard> trick = <PlayedCard>[
        PlayedCard(0, c(Suit.clubs, 14)),
        const PlayedCard(1, PlayingCard(Suit.joker, kBlackJokerRank)),
        const PlayedCard(2, PlayingCard(Suit.joker, kRedJokerRank)),
        PlayedCard(3, c(Suit.clubs, 5)),
      ];
      expect(trickWinner(trick, Suit.clubs), 2);
      expect(trickScore(trick), 5 + 10 + 15 + 20 + 5);
    });

    test('امتیاز هر دست دست‌کم ۵ است', () {
      final List<PlayedCard> trick = <PlayedCard>[
        PlayedCard(0, c(Suit.spades, 2)),
        PlayedCard(1, c(Suit.spades, 3)),
        PlayedCard(2, c(Suit.spades, 4)),
        PlayedCard(3, c(Suit.spades, 6)),
      ];
      expect(trickScore(trick), kTrickBonus);
    });
  });
}
