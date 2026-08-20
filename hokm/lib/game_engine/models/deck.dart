import 'dart:math';

import 'playing_card.dart';
import 'rank.dart';
import 'suit.dart';

/// دستهٔ کامل ۵۲ برگ — مسئول ساخت، بر زدن و پخش کردن.
///
/// بر زدن با [Random] تزریق‌شده انجام می‌شود تا در تست‌ها
/// بتوان seed ثابت داد و رفتار قطعی گرفت.
class Deck {
  Deck._(this._cards);

  final List<PlayingCard> _cards;

  /// ساخت دستهٔ مرتب‌شدهٔ ۵۲ برگ (بدون جوکر).
  factory Deck.standard() {
    final cards = <PlayingCard>[
      for (final suit in Suit.values)
        for (final rank in Rank.values) PlayingCard(suit, rank),
    ];
    assert(cards.length == 52);
    return Deck._(cards);
  }

  factory Deck.fromCards(List<PlayingCard> cards) =>
      Deck._(List<PlayingCard>.of(cards));

  int get length => _cards.length;
  bool get isEmpty => _cards.isEmpty;
  bool get isNotEmpty => _cards.isNotEmpty;

  /// نمای فقط‌خواندنی از کارت‌های باقی‌مانده (بالای دسته = انتهای لیست).
  List<PlayingCard> get cards => List<PlayingCard>.unmodifiable(_cards);

  /// بر زدن با Fisher–Yates.
  void shuffle(Random random) {
    for (var i = _cards.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final tmp = _cards[i];
      _cards[i] = _cards[j];
      _cards[j] = tmp;
    }
  }

  /// کشیدن [count] کارت از بالای دسته.
  List<PlayingCard> draw(int count) {
    if (count < 0 || count > _cards.length) {
      throw StateError('Cannot draw $count cards from ${_cards.length}');
    }
    final drawn = _cards.sublist(_cards.length - count);
    _cards.removeRange(_cards.length - count, _cards.length);
    return drawn;
  }

  /// کشیدن یک کارت.
  PlayingCard drawOne() => draw(1).single;

  Map<String, dynamic> toJson() => {
        'cards': _cards.map((c) => c.id).toList(),
      };

  factory Deck.fromJson(Map<String, dynamic> json) => Deck._(
        (json['cards'] as List<dynamic>)
            .map((id) => PlayingCard.fromId(id as String))
            .toList(),
      );

  @override
  String toString() => 'Deck(${_cards.length} cards)';
}
