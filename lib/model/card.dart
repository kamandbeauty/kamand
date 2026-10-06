/// مدل کارت‌های پاسور برای بازی شلم.
library;

/// خال‌های پاسور. [Suit.joker] خالِ مجازی جوکرهاست.
enum Suit { spades, hearts, clubs, diamonds, joker }

extension SuitInfo on Suit {
  /// نماد خال
  String get symbol {
    switch (this) {
      case Suit.spades:
        return '♠';
      case Suit.hearts:
        return '♥';
      case Suit.clubs:
        return '♣';
      case Suit.diamonds:
        return '♦';
      case Suit.joker:
        return '★';
    }
  }

  /// نام فارسی خال
  String get fa {
    switch (this) {
      case Suit.spades:
        return 'پیک';
      case Suit.hearts:
        return 'دل';
      case Suit.clubs:
        return 'گشنیز';
      case Suit.diamonds:
        return 'خشت';
      case Suit.joker:
        return 'جوکر';
    }
  }

  bool get isRed => this == Suit.hearts || this == Suit.diamonds;
}

/// چهار خال واقعی بازی (بدون جوکر).
const List<Suit> kRealSuits = <Suit>[
  Suit.spades,
  Suit.hearts,
  Suit.clubs,
  Suit.diamonds,
];

/// رتبهٔ جوکر سیاه (بالاتر از آسِ حکم).
const int kBlackJokerRank = 15;

/// رتبهٔ جوکر قرمز (بالاترین کارت بازی).
const int kRedJokerRank = 16;

/// یک برگ پاسور. رتبه‌ها ۲ تا ۱۴ (۱۴ = آس) و ۱۵/۱۶ برای جوکرها هستند.
class PlayingCard implements Comparable<PlayingCard> {
  const PlayingCard(this.suit, this.rank);

  final Suit suit;
  final int rank;

  bool get isJoker => suit == Suit.joker;
  bool get isRedJoker => rank == kRedJokerRank;

  /// امتیاز خودِ برگ در شلم:
  /// آس و ۱۰ ← ۱۰ امتیاز، ۵ ← ۵ امتیاز، جوکر قرمز ۲۰ و جوکر سیاه ۱۵.
  int get points {
    if (isJoker) return isRedJoker ? 20 : 15;
    if (rank == 14 || rank == 10) return 10;
    if (rank == 5) return 5;
    return 0;
  }

  /// برچسب کوتاه انگلیسی روی کارت (A, K, Q, J, 10, …)
  String get label {
    if (isJoker) return isRedJoker ? 'JK' : 'jk';
    switch (rank) {
      case 14:
        return 'A';
      case 13:
        return 'K';
      case 12:
        return 'Q';
      case 11:
        return 'J';
      default:
        return '$rank';
    }
  }

  /// نام کامل فارسی کارت، برای صفحهٔ راهنما و دسترس‌پذیری.
  String get faName {
    if (isJoker) return isRedJoker ? 'جوکر قرمز' : 'جوکر سیاه';
    const Map<int, String> names = <int, String>{
      14: 'آس',
      13: 'شاه',
      12: 'بی‌بی',
      11: 'سرباز',
    };
    final String r = names[rank] ?? '$rank';
    return '$r ${suit.fa}';
  }

  String get id => '${suit.name}_$rank';

  @override
  int compareTo(PlayingCard other) {
    if (suit != other.suit) return suit.index.compareTo(other.suit.index);
    return rank.compareTo(other.rank);
  }

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => Object.hash(suit, rank);

  @override
  String toString() => id;

  Map<String, dynamic> toJson() => <String, dynamic>{'s': suit.index, 'r': rank};

  static PlayingCard fromJson(Map<String, dynamic> json) =>
      PlayingCard(Suit.values[json['s'] as int], json['r'] as int);
}

/// دستهٔ کارت استاندارد؛ با [withJokers] دو جوکر هم اضافه می‌شود (۵۴ برگ).
List<PlayingCard> buildDeck({bool withJokers = false}) {
  final List<PlayingCard> deck = <PlayingCard>[];
  for (final Suit s in kRealSuits) {
    for (int r = 2; r <= 14; r++) {
      deck.add(PlayingCard(s, r));
    }
  }
  if (withJokers) {
    deck.add(const PlayingCard(Suit.joker, kBlackJokerRank));
    deck.add(const PlayingCard(Suit.joker, kRedJokerRank));
  }
  return deck;
}

/// مجموع امتیاز کارت‌های یک فهرست.
int cardPointsOf(Iterable<PlayingCard> cards) =>
    cards.fold<int>(0, (int sum, PlayingCard c) => sum + c.points);
