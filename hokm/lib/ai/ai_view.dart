import '../game_engine/models/playing_card.dart';
import '../game_engine/models/suit.dart';
import '../game_engine/models/trick.dart';
import '../game_engine/state/game_enums.dart';
import '../game_engine/state/game_state.dart';

/// نمای محدودِ بازی از چشم یک بازیکن AI.
///
/// **قرارداد ضدتقلب (anti-cheat boundary):**
/// AI فقط همین کلاس را می‌بیند. هیچ مسیر کدی از AI به دست بازیکنان
/// دیگر وجود ندارد — فقط:
///  * دستِ خودِ AI
///  * کارت‌های بازی‌شده (عمومی)
///  * دور و تاریخچهٔ عمومی
///  * تعداد کارتِ باقی‌ماندهٔ هر بازیکن (عمومی — قابل شمارش در بازی واقعی)
///  * امتیازها و تعداد دورهای برده‌شده (عمومی)
///
/// هر چیز دیگر باید از همین داده‌ها **استنتاج** شود (MemoryTracker).
class AiGameView {
  const AiGameView._({
    required this.mySeat,
    required this.myHand,
    required this.trump,
    required this.currentTrick,
    required this.trickHistory,
    required this.handCounts,
    required this.tricksWonUs,
    required this.tricksWonThem,
    required this.scoreUs,
    required this.scoreThem,
    required this.hakim,
    required this.matchTarget,
  });

  final Seat mySeat;
  final List<PlayingCard> myHand;
  final Suit trump;
  final Trick currentTrick;
  final List<Trick> trickHistory;

  /// تعداد کارتِ دست هر جایگاه (اطلاعات عمومی).
  final Map<Seat, int> handCounts;

  /// دورهای برده‌شدهٔ تیم ما / حریف در این دست.
  final int tricksWonUs;
  final int tricksWonThem;

  /// امتیاز مسابقهٔ تیم ما / حریف.
  final int scoreUs;
  final int scoreThem;

  final Seat hakim;
  final int matchTarget;

  // ---------- مشتقات ----------

  Seat get partnerSeat => mySeat.partner;

  List<Seat> get opponentSeats =>
      Seat.values.where((s) => !s.isPartnerOf(mySeat) && s != mySeat).toList();

  /// تیم ما چند دور دیگر لازم دارد تا دست را ببرد؟
  int get tricksNeededForUs => 7 - tricksWonUs;

  int get tricksNeededForThem => 7 - tricksWonThem;

  bool get isLeading => currentTrick.isEmpty;

  /// تعداد دورهای باقی‌مانده از این دست.
  int roundTricksRemaining() => 13 - trickHistory.length;

  /// همهٔ کارت‌های بازی‌شدهٔ این دست (عمومی).
  List<PlayedCard> get allPlays => <PlayedCard>[
        for (final t in trickHistory) ...t.cards,
        ...currentTrick.cards,
      ];

  /// ساخت دستی برای تست — سناریوهای مشخص AI بدون اجرای کل بازی.
  factory AiGameView.testing({
    required Seat mySeat,
    required List<PlayingCard> myHand,
    required Suit trump,
    Trick? currentTrick,
    List<Trick> trickHistory = const [],
    Map<Seat, int>? handCounts,
    int tricksWonUs = 0,
    int tricksWonThem = 0,
    int scoreUs = 0,
    int scoreThem = 0,
    Seat hakim = Seat.south,
    int matchTarget = 7,
  }) {
    return AiGameView._(
      mySeat: mySeat,
      myHand: myHand,
      trump: trump,
      currentTrick: currentTrick ?? Trick(leaderSeat: mySeat),
      trickHistory: List<Trick>.of(trickHistory),
      handCounts: handCounts ??
          {for (final s in Seat.values) s: 13},
      tricksWonUs: tricksWonUs,
      tricksWonThem: tricksWonThem,
      scoreUs: scoreUs,
      scoreThem: scoreThem,
      hakim: hakim,
      matchTarget: matchTarget,
    );
  }

  /// ساخت نمای محدود از GameState کامل — این متد تنها نقطهٔ
  /// تبدیل است و عمداً فقط دادهٔ مجاز را بیرون می‌دهد.
  factory AiGameView.fromState(GameState state, Seat mySeat) {
    assert(state.trump != null, 'Trump must be set before AI play');
    final myTeam = state.teams[mySeat.teamIndex];
    final theirTeam = state.teams[1 - mySeat.teamIndex];
    return AiGameView._(
      mySeat: mySeat,
      myHand: List<PlayingCard>.of(state.playerAt(mySeat).hand),
      trump: state.trump!,
      currentTrick: state.currentTrick ?? Trick(leaderSeat: state.currentTurn),
      trickHistory: List<Trick>.of(state.trickHistory),
      handCounts: {
        for (final s in Seat.values) s: state.playerAt(s).handCount,
      },
      tricksWonUs: state.tricksWon[mySeat.teamIndex],
      tricksWonThem: state.tricksWon[1 - mySeat.teamIndex],
      scoreUs: myTeam.matchScore,
      scoreThem: theirTeam.matchScore,
      hakim: state.hakim!,
      matchTarget: state.matchTarget,
    );
  }
}
