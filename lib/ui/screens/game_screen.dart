/// صفحهٔ میز بازی شلم.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/engine.dart';
import '../../game/rules.dart';
import '../../game/scoring.dart';
import '../../model/card.dart';
import '../../model/enums.dart';
import '../../state/game_controller.dart';
import '../../util/persian.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/card_view.dart';
import '../widgets/dialogs.dart';
import '../widgets/suit_icon.dart';
import 'settings_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _react());
  }

  void _react() {
    if (!mounted) return;
    final GameController c = widget.controller;

    final String? t = c.toast;
    if (t != null) {
      c.toast = null;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(t, textAlign: TextAlign.center),
          duration: const Duration(milliseconds: 1600),
        ));
    }

    final ShelemEngine? e = c.engine;
    if (e == null || _dialogOpen) return;

    if (e.phase == GamePhase.roundComplete) {
      _dialogOpen = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) => RoundSummaryDialog(
          controller: c,
          onNext: () {
            Navigator.of(ctx).pop();
            _dialogOpen = false;
            c.nextRound();
          },
        ),
      );
      return;
    }

    if (e.phase == GamePhase.gameOver) {
      _dialogOpen = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) => GameOverDialog(
          controller: c,
          onNewGame: () {
            Navigator.of(ctx).pop();
            _dialogOpen = false;
            c.newGame();
          },
          onMenu: () {
            Navigator.of(ctx).pop();
            _dialogOpen = false;
            c.quitToMenu();
            Navigator.of(context).pop();
          },
        ),
      );
      return;
    }

    // اعلام حکم توسط بازیکن
    final bool needPicker = e.phase == GamePhase.declaringTrump &&
        e.hakem == 0 &&
        ((c.settings.declareTrumpWithPicker && e.trick.isEmpty) ||
            e.awaitingJokerTrump);
    if (needPicker) {
      _dialogOpen = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) => TrumpPickerDialog(
          hand: e.hands[0],
          title: e.awaitingJokerTrump
              ? 'با جوکر شروع کردید؛ خالِ حکم را اعلام کنید'
              : 'خالِ حکم را انتخاب کنید',
          onPick: (Suit s) {
            Navigator.of(ctx).pop();
            _dialogOpen = false;
            c.humanDeclareTrump(s);
          },
        ),
      );
    }
  }

  Future<void> _confirmQuit() async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('خروج از بازی'),
        content: const Text(
          'بازی ذخیره می‌شود و بعداً می‌توانید ادامه بدهید.',
        ),
        actions: <Widget>[
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ادامهٔ بازی'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      widget.controller.quitToMenu();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final GameController c = widget.controller;
    return AnimatedBuilder(
      animation: c,
      builder: (BuildContext context, Widget? _) {
        final ShelemEngine? e = c.engine;
        if (e == null) return const Scaffold(body: SizedBox.shrink());
        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _Background(surface: c.settings.surface),
              SafeArea(
                child: Column(
                  children: <Widget>[
                    _TopBar(controller: c, onQuit: _confirmQuit),
                    Expanded(child: _TableArea(controller: c)),
                    _ActionArea(controller: c),
                    _HandArea(controller: c),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── پس‌زمینه ───────────────────────────────────────────────────────────
class _Background extends StatelessWidget {
  const _Background({required this.surface});

  final TableSurface surface;

  @override
  Widget build(BuildContext context) {
    final String? asset = surface.asset;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.1),
              radius: 1.1,
              colors: <Color>[Color(0xFF1C6B4B), Color(0xFF07271A)],
            ),
          ),
        ),
        if (asset != null) Image.asset(asset, fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withValues(alpha: 0.72),
                Colors.black.withValues(alpha: 0.40),
                Colors.black.withValues(alpha: 0.72),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── نوار بالا ──────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller, required this.onQuit});

  final GameController controller;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final ShelemEngine e = controller.engine!;
    final List<int> pts = e.currentPoints();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        border: Border(
          bottom: BorderSide(color: AppColors.goldDeep.withValues(alpha: 0.45)),
        ),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'منوی اصلی',
            icon: const Icon(Icons.menu, color: AppColors.gold),
            onPressed: onQuit,
          ),
          IconButton(
            tooltip: 'تنظیمات',
            icon: const Icon(Icons.settings, color: AppColors.gold),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(controller: controller),
              ),
            ),
          ),
          IconButton(
            tooltip: 'دست‌های قبلی',
            icon: const Icon(Icons.history, color: AppColors.gold),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: AppColors.panel,
              builder: (_) => TrickViewerSheet(controller: controller),
            ),
          ),
          const Spacer(),
          if (e.trump != null)
            PopIn(
              key: ValueKey<Suit>(e.trump!),
              child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.goldDeep),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SuitIcon(suit: e.trump!, size: 16),
                  const SizedBox(width: 5),
                  const Text(
                    'حکم',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            ),
          if (e.contract > 0) ...<Widget>[
            const SizedBox(width: 6),
            PopIn(
              key: ValueKey<int>(e.contract),
              child: _Chip(
                text: 'قرارداد ${contractLabel(e.contract)}',
                color: AppColors.gold,
              ),
            ),
          ],
          const Spacer(),
          GestureDetector(
            onTap: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: AppColors.panel,
              isScrollControlled: true,
              builder: (_) => ScoreboardSheet(controller: controller),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.goldDeep.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CountUpText(
                        value: e.scores[0],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.teamUs,
                        ),
                      ),
                      const Text(
                        ' : ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.gold,
                        ),
                      ),
                      CountUpText(
                        value: e.scores[1],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.teamThem,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'این راند ${fa(pts[0])}-${fa(pts[1])}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ── میز و صندلی‌ها ─────────────────────────────────────────────────────
class _TableArea extends StatelessWidget {
  const _TableArea({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final ShelemEngine e = controller.engine!;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double cw = (box.maxWidth * 0.085).clamp(24.0, 38.0);
        return Stack(
          children: <Widget>[
            // میزِ نمدیِ بیضی وسط
            Center(
              child: Container(
                width: box.maxWidth * 0.90,
                height: box.maxHeight * 0.78,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(box.maxWidth * 0.45, box.maxHeight * 0.39),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 34,
                      spreadRadius: 4,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(-0.2, -0.35),
                            radius: 1.0,
                            colors: <Color>[
                              Color(0xFF2E8C63),
                              Color(0xFF17684A),
                              Color(0xFF0A3524),
                            ],
                            stops: <double>[0, 0.55, 1],
                          ),
                        ),
                      ),
                      // نشانِ محوِ وسطِ میز
                      const Center(
                        child: Opacity(
                          opacity: 0.075,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  SuitIcon(
                                    suit: Suit.spades,
                                    size: 46,
                                    color: Color(0xFFF6E7C1),
                                  ),
                                  SizedBox(width: 10),
                                  SuitIcon(
                                    suit: Suit.hearts,
                                    size: 46,
                                    color: Color(0xFFF6E7C1),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  SuitIcon(
                                    suit: Suit.diamonds,
                                    size: 46,
                                    color: Color(0xFFF6E7C1),
                                  ),
                                  SizedBox(width: 10),
                                  SuitIcon(
                                    suit: Suit.clubs,
                                    size: 46,
                                    color: Color(0xFFF6E7C1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(painter: _TableRimPainter()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (e.seats == 2)
              Align(
                alignment: Alignment.topCenter,
                child: _Seat(controller: controller, player: 1, cardWidth: cw),
              )
            else ...<Widget>[
              Align(
                alignment: Alignment.topCenter,
                child: _Seat(controller: controller, player: 2, cardWidth: cw),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _Seat(controller: controller, player: 1, cardWidth: cw),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: _Seat(controller: controller, player: 3, cardWidth: cw),
              ),
            ],
            // برگ‌های روی هم در بازی دونفره
            if (e.stock.isNotEmpty)
              Align(
                alignment: const Alignment(-0.92, -0.55),
                child: _StockPile(
                  count: e.stock.length,
                  width: cw * 1.15,
                  back: controller.settings.cardBack,
                ),
              ),
            Center(
              child: _TrickArea(
                controller: controller,
                size: Size(box.maxWidth * 0.60, box.maxHeight * 0.62),
              ),
            ),
            if (e.phase == GamePhase.kitty)
              Align(
                alignment: const Alignment(0, 0.25),
                child: _KittyView(controller: controller),
              ),
          ],
        );
      },
    );
  }
}

/// قابِ چوبی و حلقه‌های طلاییِ دورِ میز (بیضوی، هم‌شکل با خودِ میز).
class _TableRimPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = Offset.zero & size;
    final Paint wood = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF6B4423), Color(0xFF3A2210)],
      ).createShader(r);
    canvas.drawOval(r.deflate(7), wood);

    final Paint gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = AppColors.gold.withValues(alpha: 0.55);
    canvas.drawOval(r.deflate(15), gold);

    final Paint faint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.gold.withValues(alpha: 0.16);
    canvas.drawOval(r.deflate(30), faint);

    // سایهٔ داخلیِ ملایم برای حسِ گودیِ میز
    final Paint inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..color = Colors.black.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawOval(r.deflate(20), inner);
  }

  @override
  bool shouldRepaint(covariant _TableRimPainter oldDelegate) => false;
}

