/// تنظیمات کاربر + قوانین انتخابی بازی (ذخیره در حافظهٔ دستگاه).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/engine.dart';
import '../game/scoring.dart';
import '../model/enums.dart';

class AppSettings {
  AppSettings({
    this.playerName = 'شما',
    this.difficulty = Difficulty.hard,
    this.speed = GameSpeed.normal,
    this.surface = TableSurface.carpetRed,
    this.cardBack = CardBack.crimson,
    this.sound = true,
    this.haptics = true,
    this.highlightLegal = true,
    this.sortHand = true,
    this.showBotHands = false,
    this.declareTrumpWithPicker = false,
    GameConfig? rules,
  }) : rules = rules ?? const GameConfig();

  String playerName;
  Difficulty difficulty;
  GameSpeed speed;
  TableSurface surface;
  CardBack cardBack;
  bool sound;
  bool haptics;
  bool highlightLegal;
  bool sortHand;

  /// حالت تمرین: کارت‌های ربات‌ها دیده می‌شود.
  bool showBotHands;

  /// اعلام حکم از طریق منو به‌جای «اولین برگ، حکم را تعیین می‌کند».
  bool declareTrumpWithPicker;

  GameConfig rules;

  static const String _key = 'shelem_settings_v1';

  AppSettings copy() => AppSettings(
        playerName: playerName,
        difficulty: difficulty,
        speed: speed,
        surface: surface,
        cardBack: cardBack,
        sound: sound,
        haptics: haptics,
        highlightLegal: highlightLegal,
        sortHand: sortHand,
        showBotHands: showBotHands,
        declareTrumpWithPicker: declareTrumpWithPicker,
        rules: rules,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': playerName,
        'difficulty': difficulty.index,
        'speed': speed.index,
        'surface': surface.index,
        'back': cardBack.index,
        'sound': sound,
        'haptics': haptics,
        'highlight': highlightLegal,
        'sort': sortHand,
        'showBots': showBotHands,
        'picker': declareTrumpWithPicker,
        'rules': rules.toJson(),
      };

  static AppSettings fromJson(Map<String, dynamic> j) => AppSettings(
        playerName: (j['name'] as String?) ?? 'شما',
        difficulty: Difficulty.values[(j['difficulty'] as int?) ?? 2],
        speed: GameSpeed.values[(j['speed'] as int?) ?? 1],
        surface: TableSurface.values[(j['surface'] as int?) ?? 0],
        cardBack: CardBack.values[(j['back'] as int?) ?? 0],
        sound: (j['sound'] as bool?) ?? true,
        haptics: (j['haptics'] as bool?) ?? true,
        highlightLegal: (j['highlight'] as bool?) ?? true,
        sortHand: (j['sort'] as bool?) ?? true,
        showBotHands: (j['showBots'] as bool?) ?? false,
        declareTrumpWithPicker: (j['picker'] as bool?) ?? false,
        rules: GameConfig.fromJson(
          Map<String, dynamic>.from(
            (j['rules'] as Map?) ?? const <String, dynamic>{},
          ),
        ),
      );

  static Future<AppSettings> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_key);
      if (raw == null) return AppSettings();
      return AppSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> save() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(toJson()));
    } catch (_) {
      // ذخیره‌سازی اختیاری است؛ خطا نباید بازی را متوقف کند.
    }
  }

  /// ساخت تنظیمات قانونی جدید با تغییر یک گزینه.
  GameConfig rulesWith({
    int? players,
    bool? withJokers,
    bool? allowShelemBid,
    bool? allowSarShelemBid,
    bool? forceDealerBidOnAllPass,
    int? targetScore,
    YasaRule? yasa,
    HakemAward? hakemAward,
    SlamAward? slamAward,
    bool? opponentAlwaysScores,
  }) =>
      GameConfig(
        players: players ?? rules.players,
        withJokers: withJokers ?? rules.withJokers,
        allowShelemBid: allowShelemBid ?? rules.allowShelemBid,
        allowSarShelemBid: allowSarShelemBid ?? rules.allowSarShelemBid,
        forceDealerBidOnAllPass:
            forceDealerBidOnAllPass ?? rules.forceDealerBidOnAllPass,
        targetScore: targetScore ?? rules.targetScore,
        scoring: ScoringRules(
          yasa: yasa ?? rules.scoring.yasa,
          hakemAward: hakemAward ?? rules.scoring.hakemAward,
          slamAward: slamAward ?? rules.scoring.slamAward,
          opponentAlwaysScores:
              opponentAlwaysScores ?? rules.scoring.opponentAlwaysScores,
        ),
      );
}
