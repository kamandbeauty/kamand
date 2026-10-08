import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taalebin/core/theme/app_theme.dart';
import 'package:taalebin/data/settings/settings_service.dart';

/// Theme system: five dark skins + the SkyPalette extension that
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
      // Distinct skins → distinct backgrounds.
      expect(backgrounds.length, AppThemeSkin.values.length);
    });

    test('velvet (the main skin) matches the design reference', () {
      final theme = AppTheme.themeFor(AppThemeSkin.velvet);
      final palette = theme.extension<SkyPalette>()!;
      // Midnight-indigo base, warm moonlit-cream text, gold accent.
      expect(theme.scaffoldBackgroundColor, const Color(0x0014122B));
      expect(theme.colorScheme.onSurface, const Color(0xFFD6D1CE));
      expect(palette.starGold, const Color(0x99E0B060));
      // The velvet-only backdrop: generated artwork, borderless UI.
      expect(palette.backgroundAsset, 'assets/theme/velvet_night.webp');
      // Other skins must not inherit the artwork.
      final midnight = AppTheme.themeFor(AppThemeSkin.midnight);
      expect(midnight.extension<SkyPalette>()!.backgroundAsset, isNull);
      // Velvet must lead the picker (asserted so a future enum reorder
      // can't silently demote the app's main look).
      expect(AppTheme.skinPickerOrder.first, AppThemeSkin.velvet);
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
      expect(AppThemeSkin.values.length, 5);
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
      // Since v1.9.0 the main skin («شبِ مخملی») is the fallback for
      // anyone who never explicitly picked one.
      expect(loaded.themeSkin, AppThemeSkin.velvet);

      await service.save(loaded.copyWith(themeSkin: AppThemeSkin.aurora));
      final reloaded = await service.load();
      expect(reloaded.themeSkin, AppThemeSkin.aurora);
      expect(reloaded.themeMode, loaded.themeMode); // untouched
    });

    test('fresh install without any keys: dark mode + velvet main skin',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = SharedPreferencesSettingsService(
        await SharedPreferences.getInstance(),
      );
      final s = await service.load();
      expect(s.themeMode, ThemeModeSetting.dark);
      expect(s.themeSkin, AppThemeSkin.velvet);
    });

    test('an explicit skin pick survives the new default (no demotion)',
        () async {
      SharedPreferences.setMockInitialValues({
        'themeSkin': AppThemeSkin.ocean.index,
      });
      final service = SharedPreferencesSettingsService(
        await SharedPreferences.getInstance(),
      );
      final s = await service.load();
      expect(s.themeSkin, AppThemeSkin.ocean);
    });
  });
}