/// برگ‌های روی هم در بازی دونفره (با شمارندهٔ باقی‌مانده).
class _StockPile extends StatelessWidget {
  const _StockPile({
    required this.count,
    required this.width,
    required this.back,
  });

  final int count;
  final double width;
  final CardBack back;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: width + 6,
          height: width * kCardAspect + 6,
          child: Stack(
            children: <Widget>[
              for (int i = 0; i < 3; i++)
                Positioned(
                  left: i * 3.0,
                  top: i * 3.0,
                  child: CardBackView(
                    width: width,
                    back: back,
                    elevation: 3,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          ),
          child: Text(
            fa(count),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
        ),
      ],
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.controller,
    required this.player,
    required this.cardWidth,
  });

  final GameController controller;
  final int player;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final ShelemEngine e = controller.engine!;
    final List<PlayingCard> hand = e.hands[player];
    final bool isTurn = (e.phase == GamePhase.playing ||
            e.phase == GamePhase.declaringTrump) &&
        e.turn == player;
    final bool isBidding = e.phase == GamePhase.bidding && e.bidder == player;

    final Widget cards = controller.settings.showBotHands
        ? Wrap(
            spacing: 2,
            children: <Widget>[
              for (final PlayingCard c in sortedHand(hand, e.trump))
                CardView(card: c, width: cardWidth * 0.8),
            ],
          )
        : SizedBox(
            width: cardWidth + (hand.length - 1).clamp(0, 20) * cardWidth * 0.18,
            height: cardWidth * kCardAspect,
            child: Stack(
              children: <Widget>[
                for (int i = hand.length - 1; i >= 0; i--)
                  Positioned(
                    left: i * cardWidth * 0.18,
                    child: Transform.rotate(
                      angle: (i - (hand.length - 1) / 2) * 0.035,
                      alignment: Alignment.bottomCenter,
                      child: CardBackView(
                        width: cardWidth,
                        back: controller.settings.cardBack,
                        elevation: 3,
                      ),
                    ),
                  ),
              ],
            ),
          );

