import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game_engine/state/game_enums.dart';
import '../game_engine/state/game_state.dart';

/// دادهٔ ذخیره‌شدهٔ یک مسابقهٔ نیمه‌تمام.
class SavedMatch {
  const SavedMatch({
    required this.state,
    required this.difficulty,
    required this.savedAtMillis,
    required this.humanSeat,
  });

  final GameState state;
  final AiDifficulty difficulty;
  final int savedAtMillis;
  final Seat humanSeat;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'state': state.toJson(),
        'difficulty': difficulty.index,
        'savedAt': savedAtMillis,
        'humanSeat': humanSeat.index,
      };

  factory SavedMatch.fromJson(Map<String, dynamic> json) => SavedMatch(
        state: GameState.fromJson(json['state'] as Map<String, dynamic>),
        difficulty: AiDifficulty
            .values[(json['difficulty'] as int).clamp(0, 2).toInt()],
        savedAtMillis: json['savedAt'] as int,
        humanSeat: Seat.fromIndex(json['humanSeat'] as int? ?? 0),
      );
}

/// مدیریت ذخیره و بازیابی مسابقهٔ در حال انجام.
///
/// ذخیره در مرزهای پایدار جریان بازی انجام می‌شود (پایان هر عمل)،
/// نه وسط انیمیشن — تا بازیابی همیشه به وضعیت سازگار برسد.
class SaveManager {
  SaveManager._(this._prefs);

  static const String _key = 'hokm_match_save_v1';

  final SharedPreferences _prefs;

  static Future<SaveManager> load() async =>
      SaveManager._(await SharedPreferences.getInstance());

  bool get hasSave => _prefs.containsKey(_key);

  Future<void> saveMatch(SavedMatch match) async {
    await _prefs.setString(_key, jsonEncode(match.toJson()));
  }

  SavedMatch? loadMatch() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return SavedMatch.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    } on Object {
      // ناسازگاری نسخهٔ ذخیره → بی‌خطر نادیده بگیر.
      return null;
    }
  }

  Future<void> clear() async => _prefs.remove(_key);
}
