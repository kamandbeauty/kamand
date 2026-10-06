import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelem/game/scoring.dart';
import 'package:shelem/model/enums.dart';
import 'package:shelem/state/settings.dart';
import 'package:shelem/util/persian.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('ذخیره و بازخوانی تنظیمات', () async {
    final AppSettings s = AppSettings()
      ..playerName = 'کامند'
      ..difficulty = Difficulty.master
      ..surface = TableSurface.woodTable
      ..cardBack = CardBack.emerald
      ..declareTrumpWithPicker = true;
    s.rules = s.rulesWith(
      withJokers: true,
      targetScore: 1200,
      yasa: YasaRule.lessThanHalfContract,
    );
    await s.save();

    final AppSettings back = await AppSettings.load();
    expect(back.playerName, 'کامند');
    expect(back.difficulty, Difficulty.master);
    expect(back.surface, TableSurface.woodTable);
    expect(back.cardBack, CardBack.emerald);
    expect(back.declareTrumpWithPicker, isTrue);
    expect(back.rules.withJokers, isTrue);
    expect(back.rules.kittySize, 6);
    expect(back.rules.targetScore, 1200);
    expect(back.rules.scoring.yasa, YasaRule.lessThanHalfContract);
  });

  test('تنظیمات پیش‌فرض بدون داده ذخیره‌شده', () async {
    final AppSettings s = await AppSettings.load();
    expect(s.difficulty, Difficulty.hard);
    expect(s.rules.withJokers, isFalse);
    expect(s.rules.totalPoints, 165);
  });

  test('copy یک نسخهٔ مستقل می‌سازد', () {
    final AppSettings a = AppSettings();
    final AppSettings b = a.copy()..playerName = 'دیگری';
    expect(a.playerName, isNot(b.playerName));
  });

  test('تبدیل رقم‌های فارسی', () {
    expect(fa(1165), '۱۱۶۵');
    expect(fa(0), '۰');
    expect(faSigned(-120), '−۱۲۰');
    expect(faSigned(95), '+۹۵');
  });

  test('سطح‌های سختی ویژگی‌های متفاوت دارند', () {
    expect(Difficulty.easy.noise > Difficulty.master.noise, isTrue);
    expect(Difficulty.master.countsCards, isTrue);
    expect(Difficulty.easy.countsCards, isFalse);
    for (final Difficulty d in Difficulty.values) {
      expect(d.fa.isNotEmpty, isTrue);
      expect(d.description.isNotEmpty, isTrue);
    }
    for (final TableSurface t in TableSurface.values) {
      expect(t.fa.isNotEmpty, isTrue);
    }
  });
}
