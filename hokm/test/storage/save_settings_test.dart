import 'package:flutter_test/flutter_test.dart';
import 'package:hokm/game_engine/state/game_enums.dart';
import 'package:hokm/storage/settings_model.dart';

void main() {
  group('SettingsModel', () {
    test('defaults are sensible', () {
      const m = SettingsModel();
      expect(m.soundOn, isTrue);
      expect(m.musicOn, isTrue);
      expect(m.animationSpeed, AnimationSpeed.normal);
      expect(m.aiDifficulty, AiDifficulty.normal);
    });

    test('json round-trip', () {
      const m = SettingsModel(
        soundOn: false,
        musicOn: false,
        animationSpeed: AnimationSpeed.fast,
        aiDifficulty: AiDifficulty.hard,
        cardBack: CardBackStyle.diagonal,
        tableTheme: TableTheme.midnightBlue,
      );
      final restored = SettingsModel.fromJson(m.toJson());
      expect(restored.soundOn, isFalse);
      expect(restored.musicOn, isFalse);
      expect(restored.animationSpeed, AnimationSpeed.fast);
      expect(restored.aiDifficulty, AiDifficulty.hard);
      expect(restored.cardBack, CardBackStyle.diagonal);
      expect(restored.tableTheme, TableTheme.midnightBlue);
    });

    test('robust against missing keys and out-of-range indexes', () {
      final m = SettingsModel.fromJson(const {
        'aiDifficulty': 99,
        'animationSpeed': -4,
      });
      expect(m.aiDifficulty, AiDifficulty.values.last);
      expect(m.animationSpeed, AnimationSpeed.slow);
      expect(m.soundOn, isTrue);
    });
  });
}
