import 'package:flutter/material.dart';

import '../../audio/sound_manager.dart';
import '../../core/app_strings.dart';
import '../../core/app_theme.dart';
import '../../game_engine/state/game_enums.dart';
import '../../storage/save_manager.dart';
import '../../storage/settings_model.dart';
import '../../storage/settings_repository.dart';
import 'widgets/card_back_preview.dart';

/// صفحهٔ تنظیمات.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.saveManager,
  });

  final SettingsController settings;
  final SaveManager saveManager;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          final model = settings.model;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // --- صدا و موسیقی ---
              _SectionHeader(title: 'صدا'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.volume_up_rounded),
                      title: const Text(AppStrings.sound),
                      value: model.soundOn,
                      onChanged: (v) {
                        settings.setSoundOn(v);
                        SoundManager.instance.enabled = v;
                        if (v) SoundManager.instance.button();
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: const Icon(Icons.music_note_rounded),
                      title: const Text(AppStrings.music),
                      value: model.musicOn,
                      onChanged: (v) {
                        settings.setMusicOn(v);
                        SoundManager.instance.musicOn = v;
                        SoundManager.instance.syncMusic();
                      },
                    ),
                  ],
                ),
              ),

              // --- بازی ---
              _SectionHeader(title: 'بازی'),
              Card(
                child: Column(
                  children: [
                    _OptionTile<AnimationSpeed>(
                      icon: Icons.speed_rounded,
                      title: AppStrings.animationSpeed,
                      options: const [
                        (AnimationSpeed.slow, AppStrings.speedSlow),
                        (AnimationSpeed.normal, AppStrings.speedNormal),
                        (AnimationSpeed.fast, AppStrings.speedFast),
                      ],
                      current: model.animationSpeed,
                      onChanged: settings.setAnimationSpeed,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _OptionTile<AiDifficulty>(
                      icon: Icons.psychology_rounded,
                      title: AppStrings.aiLevel,
                      options: const [
                        (AiDifficulty.easy, AppStrings.aiEasy),
                        (AiDifficulty.normal, AppStrings.aiNormal),
                        (AiDifficulty.hard, AppStrings.aiHard),
                      ],
                      current: model.aiDifficulty,
                      onChanged: (v) {
                        settings.setAiDifficulty(v);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('از مسابقهٔ بعدی اعمال می‌شود'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // --- ظاهر ---
              _SectionHeader(title: 'ظاهر'),
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Row(
                        children: [
                          Icon(Icons.style_rounded, size: 20),
                          SizedBox(width: 10),
                          Text(AppStrings.cardBack),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (var i = 0; i < CardBackStyle.values.length; i++)
                            CardBackPreview(
                              style: CardBackStyle.values[i],
                              selected: model.cardBack ==
                                  CardBackStyle.values[i],
                              onTap: () {
                                SoundManager.instance.button();
                                settings.setCardBack(CardBackStyle.values[i]);
                              },
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _OptionTile<TableTheme>(
                      icon: Icons.table_restaurant_rounded,
                      title: AppStrings.tableTheme,
                      options: const [
                        (TableTheme.classicGreen, 'سبز کلاسیک'),
                        (TableTheme.midnightBlue, 'آبی شب'),
                        (TableTheme.royalRed, 'قرمز سلطنتی'),
                      ],
                      current: model.tableTheme,
                      onChanged: settings.setTableTheme,
                    ),
                  ],
                ),
              ),

              // --- داده ---
              _SectionHeader(title: 'داده'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent),
                  title: const Text(AppStrings.resetSave),
                  subtitle: const Text('بازیِ نیمه‌تمامِ ذخیره‌شده پاک می‌شود'),
                  enabled: saveManager.hasSave,
                  onTap: saveManager.hasSave
                      ? () async {
                          await saveManager.clear();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(AppStrings.resetSaveDone)),
                            );
                          }
                        }
                      : null,
                ),
              ),

              const SizedBox(height: 24),
              Center(
                child: Text(
                  'نسخهٔ ۱٫۰٫۰ — ساخته‌شده با Flutter + Flame',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withOpacity(0.35),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.gold.withOpacity(0.9),
        ),
      ),
    );
  }
}

/// ردیف انتخاب چندگزینه‌ای (Segmented) داخل کارت.
class _OptionTile<T> extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.options,
    required this.current,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final List<(T, String)> options;
  final T current;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 14.5)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(
                  const TextStyle(
                      fontFamily: 'VazirmatnFD', fontSize: 12.5),
                ),
              ),
              segments: [
                for (final (value, label) in options)
                  ButtonSegment<T>(value: value, label: Text(label)),
              ],
              selected: {current},
              onSelectionChanged: (set) => onChanged(set.first),
            ),
          ),
        ],
      ),
    );
  }
}
