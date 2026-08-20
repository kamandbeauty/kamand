import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hokm/game_engine/models/deck.dart';
import 'package:hokm/game_engine/models/playing_card.dart';
import 'package:hokm/game_engine/models/rank.dart';
import 'package:hokm/game_engine/models/suit.dart';

void main() {
  group('Deck', () {
    test('standard deck has 52 unique cards', () {
      final deck = Deck.standard();
      expect(deck.length, 52);
      expect(deck.cards.toSet().length, 52);
    });

    test('contains all 4 suits × 13 ranks', () {
      final deck = Deck.standard();
      for (final suit in Suit.values) {
        for (final rank in Rank.values) {
          expect(
            deck.cards.contains(PlayingCard(suit, rank)),
            isTrue,
            reason: 'missing ${suit.code}_${rank.symbol}',
          );
        }
      }
    });

    test('shuffle preserves the card set', () {
      final before = Deck.standard().cards.toSet();
      final deck = Deck.standard()..shuffle(Random(7));
      expect(deck.cards.toSet(), before);
    });

    test('shuffle actually changes order (seeded)', () {
      final ordered = Deck.standard().cards;
      final shuffled = (Deck.standard()..shuffle(Random(99))).cards;
      // با seed ثابت ترتیب عوض می‌شود — احتمال برابری تصادفی ناچیز است.
      var samePositions = 0;
      for (var i = 0; i < 52; i++) {
        if (ordered[i] == shuffled[i]) samePositions++;
      }
      expect(samePositions, lessThan(10));
    });

    test('draw removes cards from deck', () {
      final deck = Deck.standard();
      final drawn = deck.draw(5);
      expect(drawn.length, 5);
      expect(deck.length, 47);
      // کارت کشیده‌شده دیگر در دسته نیست.
      for (final c in drawn) {
        expect(deck.cards.contains(c), isFalse);
      }
    });

    test('drawing more than available throws', () {
      final deck = Deck.standard();
      deck.draw(50);
      expect(() => deck.draw(3), throwsStateError);
    });

    test('json round-trip preserves order and content', () {
      final deck = Deck.standard()..shuffle(Random(3));
      final restored = Deck.fromJson(deck.toJson());
      expect(restored.cards, deck.cards);
    });

    test('card id round-trip', () {
      for (final suit in Suit.values) {
        for (final rank in Rank.values) {
          final card = PlayingCard(suit, rank);
          expect(PlayingCard.fromId(card.id), card);
        }
      }
    });
  });
}
