import '../state/game_enums.dart';
import 'playing_card.dart';
import 'suit.dart';

/// بازیکن — نگهدارندهٔ دست کارت و هویت.
///
/// توجه: این کلاس فقط داده است؛ تصمیم‌گیری در UI/AI انجام می‌شود.
class Player {
  Player({
    required this.id,
    required this.name,
    required this.seat,
    required this.isHuman,
    List<PlayingCard>? hand,
  }) : hand = List<PlayingCard>.of(hand ?? const <PlayingCard>[]);

  /// شناسهٔ پایدار (برای سریالایز).
  final String id;

  /// نام نمایشی.
  String name;

  final Seat seat;

  final bool isHuman;

  /// دست فعلی (داخلی قابل تغییر، از بیرون فقط‌خواندنی دیده می‌شود).
  final List<PlayingCard> hand;

  int get handCount => hand.length;

  bool get handIsEmpty => hand.isEmpty;

  void addCards(List<PlayingCard> cards) => hand.addAll(cards);

  /// حذف کارت از دست؛ اگر کارت وجود نداشته باشد استثنا پرتاب می‌شود.
  PlayingCard removeCard(PlayingCard card) {
    final index = hand.indexWhere((c) => c == card);
    if (index < 0) {
      throw StateError('Player $id does not hold card ${card.id}');
    }
    return hand.removeAt(index);
  }

  bool hasCard(PlayingCard card) => hand.contains(card);

  /// کارت‌های یک خال مرتب‌شده از قوی به ضعیف.
  List<PlayingCard> cardsOfSuit(Suit suit) {
    final cards = hand.where((c) => c.suit == suit).toList()
      ..sort((a, b) => b.rank.value.compareTo(a.rank.value));
    return cards;
  }

  bool hasSuit(Suit suit) => hand.any((c) => c.suit == suit);

  /// مرتب‌سازی دست برای نمایش (خال‌به‌خال، داخل هر خال نزولی).
  void sortHand(Suit? trump) {
    hand.sort((a, b) {
      // حکم‌ها اول نمایش داده شوند.
      final aTrump = a.isTrump(trump) ? 0 : 1;
      final bTrump = b.isTrump(trump) ? 0 : 1;
      if (aTrump != bTrump) return aTrump - bTrump;
      final suitCmp = a.suit.index.compareTo(b.suit.index);
      if (suitCmp != 0) return suitCmp;
      return b.rank.value.compareTo(a.rank.value);
    });
  }

  Player clone() => Player(
        id: id,
        name: name,
        seat: seat,
        isHuman: isHuman,
        hand: hand,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'seat': seat.index,
        'isHuman': isHuman,
        'hand': hand.map((c) => c.id).toList(),
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        name: json['name'] as String,
        seat: Seat.fromIndex(json['seat'] as int),
        isHuman: json['isHuman'] as bool,
        hand: (json['hand'] as List<dynamic>)
            .map((id) => PlayingCard.fromId(id as String))
            .toList(),
      );

  @override
  String toString() => 'Player($name, ${seat.name}, ${hand.length} cards)';
}
