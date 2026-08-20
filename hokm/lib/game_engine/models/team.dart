/// تیم دونفرهٔ حکم.
class Team {
  Team({
    required this.index,
    required this.playerIds,
    this.matchScore = 0,
  });

  /// صفر یا یک.
  final int index;

  /// شناسهٔ دو بازیکن تیم.
  final List<String> playerIds;

  /// امتیاز مسابقه (نه امتیاز دست).
  int matchScore;

  Map<String, dynamic> toJson() => {
        'index': index,
        'playerIds': playerIds,
        'matchScore': matchScore,
      };

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        index: json['index'] as int,
        playerIds: List<String>.from(json['playerIds'] as List<dynamic>),
        matchScore: json['matchScore'] as int,
      );

  @override
  String toString() => 'Team($index, score=$matchScore)';
}
