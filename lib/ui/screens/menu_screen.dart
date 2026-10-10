/// منوی اصلی بازی شلم.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../state/game_controller.dart';
import '../../state/settings.dart';
import '../../util/persian.dart';
import '../theme.dart';
import 'game_screen.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  bool _hasSave = false;
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final bool has = await GameController.savedGameExists();
    if (mounted) setState(() => _hasSave = has);
  }

  void _openGame() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
          builder: (_) => GameScreen(controller: widget.controller),
        ))
        .then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final GameController c = widget.controller;
    return Scaffold(
      body: AnimatedBuilder(
        animation: c,
        builder: (BuildContext context, Widget? _) => Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // پس‌زمینهٔ تزئینی
            Image.asset('assets/images/menu_bg.jpg', fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  // نوارِ بالا: صدا و راهنما
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      children: <Widget>[
                        _RoundIconButton(
                          icon: c.settings.sound
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          tooltip: c.settings.sound
                              ? 'خاموش کردن صدا'
                              : 'روشن کردن صدا',
                          active: c.settings.sound,
                          onTap: () {
                            final AppSettings next = c.settings.copy();
                            next.sound = !next.sound;
                            c.applySettings(next);
                            setState(() {});
                          },
                        ),
                        const SizedBox(width: 8),
                        _RoundIconButton(
                          icon: Icons.menu_book_rounded,
                          tooltip: 'قوانین بازی',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RulesScreen(),
                            ),
                          ),
                        ),
                        const Spacer(),
                        _RoundIconButton(
                          icon: Icons.settings_rounded,
                          tooltip: 'تنظیمات',
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute<void>(
                                builder: (_) => SettingsScreen(controller: c),
                              ))
                              .then((_) => setState(() {})),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _Logo(glow: _glow),
                              const SizedBox(height: 18),
                              _PlayerCountPicker(
                                players: c.settings.rules.players,
                                onChanged: (int n) {
                                  final AppSettings next = c.settings.copy();
                                  next.rules = next.rulesWith(players: n);
                                  c.applySettings(next);
                                  setState(() {});
                                },
                              ),
                              const SizedBox(height: 16),
                              if (_hasSave)
                                _MenuButton(
                                  label: 'ادامهٔ بازی قبلی',
                                  icon: Icons.play_arrow_rounded,
                                  primary: true,
                                  onTap: () async {
                                    final bool ok = await c.loadSavedGame();
                                    if (!mounted) return;
                                    if (ok) {
                                      _openGame();
                                    } else {
                                      setState(() => _hasSave = false);
                                    }
                                  },
                                ),
                              _MenuButton(
                                label: 'بازی جدید',
                                icon: Icons.casino_rounded,
                                primary: !_hasSave,
                                onTap: () {
                                  c.newGame();
                                  _openGame();
                                },
                              ),
                              _MenuButton(
                                label: 'تنظیمات',
                                icon: Icons.tune_rounded,
                                onTap: () => Navigator.of(context)
                                    .push(MaterialPageRoute<void>(
                                      builder: (_) =>
                                          SettingsScreen(controller: c),
                                    ))
                                    .then((_) => setState(() {})),
                              ),
                              _MenuButton(
                                label: 'قوانین بازی',
                                icon: Icons.menu_book_rounded,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const RulesScreen(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              _InfoStrip(controller: c),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// نشانِ بازی: نگارهٔ طلاییِ ترنج + نامِ «شلم».
class _Logo extends StatelessWidget {
  const _Logo({required this.glow});

  final Animation<double> glow;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glow,
      builder: (BuildContext context, Widget? child) {
        final double t = 0.5 + 0.5 * math.sin(glow.value * math.pi * 2);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.14 + 0.16 * t),
                    blurRadius: 46 + 18 * t,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/logo_emblem.png',
                height: 152,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(height: 10),
            ShaderMask(
              shaderCallback: (Rect r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFFFCEFC0),
                  Color(0xFFE8C66A),
                  Color(0xFFB8893A),
                ],
              ).createShader(r),
              child: Text(
                'شلم',
                style: TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                  shadows: <Shadow>[
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 150,
              height: 1.2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Colors.transparent,
                    AppColors.gold.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'بازی کلاسیک ورق ایرانی — دو نفره یا چهار نفره',
              style: TextStyle(fontSize: 12, color: Color(0xFFD9CDB6)),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}

/// دکمهٔ گردِ کوچکِ بالای صفحه.
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.42),
        shape: CircleBorder(
          side: BorderSide(
            color: AppColors.goldDeep.withValues(alpha: active ? 0.9 : 0.4),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(
              icon,
              size: 20,
              color: active ? AppColors.gold : const Color(0xFF8C8273),
            ),
          ),
        ),
      ),
    );
  }
}

