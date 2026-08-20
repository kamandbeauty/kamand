import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../audio/sound_manager.dart';
import '../../core/app_strings.dart';
import '../../core/app_theme.dart';
import '../../storage/save_manager.dart';
import '../../storage/settings_repository.dart';
import '../game/game_screen.dart';
import '../settings/settings_screen.dart';
import 'how_to_play_dialog.dart';

/// صفحهٔ خانه — نقطهٔ ورود برنامه.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.settings,
    required this.saveManager,
  });

  final SettingsController settings;
  final SaveManager saveManager;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _emblemController;

  @override
  void initState() {
    super.initState();
    _emblemController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    SoundManager.instance.warmUp();
  }

  @override
  void dispose() {
    _emblemController.dispose();
    super.dispose();
  }

  void _tap() => SoundManager.instance.button();

  void _openGame({SavedMatch? resume}) {
    _tap();
    SoundManager.instance.startMusic();
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          settings: widget.settings,
          saveManager: widget.saveManager,
          resume: resume,
        ),
      ),
    )
        .then((_) {
      // بازسازی وضعیت دکمهٔ ادامه پس از بازگشت
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSave = widget.saveManager.hasSave;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppTheme.surfaceDark,
      ),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.5),
              radius: 1.3,
              colors: [Color(0xFF1E2A3A), Color(0xFF0C1016)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // لوگو
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.985, end: 1.0)
                        .animate(CurvedAnimation(
                      parent: _emblemController,
                      curve: Curves.easeInOut,
                    )),
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.gold.withOpacity(0.22),
                            blurRadius: 42,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _FallbackEmblem(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    AppStrings.appName,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'بازی کارتی حکم — ۴ نفره، آفلاین',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.white.withOpacity(0.65),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // دکمه‌ها
                  if (hasSave)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openGame(
                            resume: widget.saveManager.loadMatch()),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text(AppStrings.continueGame),
                      ),
                    ),
                  if (hasSave) const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: hasSave
                        ? OutlinedButton(
                            onPressed: () => _confirmNewGame(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(
                                fontFamily: 'VazirmatnFD',
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            child: const Text(AppStrings.newGame),
                          )
                        : ElevatedButton(
                            onPressed: _startNewGame,
                            child: const Text(AppStrings.newGame),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SecondaryButton(
                          icon: Icons.settings_rounded,
                          label: AppStrings.settings,
                          onTap: () {
                            _tap();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SettingsScreen(
                                    settings: widget.settings,
                                    saveManager: widget.saveManager),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SecondaryButton(
                          icon: Icons.school_rounded,
                          label: AppStrings.howToPlay,
                          onTap: () {
                            _tap();
                            showDialog<void>(
                              context: context,
                              builder: (_) => const HowToPlayDialog(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startNewGame() {
    widget.saveManager.clear();
    _openGame();
  }

  void _confirmNewGame(BuildContext context) {
    _tap();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.newGameConfirmTitle),
        content: const Text(AppStrings.newGameConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _startNewGame();
            },
            child: const Text(AppStrings.confirm),
          ),
        ],
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A2230),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: AppTheme.gold),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// نشان جایگزین اگر تصویر لوگو موجود نبود (طراحی برداری).
class _FallbackEmblem extends StatelessWidget {
  const _FallbackEmblem();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A5C40), Color(0xFF153624)],
        ),
      ),
      child: const Center(
        child: Text('♠', style: TextStyle(fontSize: 70, color: AppTheme.gold)),
      ),
    );
  }
}
