import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../audio/sound_manager.dart';
import '../../core/app_strings.dart';
import '../../core/app_theme.dart';
import '../../core/error_reporter.dart';
import '../../game/game_controller.dart';
import '../../game/hokm_game.dart';
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

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    // شروع پس از اولین فریم — آن‌وقت اندازهٔ صحنهٔ Flame معلوم است.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (mounted) _game.paused = false;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // توقف ساعت بازی (بدون تغییر منطق مسابقه) + ذخیرهٔ خودکار.
        _game.paused = true;
        _controller.saveNow();
    }
  }

  void _onSettingsChanged() {
    _game.applySettings(widget.settings.model);
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    SoundManager.instance.warmUp();
    // تا ساخته‌شدن صحنهٔ Flame صبر کن (در تأخیرهای چیدمان/چرخش امن است).
    for (var i = 0; i < 40 && !_game.isSceneReady && mounted; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return;
    try {
      if (widget.resume != null) {
        _controller.resumeMatch(widget.resume!);
      } else {
        _controller.startNewMatch();
      }
    } on Object catch (e, st) {
      debugPrint('GameScreen start failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      onPopInvokedWithResult: (didPop, result) async {
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
                  GameWidget(
                    game: _game,
                    loadingBuilder: (context) => const _GameLoading(),
                    errorBuilder: (context, error) =>
                        _GameErrorPane(error: error),
                  ),

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

                  // نمایش خوانای خطاهای محتمل در release (به‌جای صفحهٔ خاکستری)
                  ValueListenableBuilder<String?>(
                    valueListenable: AppErrorReporter.lastError,
                    builder: (context, err, _) => _ErrorToast(text: err),
                  ),

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
                      records: _controller.roundRecords,
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

/// نشان خطای ثبت‌شده — پایین صفحه، قابل بستن، بدون مزاحمت برای بازی.
class _ErrorToast extends StatelessWidget {
  const _ErrorToast({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final value = text;
    if (value == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Material(
            color: const Color(0xE63A1116),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 10),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => AppErrorReporter.lastError.value = null,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close, size: 16, color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// نمایش کوتاه هنگام آماده‌سازی صحنه (به‌جای صفحهٔ خالی).
class _GameLoading extends StatelessWidget {
  const _GameLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF10141B),
      child: Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      ),
    );
  }
}

/// به‌جای صفحهٔ خاکستریِ بیربط در release: خطای رندر صحنه را خوانا نشان
/// می‌دهد تا گزارش کاربر قابل‌تشخیص باشد.
class _GameErrorPane extends StatelessWidget {
  const _GameErrorPane({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    debugPrint('GameWidget error: $error');
    return ColoredBox(
      color: const Color(0xFF10141B),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 42),
              const SizedBox(height: 12),
              const Text(
                'خطا در نمایش صحنهٔ بازی',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
