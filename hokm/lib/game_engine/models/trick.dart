import '../state/game_enums.dart';
import 'playing_card.dart';
import 'suit.dart';

/// یک کارتِ بازی‌شده همراه עם بازیکنش — ترتیب در [cards] حفظ می‌شود.
class PlayedCard {
  const PlayedCard({required this.seat, required this.card});

  final Seat seat;
  final PlayingCard card;

  Map<String, dynamic> toJson() => {
        'seat': seat.index,
        'card': card.id,
      };

  factory PlayedCard.fromJson(Map<String, dynamic> json) => PlayedCard(
        seat: Seat.fromIndex(json['seat'] as int),
        card: PlayingCard.fromId(json['card'] as String),
      );

  @override
  String toString() => '${seat.name}:${card.id}';
}

/// یک دور (تریک) — حداکثر ۴ کارت، یکی از هر بازیکن.
class Trick {
  Trick({required this.leaderSeat});

  /// کسی که دور را شروع کرده.
  final Seat leaderSeat;

  final List<PlayedCard> cards = <PlayedCard>[];

  int get playCount => cards.length;
  bool get isEmpty => cards.isEmpty;
  bool get isComplete => cards.length == 4;

  /// خال زمینه — خال اولین کارت دور.
  Suit? get ledSuit => isEmpty ? null : cards.first.card.suit;

  /// آیا [candidate] نسبت به [current] با حکمِ [trump] برنده است؟
  static bool beats(PlayingCard candidate, PlayingCard current, Suit trump) {
    final candTrump = candidate.suit == trump;
    final curTrump = current.suit == trump;
    if (candTrump != curTrump) return candTrump;
    if (candTrump) {
      // هر دو حکم: بالاتر برنده است.
      return candidate.rank.value > current.rank.value;
    }
    // هیچ‌کدام حکم نیستند: فقط خال زمینه رقابت می‌کند.
    if (candidate.suit != current.suit) return false;
    return candidate.rank.value > current.rank.value;
  }

  /// برندهٔ فعلی دور (با توجه به کارت‌های تا این لحظه).
  ///
  /// [trump] باید خال حکمِ این دست باشد.
  PlayedCard currentWinner(Suit trump) {
    if (isEmpty) throw StateError('Trick is empty');
    var best = cards.first;
    for (var i = 1; i < cards.length; i++) {
      final candidate = cards[i];
      if (beats(candidate.card, best.card, trump)) {
        best = candidate;
      }
    }
    return best;
  }

  void add(PlayedCard played) {
    if (isComplete) throw StateError('Trick already complete');
    cards.add(played);
  }

  Map<String, dynamic> toJson() => {
        'leaderSeat': leaderSeat.index,
        'cards': cards.map((p) => p.toJson()).toList(),
      };

  factory Trick.fromJson(Map<String, dynamic> json) {
    final trick = Trick(leaderSeat: Seat.fromIndex(json['leaderSeat'] as int));
    for (final p in json['cards'] as List<dynamic>) {
      trick.add(PlayedCard.fromJson(p as Map<String, dynamic>));
    }
    return trick;
  }

  @override
  String toString() =>
      'Trick(led=$ledSuit, ${cards.map((p) => p.toString()).join(', ')})';
}
