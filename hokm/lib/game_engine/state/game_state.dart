import '../models/player.dart';
import '../models/playing_card.dart';
import '../models/suit.dart';
import '../models/team.dart';
import '../models/trick.dart';
import 'game_enums.dart';

/// وضعیت کامل و سریالایزپذیر یک مسابقهٔ حکم.
///
/// این کلاس «تنها منبع حقیقت» موتور است — کل UI و AI از روی
/// مشتقات آن کار می‌کنند. هیچ ارجاعی به Flutter/Flame ندارد.
class GameState {
  GameState({
    required this.players,
    required this.teams,
    required this.phase,
    required this.currentTurn,
    this.hakim,
    this.trump,
    this.currentTrick,
    List<int>? tricksWon,
    List<Trick>? trickHistory,
    this.roundNumber = 1,
    this.matchTarget = 7,
  })  : tricksWon = tricksWon ?? <int>[0, 0],
        trickHistory = trickHistory ?? <Trick>[];

  /// چهار بازیکن به ترتیب جایگاه (index = seat.index).
  final List<Player> players;

  /// دو تیم.
  final List<Team> teams;

  /// مرحلهٔ فعلی مسابقه.
  GamePhase phase;

  /// نوبت فعلی.
  Seat currentTurn;

  /// حاکم فعلی (ممکن است هنوز تعیین نشده باشد).
  Seat? hakim;

  /// خال حکم این دست (null تا پیش از اعلام).
  Suit? trump;

  /// دورِ در حال انجام (null خارج از فاز playing).
  Trick? currentTrick;

  /// تعداد دورهای برده‌شدهٔ هر تیم در این دست.
  final List<int> tricksWon;

  /// دورهای کامل‌شدهٔ این دست، به ترتیب انجام — برای حافظهٔ AI و بازپخش.
  final List<Trick> trickHistory;

  int roundNumber;

  /// سقف امتیاز مسابقه.
  final int matchTarget;

  // ---------- مشتقات راحت ----------

  Player playerAt(Seat seat) => players[seat.index];

  Player get currentPlayer => players[currentTurn.index];

  /// ایندکس تیمِ جایگاه داده‌شده (۰ یا ۱).
  Team teamOf(Seat seat) => teams[seat.teamIndex];

  bool isHumanTurn() => players[currentTurn.index].isHuman;

  /// تعداد دورهای برده‌شدهٔ تیمِ [seat] در این دست.
  int tricksWonByTeamOf(Seat seat) => tricksWon[seat.teamIndex];

  int get roundTricksPlayed => trickHistory.length;

  /// کارت‌هایی که تا این لحظه در این دست بازی شده‌اند (به ترتیب).
  List<PlayedCard> get allPlaysThisRound => <PlayedCard>[
        for (final trick in trickHistory) ...trick.cards,
        if (currentTrick != null) ...currentTrick!.cards,
      ];

  List<PlayingCard> get playedCards =>
      allPlaysThisRound.map((p) => p.card).toList();

  /// آیا این دست تمام شده؟
  bool get isRoundComplete => roundTricksPlayed >= 13;

  // ---------- سریالایز ----------

  Map<String, dynamic> toJson() => {
        'version': 1,
        'players': players.map((p) => p.toJson()).toList(),
        'teams': teams.map((t) => t.toJson()).toList(),
        'phase': phase.index,
        'currentTurn': currentTurn.index,
        'hakim': hakim?.index,
        'trump': trump?.code,
        'currentTrick': currentTrick?.toJson(),
        'tricksWon': tricksWon,
        'trickHistory': trickHistory.map((t) => t.toJson()).toList(),
        'roundNumber': roundNumber,
        'matchTarget': matchTarget,
      };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
        players: (json['players'] as List<dynamic>)
            .map((p) => Player.fromJson(p as Map<String, dynamic>))
            .toList(),
        teams: (json['teams'] as List<dynamic>)
            .map((t) => Team.fromJson(t as Map<String, dynamic>))
            .toList(),
        phase: GamePhase.values[json['phase'] as int],
        currentTurn: Seat.fromIndex(json['currentTurn'] as int),
        hakim: json['hakim'] == null
            ? null
            : Seat.fromIndex(json['hakim'] as int),
        trump: json['trump'] == null
            ? null
            : Suit.fromCode(json['trump'] as String),
        currentTrick: json['currentTrick'] == null
            ? null
            : Trick.fromJson(json['currentTrick'] as Map<String, dynamic>),
        tricksWon: List<int>.from(json['tricksWon'] as List<dynamic>),
        trickHistory: (json['trickHistory'] as List<dynamic>)
            .map((t) => Trick.fromJson(t as Map<String, dynamic>))
            .toList(),
        roundNumber: json['roundNumber'] as int,
        matchTarget: json['matchTarget'] as int,
      );

  GameState clone() => GameState.fromJson(toJson());
}
