import 'rank.dart';
import 'suit.dart';

/// یک کارت بازی — value object تغییرناپذیر.
///
/// برابری بر اساس زوج (suit, rank) است؛ در یک دست ۵۲کارتی استاندارد
/// این زوج یکتا است، پس [id] نیز یکتاست.
class PlayingCard {
  const PlayingCard(this.suit, this.rank);

  final Suit suit;
  final Rank rank;

  /// شناسهٔ پایدار و خوانا مثل `S_A` (پیک آس) — برای سریالایز/ذخیره.
  String get id => '${suit.code}_${rank.symbol}';

  /// آیا این کارت در بازی با حکمِ [trump]، کارت حکم است؟
  bool isTrump(Suit? trump) => trump != null && suit == trump;

  static PlayingCard fromId(String id) {
    final parts = id.split('_');
    if (parts.length != 2) {
      throw ArgumentError('Invalid card id: $id');
    }
    return PlayingCard(Suit.fromCode(parts[0]), Rank.fromSymbol(parts[1]));
  }

  Map<String, dynamic> toJson() => {'id': id};

  factory PlayingCard.fromJson(Map<String, dynamic> json) =>
      PlayingCard.fromId(json['id'] as String);

  PlayingCard copyWith({Suit? suit, Rank? rank}) =>
      PlayingCard(suit ?? this.suit, rank ?? this.rank);

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => Object.hash(suit, rank);

  @override
  String toString() => '$rank.symbol${suit.code}';
}
