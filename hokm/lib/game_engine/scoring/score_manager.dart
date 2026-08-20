import '../models/team.dart';

/// نتیجهٔ یک دست (راند).
class RoundResult {
  const RoundResult({
    required this.winnerTeamIndex,
    required this.winnerTricks,
    required this.loserTricks,
    required this.pointsAwarded,
    required this.isKoot,
    required this.isHakimKoot,
  });

  final int winnerTeamIndex;
  final int winnerTricks;
  final int loserTricks;

  /// امتیاز مسابقهٔ اعمال‌شده (۱ معمولی، ۲ کوت، ۳ حاکم‌کوت).
  final int pointsAwarded;
  final bool isKoot;
  final bool isHakimKoot;

  Map<String, dynamic> toJson() => {
        'winnerTeamIndex': winnerTeamIndex,
        'winnerTricks': winnerTricks,
        'loserTricks': loserTricks,
        'pointsAwarded': pointsAwarded,
        'isKoot': isKoot,
        'isHakimKoot': isHakimKoot,
      };

  factory RoundResult.fromJson(Map<String, dynamic> json) => RoundResult(
        winnerTeamIndex: json['winnerTeamIndex'] as int,
        winnerTricks: json['winnerTricks'] as int,
        loserTricks: json['loserTricks'] as int,
        pointsAwarded: json['pointsAwarded'] as int,
        isKoot: json['isKoot'] as bool,
        isHakimKoot: json['isHakimKoot'] as bool,
      );
}

/// رکورد یک دستِ بازی‌شده در تاریخچهٔ مسابقه — از دید تیم انسان،
/// برای نمایش در «جدول امتیازات» پایان هر دست.
class RoundRecord {
  const RoundRecord({
    required this.roundNumber,
    required this.tricksUs,
    required this.tricksThem,
    required this.totalUs,
    required this.totalThem,
    required this.winnerIsUs,
    required this.pointsAwarded,
    required this.isKoot,
    required this.isHakimKoot,
  });

  /// شمارهٔ دست (از ۱).
  final int roundNumber;

  /// دورهای برده‌شده در این دست — هر دو طرف (مجموعاً ۱۳).
  final int tricksUs;
  final int tricksThem;

  /// مجموع امتیاز مسابقه پس از این دست.
  final int totalUs;
  final int totalThem;

  /// آیا تیم انسان این دست را برد؟
  final bool winnerIsUs;

  /// امتیاز این دست (۱ / ۲ کوت / ۳ حاکم‌کوت).
  final int pointsAwarded;
  final bool isKoot;
  final bool isHakimKoot;

  /// برچسب قانون ویژهٔ این دست (برای ستون «قانون»).
  String get ruleLabel =>
      isHakimKoot ? 'حاکم‌کوت' : (isKoot ? 'کوت' : '—');
}

/// مدیر امتیاز — منطق امتیازدهی استاندارد حکم:
///
/// * برندهٔ دست = اولین تیمی که ۷ دور را ببرد → ۱ امتیاز.
/// * برد ۷ بر ۰ = «کوت» → ۲ امتیاز.
/// * برد ۷ بر ۰ توسط تیمی که حاکم ندارد = «حاکم‌کوت» → ۳ امتیاز.
/// * مسابقه تا رسیدن به [matchTarget] (پیش‌فرض ۷) ادامه دارد.
class ScoreManager {
  const ScoreManager({this.matchTarget = defaultMatchTarget});

  /// سقف پیش‌فرض امتیاز مسابقه.
  static const int defaultMatchTarget = 7;

  /// سقف امتیاز مسابقه — قابل تنظیم.
  final int matchTarget;

  static const int tricksToWinRound = 7;

  /// محاسبهٔ نتیجهٔ دست از روی تعداد دورهای برده‌شده.
  ///
  /// حاکم در [hakimTeamIndex] است (برای تشخیص حاکم‌کوت لازم است).
  RoundResult settleRound({
    required int tricksTeam0,
    required int tricksTeam1,
    required int hakimTeamIndex,
  }) {
    assert(tricksTeam0 + tricksTeam1 == 13);
    final winner = tricksTeam0 >= tricksToWinRound ? 0 : 1;
    final winnerTricks = winner == 0 ? tricksTeam0 : tricksTeam1;
    final loserTricks = winner == 0 ? tricksTeam1 : tricksTeam0;
    assert(winnerTricks >= tricksToWinRound);

    final isKoot = loserTricks == 0;
    final isHakimKoot = isKoot && winner != hakimTeamIndex;
    final points = isHakimKoot ? 3 : (isKoot ? 2 : 1);

    return RoundResult(
      winnerTeamIndex: winner,
      winnerTricks: winnerTricks,
      loserTricks: loserTricks,
      pointsAwarded: points,
      isKoot: isKoot,
      isHakimKoot: isHakimKoot,
    );
  }

  /// اعمال نتیجه روی تیم‌ها؛ برمی‌گرداند آیا مسابقه تمام شده.
  bool applyAndCheckMatchEnd(RoundResult result, List<Team> teams) {
    teams[result.winnerTeamIndex].matchScore += result.pointsAwarded;
    return isMatchOver(teams);
  }

  bool isMatchOver(List<Team> teams) =>
      teams.any((t) => t.matchScore >= matchTarget);

  /// تیم برندهٔ مسابقه (null اگر مسابقه ادامه دارد).
  int? matchWinnerIndex(List<Team> teams) {
    if (!isMatchOver(teams)) return null;
    return teams[0].matchScore >= matchTarget ? 0 : 1;
  }
}
