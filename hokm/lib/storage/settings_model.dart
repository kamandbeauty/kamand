import '../game_engine/state/game_enums.dart';

/// سرعت انیمیشن — ضربه‌ای بر مدت‌زمان پایه.
enum AnimationSpeed {
  slow(1.35),
  normal(1.0),
  fast(0.65);

  const AnimationSpeed(this.multiplier);

  /// ضریب زمان: مقادیر بزرگ‌تر = کندتر.
  final double multiplier;

  static AnimationSpeed fromIndex(int i) =>
      AnimationSpeed.values[i.clamp(0, AnimationSpeed.values.length - 1).toInt()];
}

/// طرح‌های پشت کارت (رندر رویه‌ای — بدون نیاز به فایل تصویری).
enum CardBackStyle {
  classic, // شبکهٔ لوزی سنتی
  persianTile, // موتیف کاشی
  diagonal; // خطوط موریانه

  static CardBackStyle fromIndex(int i) =>
      CardBackStyle.values[i.clamp(0, CardBackStyle.values.length - 1).toInt()];
}

/// تم‌های میز.
enum TableTheme {
  classicGreen,
  midnightBlue,
  royalRed;

  static TableTheme fromIndex(int i) =>
      TableTheme.values[i.clamp(0, TableTheme.values.length - 1).toInt()];
}

/// مدل تغییرناپذیر تنظیمات.
class SettingsModel {
  const SettingsModel({
    this.soundOn = true,
    this.musicOn = true,
    this.animationSpeed = AnimationSpeed.normal,
    this.aiDifficulty = AiDifficulty.normal,
    this.cardBack = CardBackStyle.persianTile,
    this.tableTheme = TableTheme.classicGreen,
  });

  final bool soundOn;
  final bool musicOn;
  final AnimationSpeed animationSpeed;
  final AiDifficulty aiDifficulty;
  final CardBackStyle cardBack;
  final TableTheme tableTheme;

  SettingsModel copyWith({
    bool? soundOn,
    bool? musicOn,
    AnimationSpeed? animationSpeed,
    AiDifficulty? aiDifficulty,
    CardBackStyle? cardBack,
    TableTheme? tableTheme,
  }) =>
      SettingsModel(
        soundOn: soundOn ?? this.soundOn,
        musicOn: musicOn ?? this.musicOn,
        animationSpeed: animationSpeed ?? this.animationSpeed,
        aiDifficulty: aiDifficulty ?? this.aiDifficulty,
        cardBack: cardBack ?? this.cardBack,
        tableTheme: tableTheme ?? this.tableTheme,
      );

  Map<String, dynamic> toJson() => {
        'soundOn': soundOn,
        'musicOn': musicOn,
        'animationSpeed': animationSpeed.index,
        'aiDifficulty': aiDifficulty.index,
        'cardBack': cardBack.index,
        'tableTheme': tableTheme.index,
      };

  factory SettingsModel.fromJson(Map<String, dynamic> json) => SettingsModel(
        soundOn: json['soundOn'] as bool? ?? true,
        musicOn: json['musicOn'] as bool? ?? true,
        animationSpeed: json['animationSpeed'] == null
            ? AnimationSpeed.normal
            : AnimationSpeed.fromIndex(json['animationSpeed'] as int),
        aiDifficulty: json['aiDifficulty'] == null
            ? AiDifficulty.normal
            : AiDifficulty
                .values[(json['aiDifficulty'] as int).clamp(0, 2).toInt()],
        cardBack: json['cardBack'] == null
            ? CardBackStyle.persianTile
            : CardBackStyle.fromIndex(json['cardBack'] as int),
        tableTheme: json['tableTheme'] == null
            ? TableTheme.classicGreen
            : TableTheme.fromIndex(json['tableTheme'] as int),
      );
}
