import '../models/deck.dart';
import '../models/player.dart';
import '../models/playing_card.dart';
import '../state/game_enums.dart';

/// یک مرحلهٔ پخش: چند کارت به یک بازیکن.
class DealStep {
  const DealStep({required this.seat, required this.cards});

  final Seat seat;
  final List<PlayingCard> cards;

  Map<String, dynamic> toJson() => {
        'seat': seat.index,
        'cards': cards.map((c) => c.id).toList(),
      };

  factory DealStep.fromJson(Map<String, dynamic> json) => DealStep(
        seat: Seat.fromIndex(json['seat'] as int),
        cards: (json['cards'] as List<dynamic>)
            .map((id) => PlayingCard.fromId(id as String))
            .toList(),
      );
}

/// مدیر پخش کارت — الگوی استاندارد حکم:
///
/// * پخش از بازیکنِ سمتِ راست حاکم شروع می‌شود و به خودِ حاکم ختم می‌شود.
/// * ابتدا ۵ کارت به هر بازیکن؛ حاکم پس از دیدن ۵ کارتش حکم را اعلام می‌کند؛
/// * سپس دو نوبت ۴ کارتی تا تکمیل ۱۳ کارت.
class DealManager {
  static const List<int> dealPattern = [5, 4, 4];

  /// ترتیب پخش: شروع از hakim.next به ترتیب چرخش نوبت.
  List<Seat> dealOrder(Seat hakim) =>
      List<Seat>.generate(4, (i) => Seat.fromIndex(hakim.index + 1 + i));

  /// پخش [size] کارت به هر بازیکن با ترتیب استاندارد.
  ///
  /// هم به [players] کارت می‌دهد و هم [DealStep]ها را برای انیمیشن برمی‌گرداند.
  List<DealStep> dealBatch({
    required Deck deck,
    required List<Player> players,
    required Seat hakim,
    required int size,
  }) {
    final order = dealOrder(hakim);
    final steps = <DealStep>[];
    for (final seat in order) {
      final cards = deck.draw(size);
      players[seat.index].addCards(cards);
      steps.add(DealStep(seat: seat, cards: cards));
    }
    return steps;
  }

  /// پخش ۵ کارت اولیه.
  List<DealStep> dealInitialFive({
    required Deck deck,
    required List<Player> players,
    required Seat hakim,
  }) =>
      dealBatch(deck: deck, players: players, hakim: hakim, size: 5);

  /// باقی کارت‌ها (۴+۴) — دو لیست مرحله برمی‌گرداند:
  /// اولی پخش ۴تایی، دومی پخش ۴تایی بعدی.
  List<List<DealStep>> dealRemaining({
    required Deck deck,
    required List<Player> players,
    required Seat hakim,
  }) {
    return [
      dealBatch(deck: deck, players: players, hakim: hakim, size: 4),
      dealBatch(deck: deck, players: players, hakim: hakim, size: 4),
    ];
  }
}
