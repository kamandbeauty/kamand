/// قوانین پایهٔ بازی شلم: خالِ مؤثر، کارت‌های مجاز و تعیین برندهٔ دست.
library;

import '../model/card.dart';

/// یک برگِ بازی‌شده روی زمین.
class PlayedCard {
  const PlayedCard(this.player, this.card);

  final int player;
  final PlayingCard card;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'p': player, 'c': card.toJson()};

  static PlayedCard fromJson(Map<String, dynamic> json) => PlayedCard(
        json['p'] as int,
        PlayingCard.fromJson(Map<String, dynamic>.from(json['c'] as Map)),
      );
}

/// امتیاز هر دست (چهار برگ) در شلم.
const int kTrickBonus = 5;

/// خالی که کارت در عمل با آن بازی می‌کند.
/// جوکرها همیشه جزو خالِ حکم محسوب می‌شوند.
Suit effectiveSuit(PlayingCard card, Suit? trump) {
  if (card.isJoker) return trump ?? Suit.joker;
  return card.suit;
}

/// آیا این برگ، برگِ حکم است؟ (جوکر هم حکم است)
bool isTrumpCard(PlayingCard card, Suit? trump) =>
    trump != null && effectiveSuit(card, trump) == trump;

/// کارت‌هایی که بازیکن طبق قانونِ «اجبار به خالِ زمین» می‌تواند بازی کند.
///
/// اگر از خالِ زمین کارت داشته باشد، فقط همان‌ها مجازند؛ در غیر این صورت
/// هر کارتی (از جمله بریدن با حکم یا رد دادن) مجاز است.
List<PlayingCard> legalCards({
  required List<PlayingCard> hand,
  required Suit? leadSuit,
  required Suit? trump,
}) {
  if (leadSuit == null) return List<PlayingCard>.of(hand);
  final List<PlayingCard> follow = hand
      .where((PlayingCard c) => effectiveSuit(c, trump) == leadSuit)
      .toList();
  return follow.isNotEmpty ? follow : List<PlayingCard>.of(hand);
}

/// آیا [card] از [best] (برگِ برندهٔ فعلی) قوی‌تر است؟
bool cardBeats({
  required PlayingCard card,
  required PlayingCard best,
  required Suit? trump,
  required Suit leadSuit,
}) {
  final Suit cs = effectiveSuit(card, trump);
  final Suit bs = effectiveSuit(best, trump);
  if (cs == bs) return card.rank > best.rank;
  if (trump != null && cs == trump) return true;
  if (trump != null && bs == trump) return false;
  return bs != leadSuit && cs == leadSuit;
}

/// ایندکس برندهٔ دست در فهرست [trick].
int trickWinnerIndex(List<PlayedCard> trick, Suit? trump) {
  if (trick.isEmpty) return -1;
  final Suit leadSuit = effectiveSuit(trick.first.card, trump);
  int best = 0;
  for (int i = 1; i < trick.length; i++) {
    if (cardBeats(
      card: trick[i].card,
      best: trick[best].card,
      trump: trump,
      leadSuit: leadSuit,
    )) {
      best = i;
    }
  }
  return best;
}

/// شمارهٔ بازیکن برندهٔ دست.
int trickWinner(List<PlayedCard> trick, Suit? trump) =>
    trick[trickWinnerIndex(trick, trump)].player;

/// امتیاز کارت‌های یک دست + ۵ امتیاز خودِ دست.
int trickScore(List<PlayedCard> trick) =>
    kTrickBonus + cardPointsOf(trick.map((PlayedCard p) => p.card));

/// مرتب‌سازی دست بازیکن: حکم اول، سپس خال‌ها؛ در هر خال از بزرگ به کوچک.
List<PlayingCard> sortedHand(List<PlayingCard> hand, Suit? trump) {
  final List<PlayingCard> out = List<PlayingCard>.of(hand);
  int suitOrder(PlayingCard c) {
    final Suit s = effectiveSuit(c, trump);
    if (trump != null && s == trump) return -1;
    return c.isJoker ? 9 : kRealSuits.indexOf(c.suit);
  }

  out.sort((PlayingCard a, PlayingCard b) {
    final int sa = suitOrder(a);
    final int sb = suitOrder(b);
    if (sa != sb) return sa.compareTo(sb);
    return b.rank.compareTo(a.rank);
  });
  return out;
}
