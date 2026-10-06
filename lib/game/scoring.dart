/// امتیازدهی راند در بازی شلم (کاملاً خالص و تست‌پذیر).
library;

/// قانون «یاسا» — شرط منفیِ دوبرابر برای تیم حاکم.
enum YasaRule {
  /// بدون یاسا: شکست فقط منفیِ عددِ قرارداد دارد.
  off,

  /// اگر تیم حاکم از تیم مقابل هم کمتر بگیرد.
  lessThanOpponents,

  /// اگر تیم حاکم کمتر از نصف قراردادش بگیرد.
  lessThanHalfContract,
}

/// امتیاز تیم حاکم در صورت موفقیت.
enum HakemAward {
  /// فقط به اندازهٔ عددی که خوانده است.
  contract,

  /// به اندازهٔ تمام امتیازی که جمع کرده است.
  actualPoints,
}

/// پاداش «شلم» (گرفتن تمام دست‌ها توسط تیم حاکم).
enum SlamAward {
  /// دو برابر عددِ خوانده‌شده.
  doubleContract,

  /// عدد ثابت ۳۳۰ (دو برابر ۱۶۵).
  fixed330,
}

/// عددِ قرارداد برای «شلمِ اعلام‌شده».
const int kShelemBid = 330;

/// عددِ قرارداد برای «سرشلم / شلمِ بسته» (بدون استفاده از گلِ وسط).
const int kSarShelemBid = 660;

/// تنظیمات قانونیِ مؤثر بر امتیازدهی.
class ScoringRules {
  const ScoringRules({
    this.yasa = YasaRule.lessThanOpponents,
    this.hakemAward = HakemAward.contract,
    this.slamAward = SlamAward.doubleContract,
    this.opponentAlwaysScores = true,
  });

  final YasaRule yasa;
  final HakemAward hakemAward;
  final SlamAward slamAward;

  /// تیم مقابلِ حاکم همیشه امتیاز جمع‌کرده‌اش را می‌گیرد (قانون رایج).
  final bool opponentAlwaysScores;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'yasa': yasa.index,
        'award': hakemAward.index,
        'slam': slamAward.index,
        'oppScores': opponentAlwaysScores,
      };

  static ScoringRules fromJson(Map<String, dynamic> j) => ScoringRules(
        yasa: YasaRule.values[(j['yasa'] as int?) ?? 1],
        hakemAward: HakemAward.values[(j['award'] as int?) ?? 0],
        slamAward: SlamAward.values[(j['slam'] as int?) ?? 0],
        opponentAlwaysScores: (j['oppScores'] as bool?) ?? true,
      );
}

/// نتیجهٔ امتیازدهیِ یک راند.
class RoundOutcome {
  const RoundOutcome({
    required this.hakemTeam,
    required this.contract,
    required this.hakemPoints,
    required this.opponentPoints,
    required this.hakemDelta,
    required this.opponentDelta,
    required this.contractMade,
    required this.slam,
    required this.yasa,
  });

  final int hakemTeam;
  final int contract;
  final int hakemPoints;
  final int opponentPoints;

  /// تغییر امتیاز تیم حاکم در جدول.
  final int hakemDelta;

  /// تغییر امتیاز تیم مقابل در جدول.
  final int opponentDelta;

  final bool contractMade;

  /// تیم حاکم تمام دست‌ها را گرفت (شلم).
  final bool slam;

  /// تیم حاکم یاسا شد (منفیِ دوبرابر).
  final bool yasa;

  int get opponentTeam => 1 - hakemTeam;

  /// تغییر امتیاز برای تیم شمارهٔ [team].
  int deltaFor(int team) => team == hakemTeam ? hakemDelta : opponentDelta;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'ht': hakemTeam,
        'c': contract,
        'hp': hakemPoints,
        'op': opponentPoints,
        'hd': hakemDelta,
        'od': opponentDelta,
        'made': contractMade,
        'slam': slam,
        'yasa': yasa,
      };

  static RoundOutcome fromJson(Map<String, dynamic> j) => RoundOutcome(
        hakemTeam: j['ht'] as int,
        contract: j['c'] as int,
        hakemPoints: j['hp'] as int,
        opponentPoints: j['op'] as int,
        hakemDelta: j['hd'] as int,
        opponentDelta: j['od'] as int,
        contractMade: j['made'] as bool,
        slam: j['slam'] as bool,
        yasa: j['yasa'] as bool,
      );
}

/// محاسبهٔ امتیاز یک راند شلم.
///
/// [hakemPoints] و [opponentPoints] مجموع امتیاز جمع‌شدهٔ هر تیم است
/// (۵ امتیاز بابت هر دست + امتیاز برگ‌ها + برگ‌های کنارگذاشتهٔ حاکم).
/// [hakemWonAllTricks] یعنی تیم حاکم تمام دست‌های بازی را برده است.
RoundOutcome scoreRound({
  required int hakemTeam,
  required int contract,
  required int hakemPoints,
  required int opponentPoints,
  required bool hakemWonAllTricks,
  ScoringRules rules = const ScoringRules(),
}) {
  // ── شلم/سرشلمِ اعلام‌شده: فقط با گرفتن تمام دست‌ها موفق است ──────────
  if (contract == kShelemBid || contract == kSarShelemBid) {
    final bool made = hakemWonAllTricks;
    return RoundOutcome(
      hakemTeam: hakemTeam,
      contract: contract,
      hakemPoints: hakemPoints,
      opponentPoints: opponentPoints,
      hakemDelta: made ? contract : -contract,
      opponentDelta:
          made ? 0 : (rules.opponentAlwaysScores ? opponentPoints : 0),
      contractMade: made,
      slam: made,
      yasa: false,
    );
  }

  final bool made = hakemPoints >= contract;
  int hakemDelta;
  bool yasa = false;

  if (made) {
    if (hakemWonAllTricks) {
      hakemDelta = rules.slamAward == SlamAward.doubleContract
          ? contract * 2
          : 330;
    } else {
      hakemDelta = rules.hakemAward == HakemAward.contract
          ? contract
          : hakemPoints;
    }
  } else {
    switch (rules.yasa) {
      case YasaRule.off:
        yasa = false;
      case YasaRule.lessThanOpponents:
        yasa = hakemPoints < opponentPoints;
      case YasaRule.lessThanHalfContract:
        yasa = hakemPoints * 2 < contract;
    }
    hakemDelta = yasa ? -2 * contract : -contract;
  }

  final int opponentDelta =
      rules.opponentAlwaysScores ? opponentPoints : (made ? 0 : opponentPoints);

  return RoundOutcome(
    hakemTeam: hakemTeam,
    contract: contract,
    hakemPoints: hakemPoints,
    opponentPoints: opponentPoints,
    hakemDelta: hakemDelta,
    opponentDelta: opponentDelta,
    contractMade: made,
    slam: made && hakemWonAllTricks,
    yasa: yasa,
  );
}