    final Widget plate = _NamePlate(
      controller: controller,
      player: player,
      highlight: isTurn || isBidding,
    );

    // در بازی دو نفره حریف بالای میز می‌نشیند، پس برگ‌هایش افقی است.
    final bool vertical = e.seats == 4 && (player == 1 || player == 3);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: vertical
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                plate,
                const SizedBox(height: 4),
                RotatedBox(quarterTurns: 1, child: cards),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[plate, const SizedBox(height: 4), cards],
            ),
    );
  }
}

class _NamePlate extends StatelessWidget {
  const _NamePlate({
    required this.controller,
    required this.player,
    required this.highlight,
  });

  final GameController controller;
  final int player;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ShelemEngine e = controller.engine!;
    final bool isHakem = e.hakem == player;
    final int? bid = e.bids[player];
    final bool passed = e.passed[player];
    final bool us = teamOf(player) == 0;

    String? tag;
    if (e.phase == GamePhase.bidding) {
      if (passed) {
        tag = 'پاس';
      } else if (bid != null) {
        tag = contractLabel(bid);
      }
    }

    return PulseGlow(
      active: highlight,
      radius: 20,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: highlight
                ? const <Color>[AppColors.gold, Color(0xFFF0DCAA)]
                : <Color>[
                    Colors.black.withValues(alpha: 0.62),
                    Colors.black.withValues(alpha: 0.42),
                  ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: (us ? AppColors.teamUs : AppColors.teamThem)
                .withValues(alpha: highlight ? 0.95 : 0.6),
            width: 1.3,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (isHakem)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  size: 15,
                  color: highlight ? const Color(0xFF6B4E10) : AppColors.gold,
                ),
              ),
            Text(
              controller.nameOf(player),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: highlight ? const Color(0xFF241B06) : Colors.white,
              ),
            ),
            if (tag != null) ...<Widget>[
              const SizedBox(width: 6),
              PopIn(
                key: ValueKey<String>('bid-$player-$tag'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: highlight
                        ? Colors.black.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color:
                          highlight ? const Color(0xFF241B06) : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrickArea extends StatelessWidget {
  const _TrickArea({required this.controller, required this.size});

  final GameController controller;
  final Size size;

  /// جهتی که کارتِ هر بازیکن از آن وارد میز می‌شود.
  static const List<Offset> _from = <Offset>[
    Offset(0, 1), // جنوب
    Offset(1, 0), // شرق
    Offset(0, -1), // شمال
    Offset(-1, 0), // غرب
  ];

  /// زاویهٔ کوچکِ طبیعیِ هر کارت روی میز.
  static const List<double> _tilt = <double>[0.02, -0.05, 0.03, 0.06];

  @override
  Widget build(BuildContext context) {
    final ShelemEngine e = controller.engine!;
    final double cw = (size.width * 0.28).clamp(42.0, 68.0);
    final List<Alignment> spots = e.seats == 2
        ? <Alignment>[const Alignment(0, 0.72), const Alignment(0, -0.72)]
        : <Alignment>[
            const Alignment(0, 0.86),
            const Alignment(0.86, 0.02),
            const Alignment(0, -0.86),
            const Alignment(-0.86, 0.02),
          ];
    final List<Offset> from = e.seats == 2
        ? <Offset>[const Offset(0, 1), const Offset(0, -1)]
        : _from;
    final List<double> tilt =
        e.seats == 2 ? <double>[0.02, 0.03] : _tilt;
    final int? winner =
        e.phase == GamePhase.trickComplete && e.trick.length == e.seats
            ? trickWinner(e.trick, e.trump)
            : null;

    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // هالهٔ ملایمِ وسطِ میز
          Center(
            child: Container(
              width: size.width * 0.86,
              height: size.width * 0.86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          for (final PlayedCard p in e.trick)
            Align(
              alignment: spots[p.player],
              child: FlyIn(
                key: ValueKey<String>('trick-${p.card.id}'),
                from: from[p.player],
                distance: cw * 2.1,
                tilt: tilt[p.player],
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  scale: winner == p.player ? 1.14 : 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(cw * 0.1),
                      boxShadow: winner == p.player
                          ? <BoxShadow>[
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.75),
                                blurRadius: 22,
                                spreadRadius: 1,
                              ),
                            ]
                          : const <BoxShadow>[],
                    ),
                    child: CardView(
                      card: p.card,
                      width: cw,
                      isTrump: isTrumpCard(p.card, e.trump),
                      elevation: 8,
                    ),
                  ),
                ),
              ),
            ),
          if (winner != null)
            Align(
              alignment: const Alignment(0, 0.04),
              child: PopIn(
                key: ValueKey<int>(e.completedTricks.length),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[AppColors.gold, Color(0xFFF3DFA8)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Text(
                    '${controller.nameOf(winner)}  ${fa(trickScore(e.trick))}+',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF241B06),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KittyView extends StatelessWidget {
  const _KittyView({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final ShelemEngine e = controller.engine!;
    final bool mine = e.hakem == 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'گلِ وسط (${fa(e.config.kittySize)} برگ)',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (int i = 0; i < e.kitty.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: PopIn(
                  delay: Duration(milliseconds: 70 * i),
                  child: Transform.rotate(
                    angle: (i - (e.kitty.length - 1) / 2) * 0.06,
                    child: CardBackView(
                      width: 46,
                      back: controller.settings.cardBack,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (!mine)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${controller.nameOf(e.hakem!)} گل را برمی‌دارد…',
              style: const TextStyle(fontSize: 11),
            ),
          ),
      ],
    );
  }
}

// ── ناحیهٔ کنش (حراج، گل، پیام‌ها) ─────────────────────────────────────
class _ActionArea extends StatelessWidget {
  const _ActionArea({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final ShelemEngine e = controller.engine!;

    Widget? child;
    switch (e.phase) {
      case GamePhase.bidding:
        child = e.bidder == 0
            ? _BidBar(controller: controller)
            : _status('نوبت خواندنِ ${controller.nameOf(e.bidder)}…');
      case GamePhase.kitty:
        child = e.hakem == 0
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: controller.humanTakeKitty,
                    icon: const Icon(Icons.download, size: 18),
                    label: Text('برداشتن گل (${fa(e.config.kittySize)} برگ)'),
                  ),
                ],
              )
            : _status('حاکم در حال برداشتن گل است…');
      case GamePhase.discarding:
        child = e.hakem == 0
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      'برای کنار گذاشتن، ${fa(e.config.kittySize)} برگ را لمس کنید '
                      '(${fa(controller.selectedDiscards.length)} انتخاب شد) — '
                      'امتیاز این برگ‌ها مال شماست',
                      style: const TextStyle(fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed:
                        controller.selectedDiscards.length == e.config.kittySize
                            ? controller.confirmDiscards
                            : null,
                    child: const Text('تأیید'),
                  ),
                ],
              )
            : _status('حاکم در حال چیدن دستش است…');
      case GamePhase.declaringTrump:
        child = e.turn == 0
            ? _status(
                controller.settings.declareTrumpWithPicker
                    ? 'خالِ حکم را انتخاب کنید'
                    : 'اولین برگی که بازی کنید، حکم را تعیین می‌کند',
              )
            : _status('${controller.nameOf(e.turn)} در حال اعلام حکم است…');
      case GamePhase.playing:
        child = _status(
          e.turn == 0 ? 'نوبت شماست' : 'نوبت ${controller.nameOf(e.turn)}…',
        );
      case GamePhase.trickComplete:
        child = _status('جمع‌آوری دست…');
      case GamePhase.dealing:
        child = _status('در حال پخش ورق…');
      case GamePhase.roundComplete:
      case GamePhase.gameOver:
        child = null;
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: child == null
          ? const SizedBox(width: double.infinity, height: 6)
          : Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.48),
                  ],
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOut,
                child: KeyedSubtree(
                  key: ValueKey<String>('${e.phase}-${e.bidder}-${e.turn}'),
                  child: child,
                ),
              ),
            ),
    );
  }

  Widget _status(String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      );
}

