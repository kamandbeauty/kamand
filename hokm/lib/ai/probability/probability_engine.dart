import '../../game_engine/models/playing_card.dart';
import '../../game_engine/models/suit.dart';
import '../../game_engine/state/game_enums.dart';
import '../ai_view.dart';
import '../memory/memory_tracker.dart';

/// موتور احتمال — تخمین‌های تقریبی از توزیع کارت‌های نامعلوم.
///
/// فقط از شمارش عمومی استفاده می‌کند (تعداد کارتِ دست هر بازیکن،
/// کارت‌های دیده‌شده، خال‌های خالیِ اثبات‌شده). بدون تقلب.
class ProbabilityEngine {
  const ProbabilityEngine({required this.view, required this.memory});

  final AiGameView view;
  final MemoryTracker memory;

  /// احتمال تقریبی اینکه حداقل یکی از *حریفان* بتواند یک کارتِ بالاتر
  /// از [card] در همان خال داشته باشد (خالِ غیر حکم).
  ///
  /// مدل ساده: کارت‌های بالاترِ نامعلوم روی بازیکنانی که آن خال را
  /// دارند (خالی نیستند) و هنوز کارت دارند، توزیع یکنواخت فرض می‌شود.
  double chanceOppHasHigherInSuit(PlayingCard card) {
    final higher = memory.higherOutstanding(card);
    if (higher.isEmpty) return 0.0;
    return _chanceHeldByOpponents(higher.length, card.suit);
  }

  /// احتمال اینکه حریف‌ها هنوز حکم داشته باشند (لااقل یکی).
  double chanceOpponentsHaveTrump() {
    final out = memory.trumpsOutstanding(view.trump);
    if (out == 0) return 0.0;
    return _chanceHeldByOpponents(out, view.trump);
  }

  /// احتمال اینکه یار خال [suit] را خالی باشد و بتواند حکم بزند —
  /// برای لیّد دادن به خالِ خالیِ یار استفاده می‌شود.
  bool partnerDefinitelyVoid(Suit suit) =>
      memory.isVoid(view.partnerSeat, suit);

  bool opponentMightBeVoid(Seat opponent, Suit suit) =>
      memory.isVoid(opponent, suit);

  /// احتمال تقریبی اینکه از [unknownCount] کارتِ نامعلومِ یک خال،
  /// لااقل یکی نزد حریفان باشد.
  double _chanceHeldByOpponents(int unknownCount, Suit suit) {
    // بازیکنانِ دیگری که ممکن است این خال را داشته باشند.
    final candidates = <Seat>[
      for (final s in Seat.values)
        if (s != view.mySeat &&
            !memory.isVoid(s, suit) &&
            (view.handCounts[s] ?? 0) > 0)
          s,
    ];
    if (candidates.isEmpty) return 0.0;

    var oppSlots = 0;
    var partnerSlots = 0;
    for (final s in candidates) {
      final count = view.handCounts[s] ?? 0;
      if (s.isPartnerOf(view.mySeat)) {
        partnerSlots += count;
      } else {
        oppSlots += count;
      }
    }
    final totalSlots = oppSlots + partnerSlots;
    if (totalSlots <= 0) return 0.0;

    // P(همهٔ کارت‌ها نزد یار) با فرض توزیع یکنواخت ≈ (partner/total)^k
    // دقیق نیست اما heuristicِ باثبات و سریعی است.
    var pAllPartner = 1.0;
    for (var i = 0; i < unknownCount; i++) {
      final p = partnerSlots - i;
      final t = totalSlots - i;
      if (t <= 0) {
        // اسلات‌های نامعلوم کمتر از کارت‌های بیرون‌مانده است —
        // یعنی حریف قطعاً لااقل یکی را دارد.
        return oppSlots > 0 ? 1.0 : 0.0;
      }
      if (p <= 0) {
        pAllPartner = 0.0;
        break;
      }
      pAllPartner *= p / t;
      if (pAllPartner <= 0) break;
    }
    return (1.0 - pAllPartner).clamp(0.0, 1.0);
  }
}
