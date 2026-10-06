/// منوی اصلی بازی شلم.
library;

import 'package:flutter/material.dart';

import '../../model/card.dart';
import '../../model/enums.dart';
import '../../state/game_controller.dart';
import '../../util/persian.dart';
import '../theme.dart';
import '../widgets/suit_icon.dart';
import 'game_screen.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _hasSave = false;

  @override
  void initState() {
    super.initState();
    _refresh();
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
    final String? asset = c.settings.surface.asset;
    return Scaffold(
      body: AnimatedBuilder(
        animation: c,
        builder: (BuildContext context, Widget? _) => Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (asset != null)
              Image.asset(asset, fit: BoxFit.cover)
            else
              const DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFF123F2C)),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: <Color>[Color(0xFF241A13), Color(0xFF3A2A1C)],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: AppColors.goldDeep),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const SuitIcon(
                              suit: Suit.spades,
                              size: 22,
                              color: Color(0xFFD9CDB6),
                            ),
                            const SizedBox(width: 8),
                            const SuitIcon(
                              suit: Suit.hearts,
                              size: 22,
                              color: Color(0xFFE2705A),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'شلم',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: AppColors.gold,
                                shadows: <Shadow>[
                                  Shadow(
                                    color: AppColors.gold.withValues(alpha: 0.4),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            const SuitIcon(
                              suit: Suit.diamonds,
                              size: 22,
                              color: Color(0xFFE2705A),
                            ),
                            const SizedBox(width: 8),
                            const SuitIcon(
                              suit: Suit.clubs,
                              size: 22,
                              color: Color(0xFFD9CDB6),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'بازی کلاسیک ورق ایرانی — چهار نفره، دو تیمی',
                          style: TextStyle(fontSize: 12.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
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
                          icon: Icons.settings,
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
                        const SizedBox(height: 16),
                        Text(
                          'حریف‌ها: ${c.settings.difficulty.fa}   •   '
                          'بازی تا ${fa(c.settings.rules.targetScore)} امتیاز',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFB7AA92),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: SizedBox(
        width: double.infinity,
        child: primary
            ? FilledButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 20),
                label: Text(label),
              )
            : OutlinedButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 20),
                label: Text(label),
              ),
      ),
    );
  }
}
