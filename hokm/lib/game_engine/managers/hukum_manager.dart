import 'dart:math';

import '../models/deck.dart';
import '../models/playing_card.dart';
import '../models/rank.dart';
import '../models/suit.dart';
import '../state/game_enums.dart';

/// مدیریت «حاکم» — تعیین حاکم آغاز مسابقه، چرخش حاکم
/// و اعتبارسنجی انتخاب حکم.
///
/// قانون چرخش: تا وقتی تیم حاکم دست را ببرد، حاکم همان می‌ماند؛
/// وقتی ببازد، حاکمی به بازیکن سمت راست (نفر بعدی) منتقل می‌شود —
/// که به‌طور طبیعی در تیم حریف است.
class HukumManager {
  HukumManager({Seat? hakim}) : _hakim = hakim;

  Seat? _hakim;

  Seat? get hakim => _hakim;

  bool get isHakimDetermined => _hakim != null;

  /// تعیین حاکم اولیهٔ مسابقه با پخش کارت تا اولین آس.
  ///
  /// از یک دستهٔ بر‌خورده به ترتیب از [startSeat] کارت می‌دهد تا
  /// اولین آس ظاهر شود. کارت‌های پخش‌شده (برای انیمیشن) برگردانده می‌شوند
  /// و خود دسته برای پخش اصلی دست دوباره برمی‌خورد (در [HokmEngine]).
  HakimDeterminationResult determineHakim(Deck deck, Seat startSeat) {
    final dealt = <PlayedForHakim>[];
    var seat = startSeat;
    while (deck.isNotEmpty) {
      final card = deck.drawOne();
      dealt.add(PlayedForHakim(seat: seat, card: card));
      if (card.rank == Rank.ace) {
        _hakim = seat;
        return HakimDeterminationResult(hakim: seat, dealtCards: dealt);
      }
      seat = seat.next;
    }
    throw StateError('Deck exhausted without finding an ace — impossible');
  }

  /// تعیین مستقیم حاکم (مثلاً هنگام بازیابی بازی ذخیره‌شده).
  void setHakim(Seat seat) => _hakim = seat;

  /// پس از پایان دست: اگر تیم حاکم برد همان می‌ماند، وگرنه حاکمی
  /// به نفر بعدی (تیم حریف) منتقل می‌شود.
  Seat rotateAfterRound({required int winnerTeamIndex}) {
    final hakim = _hakim;
    if (hakim == null) throw StateError('Hakim not determined yet');
    if (hakim.teamIndex != winnerTeamIndex) {
      _hakim = hakim.next;
    }
    return _hakim!;
  }

  /// آیا انتخاب این خال برای این دست معتبر است؟
  /// (حاکم باید از روی ۵ کارت اولش تصمیم بگیرد —
  /// محدودیتی روی خال انتخابی نیست، اما خال باید معتبر باشد.)
  bool canSelectTrump(Suit suit, List<PlayingCard> hakimHandPreview) =>
      Suit.values.contains(suit);

  Map<String, dynamic> toJson() => {'hakim': _hakim?.index};

  void restore(Map<String, dynamic> json) {
    final idx = json['hakim'] as int?;
    _hakim = idx == null ? null : Seat.fromIndex(idx);
  }
}

/// کارتِ پخش‌شده به‌هنگام تعیین حاکم.
class PlayedForHakim {
  const PlayedForHakim({required this.seat, required this.card});

  final Seat seat;
  final PlayingCard card;
}

class HakimDeterminationResult {
  const HakimDeterminationResult({required this.hakim, required this.dealtCards});

  final Seat hakim;
  final List<PlayedForHakim> dealtCards;
}

/// نگه‌داشتن Random برای استفاده‌های بعدی (مثلاً seed تست).
typedef SeedProvider = Random Function();
