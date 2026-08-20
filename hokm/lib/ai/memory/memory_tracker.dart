import '../../game_engine/models/playing_card.dart';
import '../../game_engine/models/rank.dart';
import '../../game_engine/models/suit.dart';
import '../../game_engine/models/trick.dart';
import '../../game_engine/state/game_enums.dart';
import '../ai_view.dart';

/// حافظهٔ AI — فقط از اطلاعات عمومی ساخته می‌شود.
///
/// هر تصمیم یک نمونهٔ تازه از روی [AiGameView] ساخته می‌شود
/// (stateless → بدون باگ هم‌گام‌سازی، کاملاً قابل تست).
///
/// دانش استنتاجی:
///  * کارت‌های دیده‌شده و باقی‌ماندهٔ هر خال
///  * خال‌هایی که هر بازیکن «اثبات‌پذیر» خالی است: کسی که به خال زمینه
///    نرفته، یقیناً آن خال را ندارد (قانونالزام رفتن به خال).
class MemoryTracker {
  MemoryTracker._({
    required this.me,
    required this.seen,
    required this.myHand,
    required Map<Seat, Set<Suit>> voids,
  }) : _voids = voids;

  final Seat me;
  final Set<PlayingCard> seen;
  final List<PlayingCard> myHand;

  /// خال‌هایی که هر جایگاه یقیناً ندارد.
  final Map<Seat, Set<Suit>> _voids;

  /// ساخت حافظه از نمای عمومی بازی.
  factory MemoryTracker.fromView(AiGameView view) {
    final seen = <PlayingCard>{
      for (final play in view.allPlays) play.card,
    };
    final voids = <Seat, Set<Suit>>{
      for (final s in Seat.values) s: <Suit>{},
    };
    // استنتاج خالِ خالی از دورهای کامل و دور جاری.
    for (final trick in <Trick>[...view.trickHistory, view.currentTrick]) {
      final cards = trick.cards;
      if (cards.isEmpty) continue;
      final led = cards.first.card.suit;
      for (final play in cards.skip(1)) {
        if (play.card.suit != led) {
          voids[play.seat]!.add(led);
        }
      }
    }
    return MemoryTracker._(
      me: view.mySeat,
      seen: seen,
      myHand: view.myHand,
      voids: voids,
    );
  }

  /// آیا [seat] یقیناً خال [suit] را ندارد؟
  bool isVoid(Seat seat, Suit suit) => _voids[seat]!.contains(suit);

  /// کارت‌های باقی‌ماندهٔ یک خال — خارج از دستِ خودم و خارج از بازی‌شده‌ها.
  /// (این دقیقاً همان مجموعه‌ای است که یک بازیکن واقعیِ حافظه‌دار می‌داند.)
  List<PlayingCard> remainingOfSuit(Suit suit) {
    return <PlayingCard>[
      for (final rank in Rank.values)
        PlayingCard(suit, rank),
    ]
        .where((c) => !seen.contains(c) && !myHand.contains(c))
        .toList()
      ..sort((a, b) => b.rank.value.compareTo(a.rank.value));
  }

  /// تعداد حکم‌های باقی‌مانده خارج از دست من.
  int trumpsOutstanding(Suit trump) => remainingOfSuit(trump).length;

  /// بالاترین کارت باقی‌ماندهٔ یک خال (null اگر همه دیده شده‌اند).
  PlayingCard? highestOutstanding(Suit suit) {
    final remaining = remainingOfSuit(suit);
    return remaining.isEmpty ? null : remaining.first;
  }

  /// آیا [card] قوی‌ترین کارتِ باقی‌ماندهٔ خالش است؟
  /// (همهٔ کارت‌های بالاتر دیده شده‌اند یا در دست خودم است.)
  bool isHighestRemaining(PlayingCard card) {
    for (final rank in Rank.values) {
      // فقط رتبه‌های بالاتر از کارت مهم‌اند؛ پایین‌ترها معیار نیستند.
      if (rank.value <= card.rank.value) continue;
      final higher = PlayingCard(card.suit, rank);
      if (seen.contains(higher) || myHand.contains(higher)) continue;
      return false; // یک کارت بالاتر هنوز بیرون است.
    }
    return true;
  }

  /// کارت‌های بالاتر از [card] در خالش که هنوز بیرون‌اند.
  List<PlayingCard> higherOutstanding(PlayingCard card) {
    return <PlayingCard>[
      for (final rank in Rank.values)
        if (rank.value > card.rank.value) PlayingCard(card.suit, rank),
    ]
        .where((c) => !seen.contains(c) && !myHand.contains(c))
        .toList();
  }
}
