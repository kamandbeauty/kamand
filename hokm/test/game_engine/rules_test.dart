import 'package:flutter_test/flutter_test.dart';
import 'package:hokm/game_engine/models/playing_card.dart';
import 'package:hokm/game_engine/models/suit.dart';
import 'package:hokm/game_engine/models/trick.dart';
import 'package:hokm/game_engine/rules/game_rules.dart';
import 'package:hokm/game_engine/state/game_enums.dart';

PlayingCard c(String id) => PlayingCard.fromId(id);

Trick trickOf(List<String> parts) {
  final leader =
      Seat.fromIndex(int.parse(parts.first.split(':').first));
  final trick = Trick(leaderSeat: leader);
  for (final part in parts) {
    final kv = part.split(':');
    trick.add(PlayedCard(seat: Seat.fromIndex(int.parse(kv[0])), card: c(kv[1])));
  }
  return trick;
}

void main() {
  const trump = Suit.spades;
  const noTrumpContext = Suit.hearts;

  group('Follow-suit legality', () {
    test('trick leader may play any card', () {
      final hand = [c('H_5'), c('S_A'), c('D_10')];
      final trick = Trick(leaderSeat: Seat.south);
      expect(GameRules.legalPlays(hand, trick).length, hand.length);
    });

    test('must follow suit when holding the led suit', () {
      final hand = [c('H_5'), c('H_9'), c('S_A')];
      final trick = trickOf(['0:H_Q']);
      final legal = GameRules.legalPlays(hand, trick);
      expect(legal, containsAll([c('H_5'), c('H_9')]));
      expect(legal.contains(c('S_A')), isFalse,
          reason: 'Holding hearts → must play hearts, spade is illegal');
    });

    test('may play trump when void in led suit', () {
      final hand = [c('S_5'), c('D_2')];
      final trick = trickOf(['0:H_Q']);
      final legal = GameRules.legalPlays(hand, trick);
      expect(legal.length, 2, reason: 'No hearts → whole hand is legal');
    });

    test('isLegalPlay agrees with legalPlays', () {
      final hand = [c('H_5'), c('S_A')];
      final trick = trickOf(['0:H_2']);
      expect(GameRules.isLegalPlay(c('H_5'), hand, trick), isTrue);
      expect(GameRules.isLegalPlay(c('S_A'), hand, trick), isFalse);
    });
  });

  group('Trick winner', () {
    test('highest card of led suit wins when no trump', () {
      final trick = trickOf(['0:H_5', '1:H_K', '2:H_A', '3:H_2']);
      final winner = GameRules.trickWinner(trick, trump);
      expect(winner.card, c('H_A'));
      expect(winner.seat, Seat.north);
    });

    test('lower led-suit cards lose to higher even if played later', () {
      final trick = trickOf(['0:H_Q', '1:H_10', '2:H_9', '3:H_J']);
      expect(GameRules.trickWinner(trick, trump).card, c('H_Q'));
    });

    test('a trump beats any non-trump', () {
      final trick = trickOf(['0:H_A', '1:S_2', '2:H_K', '3:H_Q']);
      final winner = GameRules.trickWinner(trick, trump);
      expect(winner.card, c('S_2'));
      expect(winner.seat, Seat.west);
    });

    test('higher trump beats lower trump', () {
      final trick = trickOf(['0:H_A', '1:S_5', '2:S_9', '3:S_2']);
      expect(GameRules.trickWinner(trick, trump).card, c('S_9'));
    });

    test('off-suit non-trump never beats led suit', () {
      final trick = trickOf(['0:H_3', '1:D_A', '2:C_A', '3:H_2']);
      expect(GameRules.trickWinner(trick, trump).card, c('H_3'),
          reason: 'Led hearts; aces of other suits do not beat hearts');
    });

    test('led suit beats trump of different round context check', () {
      // حکم قلب است؛ خال زمینه پیک. حکمِ قلب باید ببرد.
      final trick = trickOf(['0:S_A', '1:H_4', '2:S_K', '3:S_Q']);
      expect(GameRules.trickWinner(trick, noTrumpContext).card, c('H_4'),
          reason: 'Hearts is trump → even the 4 of hearts beats A of spades');
    });
  });

  group('Trick model', () {
    test('complete trick has 4 plays', () {
      final trick = trickOf(['0:H_5', '1:H_6', '2:H_7', '3:H_8']);
      expect(trick.isComplete, isTrue);
      expect(() => trick.add(PlayedCard(seat: Seat.south, card: c('H_9'))),
          throwsStateError);
    });

    test('json round-trip', () {
      final trick = trickOf(['1:S_Q', '2:S_K', '3:D_2']);
      final restored = Trick.fromJson(trick.toJson());
      expect(restored.leaderSeat, Seat.west);
      expect(restored.cards.map((p) => p.card), trick.cards.map((p) => p.card));
      expect(restored.cards.map((p) => p.seat), trick.cards.map((p) => p.seat));
    });
  });
}
