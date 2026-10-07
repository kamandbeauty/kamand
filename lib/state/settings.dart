/// تنظیمات کاربر + قوانین انتخابی بازی (ذخیره در حافظهٔ دستگاه).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/engine.dart';
import '../game/scoring.dart';
import '../model/enums.dart';

/// نام‌های قدیمیِ زمینِ بازی (نسخه‌های پیش از ۱.۴) به معادلِ تازه.
const Map<String, TableSurface> _legacySurfaces = <String, TableSurface>{
  'carpetRed': TableSurface.carpetAntique,
  'carpetBlue': TableSurface.carpetSilk,
  'carpetCream': TableSurface.carpetBoteh,
  'carpetGreen': TableSurface.carpetMiniature,
};

/// خواندنِ امنِ enum از تنظیماتِ ذخیره‌شده.
///
/// هم نامِ تازه (رشته) و هم شمارهٔ نسخه‌های قدیمی را می‌پذیرد و اگر مقدار
/// نامعتبر بود به پیش‌فرض برمی‌گردد (به‌جای خطا دادن و پاک شدنِ همهٔ تنظیمات).
T _parseEnum<T extends Enum>(
  List<T> values,
  Object? raw,
  T fallback, {
  Map<String, T> legacy = const <String, Never>{},
}) {
  if (raw is String) {
    for (final T v in values) {
      if (v.name == raw) return v;
    }
    final T? old = legacy[raw];
    if (old != null) return old;
    return fallback;
  }
  if (raw is int && raw >= 0 && raw < values.length) return values[raw];
  return fallback;
}

class AppSettings {
  AppSettings({
    this.playerName = 'شما',
    this.difficulty = Difficulty.hard,
    this.speed = GameSpeed.normal,
    this.surface = TableSurface.teahouse,
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
        'difficulty': difficulty.name,
        'speed': speed.name,
        'surface': surface.name,
        'back': cardBack.name,
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
        difficulty: _parseEnum(
          Difficulty.values,
          j['difficulty'],
          Difficulty.hard,
        ),
        speed: _parseEnum(GameSpeed.values, j['speed'], GameSpeed.normal),
        surface: _parseEnum(
          TableSurface.values,
          j['surface'],
          TableSurface.teahouse,
          legacy: _legacySurfaces,
        ),
        cardBack: _parseEnum(CardBack.values, j['back'], CardBack.crimson),
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