class _BidBar extends StatelessWidget {
  const _BidBar({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final ShelemEngine e = controller.engine!;
    final List<int> options = e.availableBids();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          e.highBid == 0
              ? 'خواندن را شروع کنید (حداقل ${fa(e.config.minBid)})'
              : 'بالاترین خوانده‌شده: ${contractLabel(e.highBid)} '
                  'توسط ${controller.nameOf(e.hakem!)}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: OutlinedButton(
                  onPressed: e.canPass ? controller.humanPass : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    side: const BorderSide(color: AppColors.teamThem),
                    foregroundColor: AppColors.teamThem,
                  ),
                  child: const Text('پاس'),
                ),
              ),
              for (int bi = 0; bi < options.length; bi++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: PopIn(
                    delay: Duration(milliseconds: 28 * bi),
                    child: _bidButton(options[bi])),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bidButton(int v) => FilledButton(
        onPressed: () => controller.humanBid(v),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          backgroundColor: v >= kShelemBid ? AppColors.teamUs : AppColors.gold,
        ),
        child: Text(contractLabel(v)),
      );
}

// ── دست بازیکن ─────────────────────────────────────────────────────────
class _HandArea extends StatelessWidget {
  const _HandArea({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final ShelemEngine e = controller.engine!;
    final List<PlayingCard> hand = controller.settings.sortHand
        ? sortedHand(e.hands[0], e.trump)
        : e.hands[0];
    final bool discarding = e.phase == GamePhase.discarding && e.hakem == 0;
    final bool myTurn = controller.isHumanTurn;
    final Set<PlayingCard> legal =
        myTurn ? e.legalFor(0).toSet() : <PlayingCard>{};
    final bool highlight = controller.settings.highlightLegal;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final int n = hand.length;
        if (n == 0) return const SizedBox(height: 96);

        // هرچه برگ‌ها بیشتر، هم‌پوشانی بیشتر؛ کارت‌ها بزرگ می‌مانند.
        final double avail = box.maxWidth - 72;
        double cw = avail / (1 + (n - 1) * 0.42);
        cw = cw.clamp(38.0, 74.0);
        final double overlap = math.min(cw * 0.62, (avail - cw) / math.max(1, n - 1));
        final double total = cw + (n - 1) * overlap;
        final double start = (box.maxWidth - total) / 2;
        final double ch = cw * kCardAspect;
        final double spread = math.min(0.040, 0.34 / n);
        final double mid = (n - 1) / 2;
        final double arc = cw * 0.055;
        final double h = ch + arc * mid * mid * 0.5 + 34;

        return SizedBox(
          height: h,
          child: TweenAnimationBuilder<double>(
            // با شروع هر راند، ورق‌ها دوباره «پخش» می‌شوند.
            key: ValueKey<int>(e.round * 10 + (e.hakem ?? 0)),
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 760),
            curve: Curves.linear,
            builder: (BuildContext context, double t, Widget? _) {
              return Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  // کارت‌های سمت راست زیرتر رسم می‌شوند تا گوشهٔ هر برگ پیدا باشد
                  for (int i = n - 1; i >= 0; i--)
                    _card(
                      context: context,
                      index: i,
                      count: n,
                      card: hand[i],
                      engine: e,
                      cw: cw,
                      overlap: overlap,
                      start: start,
                      spread: spread,
                      mid: mid,
                      arc: arc,
                      progress: _stagger(t, i, n),
                      discarding: discarding,
                      myTurn: myTurn,
                      legal: legal,
                      highlight: highlight,
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// پیشرفتِ پخشِ ورقِ شمارهٔ [i] (پله‌ای، از راست به چپ).
  double _stagger(double t, int i, int n) {
    final double startAt = (i / math.max(1, n)) * 0.55;
    return ((t - startAt) / 0.45).clamp(0.0, 1.0);
  }

  Widget _card({
    required BuildContext context,
    required int index,
    required int count,
    required PlayingCard card,
    required ShelemEngine engine,
    required double cw,
    required double overlap,
    required double start,
    required double spread,
    required double mid,
    required double arc,
    required double progress,
    required bool discarding,
    required bool myTurn,
    required Set<PlayingCard> legal,
    required bool highlight,
  }) {
    final bool selected = controller.selectedDiscards.contains(card);
    final bool isLegal = legal.contains(card);
    final double d = index - mid;
    final double angle = d * spread;
    final double lift = arc * (mid * mid - d * d) * 0.5;
    final double eased = Curves.easeOutCubic.transform(progress);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      left: start + index * overlap,
      bottom: 18 + lift + (selected ? 26 : 0),
      child: Opacity(
        opacity: eased,
        child: Transform.translate(
          // ورود از سمتِ بالا-راست (جایی که ورق پخش می‌شود)
          offset: Offset((1 - eased) * 120, (1 - eased) * -110),
          child: Transform.rotate(
            angle: angle * eased + (1 - eased) * 0.5,
            alignment: Alignment.bottomCenter,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 180),
              scale: selected ? 1.06 : 1,
              child: CardView(
                card: card,
                width: cw,
                isTrump: isTrumpCard(card, engine.trump),
                selected: selected,
                playable: myTurn && highlight && isLegal,
                dimmed: myTurn && highlight && !isLegal,
                elevation: 6,
                onTap: () {
                  if (discarding) {
                    controller.toggleDiscard(card);
                  } else {
                    controller.humanPlay(card);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
