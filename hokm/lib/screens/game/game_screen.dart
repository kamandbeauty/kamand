import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../audio/sound_manager.dart';
import '../../core/app_strings.dart';
import '../../core/app_theme.dart';
import '../../core/persian_utils.dart';
import '../../game/game_controller.dart';
import '../../game/hokm_game.dart';
import '../../game_engine/state/game_enums.dart';
import '../../storage/save_manager.dart';
import '../../storage/settings_repository.dart';
import 'widgets/game_banner.dart';
import 'widgets/score_hud.dart';
import 'widgets/trump_picker.dart';
import 'widgets/round_result_sheet.dart';
import 'widgets/match_result_sheet.dart';

/// صفحهٔ اصلی بازی — صحنهٔ Flame + HUD خفن.
///
/// چیدمان: میز Flame تمام‌صفحه؛ HUD سقفیِ SafeArea بالا
/// (امتیاز/حکم/خروج) و اورلی‌های دیالوگی برای انتخاب حکم و نتایج.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.settings,
    required this.saveManager,
    this.resume,
  });

  final SettingsController settings;
  final SaveManager saveManager;

  /// اگر مقدار داشته باشد، مسابقهٔ ذخیره‌شده ادامه می‌یابد.
  final SavedMatch? resume;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final HokmGame _game;
  late final GameController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _game = HokmGame(settings: widget.settings.model);
    _controller = GameController(
      settings: widget.settings,
      saveManager: widget.saveManager,
    );
    _controller.attachGame(_game);
    // تغییر زندهٔ تنظیمات (تم میز/پشت کارت/سرعت)
    widget.settings.addListener(_onSettingsChanged);
    // شروع پس از اولین فریم — آن‌وقت اندازهٔ صحنهٔ Flame معلوم است.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _onSettingsChanged() {
    _game.applySettings(widget.settings.model);
  }

  void _start() {
    if (_started) return;
    _started = true;
    SoundManager.instance.warmUp();
    if (widget.resume != null) {
      _controller.resumeMatch(widget.resume!);
    } else {
      _controller.startNewMatch();
    }
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (_controller.showMatchResult) return true; // مسابقه تمام شده
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.leaveGameTitle),
        content: const Text(AppStrings.leaveGameBody),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.stay),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(AppStrings.leave),
          ),
        ],
      ),
    );
    if (leave == true) {
      _controller.saveNow();
    }
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _confirmLeave() && mounted && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.surfaceDark,
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // صحنهٔ بازی
                  GameWidget(game: _game),

                  // HUD بالا
                  SafeArea(
                    child: Column(
                      children: [
                        ScoreHud(controller: _controller,
                            onExit: () => _tryExit()),
                        const Spacer(),
                      ],
                    ),
                  ),

                  // بنر مرکزی
                  GameBanner(text: _controller.banner),

                  // دیالوگ انتخاب حکم
                  if (_controller.showTrumpPicker)
                    TrumpPickerOverlay(
                      previewCards: _controller.trumpPreview,
                      onSelected: _controller.onHumanTrumpSelected,
                    ),

                  // نتیجهٔ دست
                  if (_controller.showRoundResult &&
                      _controller.roundResult != null)
                    RoundResultSheet(
                      controller: _controller,
                      result: _controller.roundResult!,
                      onNext: _controller.continueToNextRound,
                      onExit: () => _tryExit(save: true),
                    ),

                  // نتیجهٔ مسابقه
                  if (_controller.showMatchResult)
                    MatchResultSheet(
                      winnerTeam: _controller.matchWinnerTeam,
                      scoreUs: _controller.scoreUs,
                      scoreThem: _controller.scoreThem,
                      onPlayAgain: () {
                        _controller.startNewMatch();
                      },
                      onHome: () => _tryExit(save: false),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _tryExit({bool save = true}) async {
    if (save) _controller.saveNow();
    if (mounted && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
