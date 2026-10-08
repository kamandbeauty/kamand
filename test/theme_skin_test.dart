import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taalebin/core/theme/app_theme.dart';
import 'package:taalebin/data/settings/settings_service.dart';

/// Round-14 theme system: four dark skins + the SkyPalette extension that
/// drives the ambient background, plus persistence/migration of the pick.
void main() {
  group('AppTheme skins', () {
    test('every skin builds a dark theme with its own palette', () {
      final backgrounds = <Color>{};
      for (final skin in AppThemeSkin.values) {
        final theme = AppTheme.themeFor(skin);
        expect(theme.brightness, Brightness.dark);
        backgrounds.add(theme.scaffoldBackgroundColor);
        final palette = theme.extension<SkyPalette>();
        expect(palette, isNotNull, reason: skin.name);
        expect(palette!.star.alpha, greaterThan(0));
        expect(palette.nebulaA.alpha, lessThanOrEqualTo(0x14)); // soft
      }
      // Four distinct skins → four distinct backgrounds.
      expect(backgrounds.length, AppThemeSkin.values.length);
    });

    test('light theme carries a dawn palette too', () {
      final palette = AppTheme.lightTheme.extension<SkyPalette>();
      expect(palette, isNotNull);
      expect(AppTheme.lightTheme.brightness, Brightness.light);
    });

    test('skin metadata is complete (label, description, swatch)', () {
      for (final skin in AppThemeSkin.values) {
        expect(skin.labelFa, isNotEmpty);
        expect(skin.descriptionFa, isNotEmpty);
        expect(skin.swatch.length, 3);
        expect(skin.swatch[2].alpha, 255);
      }
      expect(AppThemeSkin.values.length, 4);
    });

    test('SkyPalette lerp blends between skins', () {
      final a = AppTheme.themeFor(AppThemeSkin.midnight).extension<SkyPalette>()!;
      final b = AppTheme.themeFor(AppThemeSkin.aurora).extension<SkyPalette>()!;
      final mid = a.lerp(b, 0.5);
      expect(mid.nebulaA, Color.lerp(a.nebulaA, b.nebulaA, 0.5));
      final copied = a.copyWith(star: b.star);
      expect(copied.star, b.star);
      expect(copied.nebulaB, a.nebulaB);
    });

    test('legacy darkTheme equals the midnight skin', () {
      expect(
        AppTheme.darkTheme.scaffoldBackgroundColor,
        AppTheme.themeFor(AppThemeSkin.midnight).scaffoldBackgroundColor,
      );
      expect(AppTheme.darkBackground, AppTheme.darkTheme.scaffoldBackgroundColor);
    });
  });

  group('Settings persistence', () {
    test('themeSkin round-trips through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SharedPreferencesSettingsService(
        await SharedPreferences.getInstance(),
      );
      final loaded = await service.load();
      expect(loaded.themeSkin, AppThemeSkin.midnight); // migration default

      await service.save(loaded.copyWith(themeSkin: AppThemeSkin.aurora));
      final reloaded = await service.load();
      expect(reloaded.themeSkin, AppThemeSkin.aurora);
      expect(reloaded.themeMode, loaded.themeMode); // untouched
    });

    test('fresh install without any keys defaults to midnight dark',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = SharedPreferencesSettingsService(
        await SharedPreferences.getInstance(),
      );
      final s = await service.load();
      expect(s.themeMode, ThemeModeSetting.dark);
      expect(s.themeSkin, AppThemeSkin.midnight);
    });
  });
}
