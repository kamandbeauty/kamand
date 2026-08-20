import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game_engine/state/game_enums.dart';
import 'settings_model.dart';

/// مخزن تنظیمات — ماندگاری با SharedPreferences و اطلاع‌رسانی با
/// ChangeNotifier تا UI بلافاصله واکنش نشان دهد.
class SettingsController extends ChangeNotifier {
  SettingsController._(this._prefs, this._model);

  static const String _key = 'hokm_settings_v1';

  final SharedPreferences _prefs;
  SettingsModel _model;

  SettingsModel get model => _model;

  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    SettingsModel model = const SettingsModel();
    if (raw != null) {
      try {
        model = SettingsModel.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } on FormatException {
        // خرابی دادهٔ ذخیره‌شده نباید اجرای برنامه را متوقف کند.
        model = const SettingsModel();
      }
    }
    return SettingsController._(prefs, model);
  }

  Future<void> _save() async {
    await _prefs.setString(_key, jsonEncode(_model.toJson()));
  }

  Future<void> setSoundOn(bool value) =>
      _update(_model.copyWith(soundOn: value));
  Future<void> setMusicOn(bool value) =>
      _update(_model.copyWith(musicOn: value));
  Future<void> setAnimationSpeed(AnimationSpeed value) =>
      _update(_model.copyWith(animationSpeed: value));
  Future<void> setAiDifficulty(AiDifficulty value) =>
      _update(_model.copyWith(aiDifficulty: value));
  Future<void> setCardBack(CardBackStyle value) =>
      _update(_model.copyWith(cardBack: value));
  Future<void> setTableTheme(TableTheme value) =>
      _update(_model.copyWith(tableTheme: value));

  Future<void> _update(SettingsModel next) async {
    _model = next;
    notifyListeners();
    await _save();
  }
}
