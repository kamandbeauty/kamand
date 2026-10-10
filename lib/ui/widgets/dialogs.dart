/// دیالوگ‌های بازی: خلاصهٔ راند، پایان بازی، جدول امتیاز، مرور دست‌ها و
/// انتخاب خالِ حکم.
library;

import 'package:flutter/material.dart';

import '../../game/engine.dart';
import '../../game/rules.dart';
import '../../game/scoring.dart';
import '../../model/card.dart';
import '../../state/game_controller.dart';
import '../../state/settings.dart';
import '../../util/persian.dart';
import '../theme.dart';
import 'card_view.dart';
import 'suit_icon.dart';

/// عنوان قرارداد («۱۲۵»، «شلم»، «سرشلم»).
String contractLabel(int contract) {
  if (contract == kShelemBid) return 'شلم';
  if (contract == kSarShelemBid) return 'سرشلم';
  return fa(contract);
}

/// خلاصهٔ پایان راند.
class RoundSummaryDialog extends StatelessWidget {
  const RoundSummaryDialog({
    super.key,
    required this.controller,
    required this.onNext,
  });

  final GameController controller;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ShelemEngine e = controller.engine!;
    final RoundOutcome o = e.outcome!;
    final bool weWon = o.deltaFor(0) > o.deltaFor(1);
    final List<int> pts = e.currentPoints();

    String headline;
    if (o.slam) {
      headline = o.hakemTeam == 0 ? 'شلم کردید! 🎉' : 'حریف شلم کرد!';
    } else if (o.yasa) {
      headline = o.hakemTeam == 0 ? 'یاسا شدید!' : 'حریف یاسا شد! 🎉';
    } else if (o.contractMade) {
      headline = o.hakemTeam == 0 ? 'قرارداد را گرفتید ✅' : 'حریف قرارداد را گرفت';
    } else {
      headline = o.hakemTeam == 0 ? 'قرارداد را باختید' : 'حریف قرارداد را باخت 🎉';
    }

    return AlertDialog(
      title: Text(
        headline,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: weWon ? AppColors.teamUs : AppColors.teamThem,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Line(
              label: 'حاکم',
              value: '${controller.nameOf(e.hakem!)} — قرارداد '
                  '${contractLabel(o.contract)}',
            ),
            if (e.trump != null)
              _Line(label: 'حکم', value: e.trump!.fa),
            const Divider(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                _PointsBox(
                  title: controller.teamName(0),
                  points: pts[0],
                  delta: o.deltaFor(0),
                  color: AppColors.teamUs,
                ),
                _PointsBox(
                  title: controller.teamName(1),
                  points: pts[1],
                  delta: o.deltaFor(1),
                  color: AppColors.teamThem,
                ),
              ],
            ),
            const Divider(height: 22),
            _Line(
              label: 'مجموع',
              value: '${controller.teamName(0)} ${fa(e.scores[0])}'
                  '  —  ${controller.teamName(1)} ${fa(e.scores[1])}',
            ),
            _Line(
              label: 'دست‌ها',
              value: '${fa(e.tricksWon[0])} به ${fa(e.tricksWon[1])}',
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: <Widget>[
        FilledButton(onPressed: onNext, child: const Text('راند بعد')),
      ],
    );
  }
}

class _PointsBox extends StatelessWidget {
  const _PointsBox({
    required this.title,
    required this.points,
    required this.delta,
    required this.color,
  });

  final String title;
  final int points;
  final int delta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          fa(points),
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          faSigned(delta),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: delta >= 0 ? AppColors.teamUs : AppColors.teamThem,
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFFBDAE92))),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// پایان بازی.
class GameOverDialog extends StatelessWidget {
  const GameOverDialog({
    super.key,
    required this.controller,
    required this.onNewGame,
    required this.onMenu,
  });

