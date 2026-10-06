/// صفحهٔ میز بازی شلم.
library;

import 'package:flutter/material.dart';

import '../../game/engine.dart';
import '../../game/rules.dart';
import '../../game/scoring.dart';
import '../../model/card.dart';
import '../../model/enums.dart';
import '../../state/game_controller.dart';
import '../../util/persian.dart';
import '../theme.dart';
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
        if (asset != null)
          Image.asset(asset, fit: BoxFit.cover)
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: <Color>[Color(0xFF1C6B4B), Color(0xFF0C3524)],
                radius: 0.9,
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.6),
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
            Container(
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
                  Text(
                    'حکم',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          if (e.contract > 0) ...<Widget>[
            const SizedBox(width: 6),
            _Chip(
              text: 'قرارداد ${contractLabel(e.contract)}',
              color: AppColors.gold,
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
                  Text(
                    '${fa(e.scores[0])} : ${fa(e.scores[1])}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.gold,
                    ),
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
        final double cw = (box.maxWidth * 0.1).clamp(26.0, 40.0);
        return Stack(
          children: <Widget>[
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
            Center(
              child: _TrickArea(
                controller: controller,
                size: Size(box.maxWidth * 0.62, box.maxHeight * 0.74),
              ),
            ),
            if (e.phase == GamePhase.kitty)
              Align(
                alignment: const Alignment(0, 0.1),
                child: _KittyView(controller: controller),
              ),
          ],
        );
      },
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
            width: cardWidth + (hand.length - 1).clamp(0, 20) * cardWidth * 0.22,
            height: cardWidth * kCardAspect,
            child: Stack(
              children: <Widget>[
                for (int i = 0; i < hand.length; i++)
                  Positioned(
                    left: i * cardWidth * 0.22,
                    child: CardBackView(
                      width: cardWidth,
                      back: controller.settings.cardBack,
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

    final bool vertical = player == 1 || player == 3;
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

    String? tag;
    if (e.phase == GamePhase.bidding) {
      if (passed) {
        tag = 'پاس';
      } else if (bid != null) {
        tag = contractLabel(bid);
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.gold
            : Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: teamOf(player) == 0
              ? AppColors.teamUs.withValues(alpha: 0.7)
              : AppColors.teamThem.withValues(alpha: 0.7),
        ),
        boxShadow: highlight
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.5),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isHakem)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.workspace_premium,
                size: 15,
                color: highlight ? const Color(0xFF6B4E10) : AppColors.gold,
              ),
            ),
          Text(
            controller.nameOf(player),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlight ? const Color(0xFF241B06) : Colors.white,
            ),
          ),
          if (tag != null) ...<Widget>[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: highlight ? const Color(0xFF241B06) : Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrickArea extends StatelessWidget {
  const _TrickArea({required this.controller, required this.size});

  final GameController controller;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final ShelemEngine e = controller.engine!;
    final double cw = (size.width * 0.28).clamp(38.0, 68.0);
    const List<Alignment> spots = <Alignment>[
      Alignment(0, 0.95), // 0 — جنوب
      Alignment(0.95, 0), // 1 — شرق
      Alignment(0, -0.95), // 2 — شمال
      Alignment(-0.95, 0), // 3 — غرب
    ];
    final int? winner = e.phase == GamePhase.trickComplete && e.trick.length == 4
        ? trickWinner(e.trick, e.trump)
        : null;

    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          for (final PlayedCard p in e.trick)
            Align(
              alignment: spots[p.player],
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                scale: winner == p.player ? 1.12 : 1,
                child: CardView(
                  card: p.card,
                  width: cw,
                  isTrump: isTrumpCard(p.card, e.trump),
                  elevation: 6,
                ),
              ),
            ),
          if (winner != null)
            Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${controller.nameOf(winner)} برد '
                  '(${fa(trickScore(e.trick))})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF241B06),
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
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: CardBackView(
                  width: 40,
                  back: controller.settings.cardBack,
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

    if (child == null) return const SizedBox(height: 6);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: Colors.black.withValues(alpha: 0.35),
      child: child,
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
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: OutlinedButton(
                  onPressed: controller.humanPass,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    side: const BorderSide(color: AppColors.teamThem),
                    foregroundColor: AppColors.teamThem,
                  ),
                  child: const Text('پاس'),
                ),
              ),
              for (final int v in options.take(14))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: FilledButton(
                    onPressed: () => controller.humanBid(v),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      backgroundColor: v >= kShelemBid
                          ? AppColors.teamUs
                          : AppColors.gold,
                    ),
                    child: Text(contractLabel(v)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
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
    final Set<PlayingCard> legal = myTurn
        ? e.legalFor(0).toSet()
        : <PlayingCard>{};

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final int n = hand.length;
        if (n == 0) return const SizedBox(height: 90);
        final double avail = box.maxWidth - 16;
        double cw = avail / (1 + (n - 1) * 0.5);
        cw = cw.clamp(30.0, 78.0);
        final double overlap = cw * 0.5;
        final double total = cw + (n - 1) * overlap;
        final double start = (box.maxWidth - total) / 2;
        final double h = cw * kCardAspect + 26;

        return SizedBox(
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (int i = 0; i < n; i++)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 160),
                  left: start + i * overlap,
                  bottom: controller.selectedDiscards.contains(hand[i]) ? 22 : 6,
                  child: CardView(
                    card: hand[i],
                    width: cw,
                    isTrump: isTrumpCard(hand[i], e.trump),
                    selected: controller.selectedDiscards.contains(hand[i]),
                    playable: myTurn &&
                        controller.settings.highlightLegal &&
                        legal.contains(hand[i]),
                    dimmed: myTurn &&
                        controller.settings.highlightLegal &&
                        !legal.contains(hand[i]),
                    onTap: () {
                      if (discarding) {
                        controller.toggleDiscard(hand[i]);
                      } else {
                        controller.humanPlay(hand[i]);
                      }
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