/// نوارِ خلاصهٔ تنظیمات زیر دکمه‌ها.
class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final AppSettings s = controller.settings;
    Widget item(IconData icon, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 13, color: AppColors.gold.withValues(alpha: 0.8)),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(fontSize: 11, color: Color(0xFFCFC3AC)),
            ),
          ],
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.goldDeep.withValues(alpha: 0.4)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 6,
        children: <Widget>[
          item(
            s.rules.players == 2 ? Icons.person_rounded : Icons.groups_rounded,
            s.rules.players == 2 ? 'دو نفره' : 'چهار نفره',
          ),
          item(Icons.psychology_alt_rounded, 'حریف: ${s.difficulty.fa}'),
          item(Icons.flag_rounded, 'تا ${fa(s.rules.targetScore)} امتیاز'),
          item(
            s.sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            s.sound ? 'صدا روشن' : 'صدا خاموش',
          ),
        ],
      ),
    );
  }
}

/// انتخاب دو نفره / چهار نفره در صفحهٔ اصلی.
class _PlayerCountPicker extends StatelessWidget {
  const _PlayerCountPicker({required this.players, required this.onChanged});

  final int players;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(int n, String label, IconData icon) {
      final bool on = players == n;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(n),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: on
                  ? LinearGradient(
                      colors: <Color>[
                        AppColors.gold.withValues(alpha: 0.30),
                        AppColors.gold.withValues(alpha: 0.12),
                      ],
                    )
                  : null,
              color: on ? null : Colors.black.withValues(alpha: 0.35),
              border: Border.all(
                color: on
                    ? AppColors.gold
                    : AppColors.gold.withValues(alpha: 0.25),
                width: on ? 1.6 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 17,
                  color: on ? AppColors.gold : const Color(0xFFB7AA92),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                    color: on ? AppColors.gold : const Color(0xFFB7AA92),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        tab(2, 'دو نفره', Icons.person_rounded),
        const SizedBox(width: 10),
        tab(4, 'چهار نفره', Icons.groups_rounded),
      ],
    );
  }
}

/// دکمهٔ بزرگِ منو با قابِ طلایی.
class _MenuButton extends StatefulWidget {
  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool p = widget.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 110),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: p
                    ? const <Color>[Color(0xFFE2C070), Color(0xFFB4893C)]
                    : <Color>[
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.35),
                      ],
              ),
              border: Border.all(
                color: p
                    ? const Color(0xFFF2DFA4)
                    : AppColors.gold.withValues(alpha: 0.45),
                width: p ? 1.4 : 1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: p
                      ? AppColors.gold.withValues(alpha: 0.30)
                      : Colors.black.withValues(alpha: 0.4),
                  blurRadius: p ? 18 : 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  widget.icon,
                  size: 21,
                  color: p ? const Color(0xFF2A1D10) : AppColors.gold,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: p ? const Color(0xFF2A1D10) : AppColors.gold,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: (p ? const Color(0xFF2A1D10) : AppColors.gold)
                      .withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