  final GameController controller;
  final VoidCallback onNewGame;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final ShelemEngine e = controller.engine!;
    final bool weWon = e.winnerTeam == 0;
    return AlertDialog(
      title: Text(
        weWon ? 'بردید! 🏆' : 'باختید',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: weWon ? AppColors.teamUs : AppColors.teamThem,
        ),
      ),
      content: Text(
        '${controller.teamName(0)} ${fa(e.scores[0])}'
        '  —  ${controller.teamName(1)} ${fa(e.scores[1])}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: <Widget>[
        FilledButton(onPressed: onNewGame, child: const Text('بازی دوباره')),
        OutlinedButton(onPressed: onMenu, child: const Text('منوی اصلی')),
      ],
    );
  }
}

/// جدول امتیاز راندها.
class ScoreboardSheet extends StatelessWidget {
  const ScoreboardSheet({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final ShelemEngine e = controller.engine!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'جدول امتیازها',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _TotalBox(
                    title: controller.teamName(0),
                    value: e.scores[0],
                    color: AppColors.teamUs,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TotalBox(
                    title: controller.teamName(1),
                    value: e.scores[1],
                    color: AppColors.teamThem,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 14,
                  headingRowHeight: 34,
                  dataRowMinHeight: 32,
                  dataRowMaxHeight: 42,
                  columns: <DataColumn>[
                    const DataColumn(label: Text('راند')),
                    const DataColumn(label: Text('حاکم')),
                    const DataColumn(label: Text('قرارداد')),
                    DataColumn(label: Text(controller.teamName(0))),
                    DataColumn(label: Text(controller.teamName(1))),
                    const DataColumn(label: Text('مجموع')),
                  ],
                  rows: <DataRow>[
                    for (final RoundRecord r in e.history)
                      DataRow(
                        cells: <DataCell>[
                          DataCell(Text(fa(r.round))),
                          DataCell(Text(controller.nameOf(r.hakem))),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(contractLabel(r.outcome.contract)),
                              if (r.trump != null) ...<Widget>[
                                const SizedBox(width: 4),
                                SuitIcon(
                                  suit: r.trump!,
                                  size: 13,
                                  color: r.trump!.isRed
                                      ? AppColors.teamThem
                                      : const Color(0xFFD9CDB6),
                                ),
                              ],
                            ],
                          )),
                          DataCell(Text(faSigned(r.outcome.deltaFor(0)))),
                          DataCell(Text(faSigned(r.outcome.deltaFor(1)))),
                          DataCell(Text(
                            '${fa(r.totals[0])} / ${fa(r.totals[1])}',
                          )),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (e.history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'هنوز راندی تمام نشده است.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFA99D87)),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              'بازی تا ${fa(e.config.targetScore)} امتیاز',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFFA99D87)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalBox extends StatelessWidget {
  const _TotalBox({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 12)),
          Text(
            fa(value),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// مرور دست‌های بازی‌شدهٔ راند جاری.
class TrickViewerSheet extends StatefulWidget {
  const TrickViewerSheet({super.key, required this.controller});

  final GameController controller;

  @override
  State<TrickViewerSheet> createState() => _TrickViewerSheetState();
}

class _TrickViewerSheetState extends State<TrickViewerSheet> {
  late int index;

  @override
  void initState() {
    super.initState();
    final List<CompletedTrick> t = widget.controller.engine!.completedTricks;
    index = t.isEmpty ? 0 : t.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final ShelemEngine e = widget.controller.engine!;
    final List<CompletedTrick> tricks = e.completedTricks;
    if (tricks.isEmpty) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'هنوز دستی بازی نشده است.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final CompletedTrick t = tricks[index];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'دستِ ${fa(t.index)} از ${fa(tricks.length)}  •  ${fa(t.points)} امتیاز',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (final PlayedCard p in t.cards)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: p.player == t.winner
                                  ? AppColors.gold
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: CardView(
                            card: p.card,
                            width: 46,
                            isTrump: isTrumpCard(p.card, e.trump),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.controller.nameOf(p.player),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                OutlinedButton(
                  onPressed:
                      index > 0 ? () => setState(() => index -= 1) : null,
                  child: const Text('قبلی'),
                ),
                const SizedBox(width: 14),
                Text('برنده: ${widget.controller.nameOf(t.winner)}'),
                const SizedBox(width: 14),
                OutlinedButton(
                  onPressed: index < tricks.length - 1
                      ? () => setState(() => index += 1)
                      : null,
                  child: const Text('بعدی'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// انتخاب خالِ حکم (برای حالت منو یا وقتی با جوکر شروع شده است).
class TrumpPickerDialog extends StatelessWidget {
  const TrumpPickerDialog({
    super.key,
    required this.hand,
    required this.onPick,
    this.title = 'خالِ حکم را انتخاب کنید',
  });

  final List<PlayingCard> hand;
  final void Function(Suit) onPick;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final Suit s in kRealSuits)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => onPick(s),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 68,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.goldDeep),
                  ),
                  child: Column(
                    children: <Widget>[
                      SuitIcon(suit: s, size: 30),
                      const SizedBox(height: 4),
                      Text(
                        s.fa,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '${fa(hand.where((PlayingCard c) => c.suit == s).length)} برگ',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF6A6258),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// منوی زیبای هنگامِ بازی (از دکمهٔ منو در نوارِ بالا باز می‌شود).
class GameMenuSheet extends StatefulWidget {
  const GameMenuSheet({
    super.key,
    required this.controller,
    required this.onQuit,
  });

  final GameController controller;
  final Future<void> Function() onQuit;

  @override
  State<GameMenuSheet> createState() => _GameMenuSheetState();
}

class _GameMenuSheetState extends State<GameMenuSheet> {
  @override
  Widget build(BuildContext context) {
    final GameController c = widget.controller;
    final ShelemEngine e = c.engine!;
    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[Color(0xFF241A13), Color(0xFF3B2B1D)],
        ),
        border: Border.all(color: AppColors.goldDeep),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.goldDeep.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 12),
              // خلاصهٔ وضعیت
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _MiniStat(
                    label: c.teamName(0),
                    value: fa(e.scores[0]),
                    color: AppColors.teamUs,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'راند ${fa(e.round)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB7AA92),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _MiniStat(
                    label: c.teamName(1),
                    value: fa(e.scores[1]),
                    color: AppColors.teamThem,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _MenuRow(
                icon: Icons.play_arrow_rounded,
                label: 'ادامهٔ بازی',
                primary: true,
                onTap: () => Navigator.of(context).pop(),
              ),
              _MenuRow(
                icon: c.settings.sound
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                label: c.settings.sound ? 'صدا: روشن' : 'صدا: خاموش',
                trailing: Switch(
                  value: c.settings.sound,
                  onChanged: (bool v) {
                    final AppSettings next = c.settings.copy();
                    next.sound = v;
                    c.applySettings(next);
                    setState(() {});
                  },
                ),
                onTap: () {
                  final AppSettings next = c.settings.copy();
                  next.sound = !next.sound;
                  c.applySettings(next);
                  setState(() {});
                },
              ),
              _MenuRow(
                icon: Icons.table_chart_rounded,
                label: 'جدول امتیازها',
                onTap: () {
                  Navigator.of(context).pop();
                  showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: AppColors.panel,
                    isScrollControlled: true,
                    builder: (_) => ScoreboardSheet(controller: c),
                  );
                },
              ),
              _MenuRow(
                icon: Icons.history_rounded,
                label: 'دست‌های قبلی',
                onTap: () {
                  Navigator.of(context).pop();
                  showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: AppColors.panel,
                    builder: (_) => TrickViewerSheet(controller: c),
                  );
                },
              ),
              _MenuRow(
                icon: Icons.exit_to_app_rounded,
                label: 'خروج به منوی اصلی',
                danger: true,
                onTap: widget.onQuit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 10)),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.danger = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Color fg = danger
        ? const Color(0xFFE2705A)
        : (primary ? const Color(0xFF2A1D10) : AppColors.gold);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: primary
                  ? const LinearGradient(
                      colors: <Color>[Color(0xFFE2C070), Color(0xFFB4893C)],
                    )
                  : null,
              color: primary ? null : Colors.black.withValues(alpha: 0.28),
              border: Border.all(
                color: (danger ? const Color(0xFFE2705A) : AppColors.gold)
                    .withValues(alpha: primary ? 0.9 : 0.35),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
