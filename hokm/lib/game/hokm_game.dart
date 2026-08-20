import 'dart:math' as math;
import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show TextStyle;

import '../game_engine/managers/deal_manager.dart';
import '../game_engine/managers/hukum_manager.dart';
import '../game_engine/models/playing_card.dart';
import '../game_engine/state/game_enums.dart';
import '../storage/settings_model.dart';
import 'components/card_component.dart';
import 'components/table_background.dart';
import 'effects/turn_indicator.dart';
import 'effects/win_glow.dart';
import 'animations/motion.dart';
import 'table/table_layout.dart';
import 'table/table_theme.dart';

/// بازی Flame حکم — لایهٔ رندر و انیمیشن.
///
/// این کلاس «فقط» نمایشگر است: هیچ قانون و تصمیمی در آن نیست.
/// [GameController] آن را با APIهای سطح‌بالا صدا می‌زند؛ همهٔ متدها
/// Future برمی‌گردانند تا کنترلر بتواند ریتم بازی را حفظ کند.
class HokmGame extends FlameGame {
  HokmGame({required SettingsModel settings}) : _settings = settings;

  SettingsModel _settings;
  late TableLayout layout;
  late TablePalette palette;

  // --- اجزای صحنه ---
  late TableBackground _background;
  late TurnIndicator _turnIndicator;
  final Map<Seat, TextComponent> _nameLabels = {};
  final Map<Seat, TextComponent> _hakimBadges = {};

  /// استخر ۵۲ کارت — یک‌بار ساخته و هر دست بازاستفاده می‌شود.
  final Map<String, CardComponent> cardPool = {};

  /// زون‌های کارت: دست هر بازیکن و مرکز میز.
  final Map<Seat, List<CardComponent>> handZones = {
    for (final s in Seat.values) s: <CardComponent>[],
  };
  final Map<Seat, CardComponent> centerZone = {};

  /// رویداد لمس کارت انسان (توسط GameController ست می‌شود).
  void Function(PlayingCard card)? onHumanCardTapped;

  final math.Random _rng = math.Random();

  // ================================================================
  // راه‌اندازی
  // ================================================================

  bool _sceneBuilt = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // اگر اندازه همین حالا معلوم است، صحنه را بساز؛ در غیر این صورت
    // اولین onGameResize آن را می‌سازد.
    if (size.x > 0 && size.y > 0) _buildScene(size);
  }

  void _buildScene(Vector2 viewSize) {
    if (_sceneBuilt) return;
    _sceneBuilt = true;
    layout = TableLayout(viewSize);
    palette = TablePalette.of(_settings.tableTheme);

    _background = TableBackground(palette: palette)
      ..size = viewSize.clone()
      ..position = Vector2.zero()
      ..priority = 0;
    add(_background);

    _turnIndicator = TurnIndicator(glowColor: palette.accent)
      ..priority = 2
      ..size = Vector2.all(10)
      ..position = Vector2(-1000, -1000);
    add(_turnIndicator);

    // ساخت استخر کارت‌ها — همگی مخفی (در resetTable چیده می‌شوند).
    const suitCodes = ['H', 'D', 'S', 'C'];
    const rankSymbols = [
      '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'
    ];
    for (final suitCode in suitCodes) {
      for (final rankSymbol in rankSymbols) {
        final card = PlayingCard.fromId('${suitCode}_$rankSymbol');
        final comp = CardComponent(
          card: card,
          cardBackStyle: _settings.cardBack,
          onTapped: (c) => onHumanCardTapped?.call(c),
        )
          ..size = Vector2(layout.cardWidth, layout.cardHeight)
          ..anchor = Anchor.center
          ..position = layout.deckCenter.clone()
          ..priority = 1
          ..scale = Vector2.zero(); // مخفی تا شروع دست
        cardPool[card.id] = comp;
        add(comp);
      }
    }
  }

  /// نام بازیکنان و حاکم را روی میز می‌نشاند.
  void setupPlayers({
    required Map<Seat, String> names,
    required Seat humanSeat,
    Seat? hakim,
  }) {
    if (!_sceneBuilt) return;
    for (final label in _nameLabels.values) {
      label.removeFromParent();
    }
    for (final badge in _hakimBadges.values) {
      badge.removeFromParent();
    }
    _nameLabels.clear();
    _hakimBadges.clear();

    for (final seat in Seat.values) {
      final isHuman = seat == humanSeat;
      final label = TextComponent(
        text: names[seat] ?? '',
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: 'VazirmatnFD',
            fontSize: 13.5,
            fontWeight: isHuman ? FontWeight.w700 : FontWeight.w500,
            color: isHuman ? palette.accent : const Color(0xEAE8E2DE),
            shadows: const [
              Shadow(color: Color(0x90000000), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
      )
        ..anchor = Anchor.center
        ..position = layout.namePosition(seat)
        ..priority = 3;
      _nameLabels[seat] = label;
      add(label);
    }
    if (hakim != null) setHakimBadge(hakim);
  }

  /// نشان «حاکم» کنار نام.
  void setHakimBadge(Seat? seat) {
    if (!_sceneBuilt) return;
    for (final badge in _hakimBadges.values) {
      badge.removeFromParent();
    }
    _hakimBadges.clear();
    if (seat == null) return;
    final base = layout.namePosition(seat);
    final badge = TextComponent(
      text: '● حاکم',
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: 'VazirmatnFD',
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: palette.accent,
        ),
      ),
    )
      ..anchor = Anchor.center
      ..position = base + Vector2(0, seat == Seat.south ? -16 : 15)
      ..priority = 3;
    _hakimBadges[seat] = badge;
    add(badge);
  }

  // ================================================================
  // تنظیمات زنده
  // ================================================================

  bool get isSceneReady => _sceneBuilt;

  void applySettings(SettingsModel settings) {
    _settings = settings;
    if (!_sceneBuilt) return;
    palette = TablePalette.of(settings.tableTheme);
    _background.palette = palette;
    for (final comp in cardPool.values) {
      comp.cardBackStyle = settings.cardBack;
      comp.motionSpeedFactor = settings.animationSpeed.multiplier;
    }
  }

  double get _speed => _settings.animationSpeed.multiplier;

  // ================================================================
  // آماده‌سازی دست جدید
  // ================================================================

  /// همهٔ کارت‌ها به دکه برمی‌گردند (بدون انیمیشن — قبل از بر).
  void resetTable() {
    centerZone.clear();
    for (final zone in handZones.values) {
      zone.clear();
    }
    _turnIndicator.hide();

    var i = 0;
    for (final comp in cardPool.values) {
      comp
        ..cancelMotion(jumpToEnd: false)
        ..faceUp = false
        ..interactive = false
        ..playable = true
        ..motionSpeedFactor = _speed
        ..priority = 1
        ..angle = 0
        ..scale = Vector2.zero()
        ..position = layout.deckCenter +
            Vector2((i % 5) - 2.0, (i % 4) - 1.5) * 0.6;
      i++;
    }
  }

  // ================================================================
  // انیمیشن تعیین حاکم (پخش تا اولین آس)
  // ================================================================

  Future<void> animateHakimDetermination(
      List<PlayedForHakim> dealtCards) async {
    if (!_sceneBuilt) return;
    resetTable();
    // کارت‌ها روی دکه پشت به بالا چیده شده‌اند؛ یکی‌یکی به هر نفر پخش و روش
    for (var i = 0; i < dealtCards.length; i++) {
      final dealt = dealtCards[i];
      final comp = cardPool[dealt.card.id]!;
      final isLast = i == dealtCards.length - 1;
      final target = layout.seatAnchor(dealt.seat) * 0.72 +
          layout.trickCenter * 0.28; // نزدیک آن بازیکن
      _bringToFront(comp, 120 + i);
      await comp.animateMotion([
        MotionSegment(
          to: target,
          scaleTo: 0.62,
          duration: Duration(milliseconds: (210 * _speed).round()),
          curve: Curves.easeOutCubic,
          arc: layout.cardHeight * 0.30,
        ),
      ]);
      comp.faceUp = true;
      if (isLast) {
        // آسِ حاکم‌ساز: تأکید کوتاه
        await comp.animateMotion([
          MotionSegment(
            scaleTo: 0.78,
            duration: Duration(milliseconds: (170 * _speed).round()),
            curve: Curves.easeOutBack,
          ),
        ]);
        add(WinGlowPulse(
            center: target, color: palette.accent, maxRadius: 54));
        await Future<void>.delayed(
            Duration(milliseconds: (650 * _speed).round()));
      } else {
        await Future<void>.delayed(
            Duration(milliseconds: (80 * _speed).round()));
      }
    }
    await Future<void>.delayed(Duration(milliseconds: (350 * _speed).round()));
    resetTable();
  }

  // ================================================================
  // انیمیشن بر زدن (spec §23)
  // ================================================================

  Future<void> animateShuffle() async {
    if (!_sceneBuilt) return;
    // ۱) کارت‌ها از هر سو به مرکز جمع می‌شوند و دکه می‌سازند.
    final all = cardPool.values.toList();
    final futures = <Future<void>>[];
    for (var i = 0; i < all.length; i++) {
      final comp = all[i];
      comp.faceUp = false;
      comp.scale.setAll(0.62);
      comp.priority = 40 + i;
      // جهت ورود متفاوت — حس جمع شدن از دست بازیکنان
      final from = switch (i % 4) {
        0 => Vector2(layout.viewSize.x / 2, layout.viewSize.y + layout.cardHeight),
        1 => Vector2(layout.viewSize.x / 2, -layout.cardHeight),
        2 => Vector2(-layout.cardWidth, layout.viewSize.y * 0.4),
        _ => Vector2(layout.viewSize.x + layout.cardWidth, layout.viewSize.y * 0.4),
      };
      comp.position = from;
      comp.angle = 0;
      futures.add(comp.animateMotion([
        MotionSegment(
          to: layout.deckCenter +
              Vector2(_rng.nextDouble() * 6 - 3, _rng.nextDouble() * 5 - 2.5),
          angleTo: (_rng.nextDouble() * 6 - 3) * math.pi / 180,
          duration: Duration(
              milliseconds: ((340 + (i % 8) * 26) * _speed).round()),
          curve: Curves.easeOutCubic,
          arc: layout.cardHeight * 0.35,
        ),
      ]));
      if (i % 9 == 8) {
        await Future.wait(futures);
        futures.clear();
      }
    }
    await Future.wait(futures);

    // ۲) دسته کردن و جابه‌جایی (دو نیم‌دسته) × ۲ بار
    for (var round = 0; round < 2; round++) {
      final halfNo = all.length ~/ 2;
      final left = all.sublist(0, halfNo);
      final right = all.sublist(halfNo);
      final offset = layout.cardWidth * 0.85;
      final gap = layout.cardHeight * 0.12;

      // جدا شدن دو نیم‌دسته
      final splitFutures = <Future<void>>[];
      for (final c in left) {
        splitFutures.add(c.animateMotion([
          MotionSegment(
            to: layout.deckCenter + Vector2(-offset, -gap * 0.3),
            angleTo: -6 * math.pi / 180,
            duration: Duration(milliseconds: (260 * _speed).round()),
            curve: Curves.easeInOutCubic,
            arc: gap,
          ),
        ]));
      }
      for (final c in right) {
        splitFutures.add(c.animateMotion([
          MotionSegment(
            to: layout.deckCenter + Vector2(offset, -gap * 0.3),
            angleTo: 6 * math.pi / 180,
            duration: Duration(milliseconds: (260 * _speed).round()),
            curve: Curves.easeInOutCubic,
            arc: gap,
          ),
        ]));
      }
      await Future.wait(splitFutures);

      // ۳) درهم‌رفتن (ری‌فل) — نیم‌دسته‌ها زیگزاگ در هم می‌روند
      final riffleFutures = <Future<void>>[];
      for (var i = 0; i < halfNo; i++) {
        final fromLeft = left[i];
        final fromRight = (i < right.length) ? right[i] : null;
        final zig = (i % 2 == 0 ? -1.0 : 1.0) * layout.cardWidth * 0.05;
        riffleFutures.add(fromLeft.animateMotion([
          MotionSegment(
            to: layout.deckCenter + Vector2(zig, (i * 0.55)),
            angleTo: 0,
            duration: Duration(
                milliseconds: ((150 + i * 6) * _speed).round()),
            curve: Curves.easeOutCubic,
            arc: layout.cardHeight * 0.10,
          ),
        ]));
        if (fromRight != null) {
          riffleFutures.add(fromRight.animateMotion([
            MotionSegment(
              to: layout.deckCenter + Vector2(-zig, (i * 0.55) + 0.9),
              angleTo: 0,
              duration: Duration(
                  milliseconds: ((165 + i * 6) * _speed).round()),
              curve: Curves.easeOutCubic,
              arc: layout.cardHeight * 0.10,
            ),
          ]));
        }
      }
      await Future.wait(riffleFutures);
    }

    // ۴) مربع نهایی دکه با یک «تکان» ملایم
    final squareFutures = all.map((c) => c.animateMotion([
          MotionSegment(
            to: layout.deckCenter,
            angleTo: 0,
            duration: Duration(milliseconds: (180 * _speed).round()),
            curve: Curves.easeOutBack,
          ),
        ]));
    await Future.wait(squareFutures);

    // تنظیم ترتیب اولویت دکه (بالای دکه = آخرین کارت)
    var pr = 10;
    for (final c in all) {
      c.priority = pr++;
      // موقعیت دکه: پشت به بالا، آمادهٔ پخش
      c.position = layout.deckCenter;
      c.scale.setAll(0.62);
      c.angle = 0;
      c.faceUp = false;
    }
  }

  // ================================================================
  // انیمیشن پخش کارت (spec §24)
  // ================================================================

  /// پخش یک مرحله (۵ یا ۴ کارت به هر بازیکن به ترتیب [steps]).
  ///
  /// [faceUpSeats]: جایگاه‌هایی که کارتشان رو می‌شود (انسان).
  Future<void> animateDealBatch(
    List<DealStep> steps, {
    required Set<Seat> faceUpSeats,
  }) async {
    if (!_sceneBuilt) return;
    var dealIndex = 0;
    for (final step in steps) {
      final zone = handZones[step.seat]!;
      final zoneStart = zone.length;
      final targetCount = zoneStart + step.cards.length;

      for (var j = 0; j < step.cards.length; j++) {
        final comp = cardPool[step.cards[j].id]!;
        _bringToFront(comp, 300 + dealIndex);

        final slot =
            layout.handSlot(step.seat, zoneStart + j, targetCount);
        final isFaceUp = faceUpSeats.contains(step.seat);
        final scale = layout.handScale(step.seat);

        dealIndex++;
        unawaitedFuture(_flyAndLand(comp, slot, scale, isFaceUp));
        zone.add(comp);
        await Future<void>.delayed(
            Duration(milliseconds: (62 * _speed).round()));
      }
    }
  }

  /// پهن شدن نهایی دست‌ها پس از اتمام پخش (چینش دقیق).
  Future<void> finalizeHands() async {
    if (!_sceneBuilt) return;
    final futures = <Future<void>>[];
    for (final seat in Seat.values) {
      futures.add(_relayoutHand(seat, fast: false));
    }
    await Future.wait(futures);
  }

  Future<void> _flyAndLand(CardComponent comp,
      ({Vector2 position, double angle}) slot, double scale,
      bool faceUp) async {
    await comp.animateMotion([
      MotionSegment(
        to: slot.position,
        angleTo: slot.angle,
        scaleTo: scale,
        duration: Duration(milliseconds: (300 * _speed).round()),
        curve: Curves.easeInOutCubic,
        arc: layout.cardHeight * 0.55,
      ),
    ]);
    // کارت‌های انسان: رو شدن با پاپ-فلیپ
    if (faceUp) {
      await comp.animateMotion([
        MotionSegment(
          scaleTo: scale * 0.02,
          duration: Duration(milliseconds: (70 * _speed).round()),
          curve: Curves.easeIn,
        ),
      ]);
      comp.faceUp = true;
      await comp.animateMotion([
        MotionSegment(
          scaleTo: scale,
          duration: Duration(milliseconds: (110 * _speed).round()),
          curve: Curves.easeOutBack,
        ),
      ]);
    }
  }

  void _bringToFront(CardComponent comp, int priority) {
    comp.priority = priority;
  }

  // ================================================================
  // بازی کارت (spec §22 §25)
  // ================================================================

  /// بازیِ یک کارت از دست [seat] به مرکز.
  Future<void> animatePlayCard(Seat seat, PlayingCard card) async {
    if (!_sceneBuilt) return;
    final comp = cardPool[card.id]!;
    handZones[seat]!.remove(comp);

    _bringToFront(comp, 500 + centerZone.length);
    final slot = layout.trickSlot(seat, centerZone.length);
    centerZone[seat] = comp;

    if (seat != Seat.south) {
      // کارت حریف/یار: در مسیر رو می‌شود
      comp.faceUp = true;
    }
    await comp.animateMotion([
      MotionSegment(
        to: slot.position + Vector2(0, seat == Seat.south ? -layout.cardHeight * 0.34 : 0),
        scaleTo: 1.06,
        angleTo: 0,
        duration: Duration(milliseconds: (130 * _speed).round()),
        curve: Curves.easeOut,
        arc: layout.cardHeight * (seat == Seat.south ? 0.55 : 0.4),
      ),
      MotionSegment(
        to: slot.position,
        scaleTo: 1.0,
        angleTo: slot.angle,
        duration: Duration(milliseconds: (150 * _speed).round()),
        curve: Curves.easeInOutCubic,
      ),
    ]);
    comp.faceUp = true;

    // چینش مجدد دستِ همان بازیکن (جاخالی کارت)
    unawaitedFuture(_relayoutHand(seat, fast: true));
  }

  /// جمع کردن دورِ برده‌شده به سمت برنده + پالس. (spec §25 §26)
  Future<void> animateCollectTrick(Seat winner, int teamIndex,
      {required bool isWin}) async {
    if (!_sceneBuilt) return;
    // مکث کوتاه برای دیده شدن‌ِ آخرین کارت
    await Future<void>.delayed(Duration(milliseconds: (620 * _speed).round()));

    add(WinGlowPulse(
      center: layout.seatAnchor(winner) * 0.82 + layout.trickCenter * 0.18,
      color: palette.accent,
      maxRadius: layout.cardHeight * 0.8,
    ));

    final target = layout.teamPilePosition(teamIndex);
    final futures = <Future<void>>[];
    var i = 0;
    for (final comp in centerZone.values) {
      _bringToFront(comp, 600 + i);
      futures.add(comp.animateMotion([
        MotionSegment(
          to: target + Vector2(i * 0.8 - 1.5, -i * 0.6),
          angleTo: 0,
          scaleTo: 0.18,
          duration: Duration(milliseconds: (380 * _speed).round()),
          curve: Curves.easeInOutCubic,
          arc: layout.cardHeight * 0.3,
        ),
      ]));
      i++;
    }
    await Future.wait(futures);
    // پارک کارت‌ها در انبار تیم (پنهان در مقیاس کوچک)
    for (final comp in centerZone.values) {
      comp.faceUp = false;
      comp.scale.setAll(0.0);
      comp.priority = 4;
    }
    centerZone.clear();
    await Future<void>.delayed(Duration(milliseconds: (120 * _speed).round()));
  }

  // ================================================================
  // تعامل انسان
  // ================================================================

  /// تعیین کارت‌های لمسی/روشن در نوبت انسان.
  void setHumanPlayableCards(List<PlayingCard> legal, {required bool enable}) {
    if (!_sceneBuilt) return;
    for (final comp in handZones[Seat.south]!) {
      final isLegal = legal.contains(comp.card);
      comp.interactive = enable && isLegal;
      comp.playable = !enable || isLegal;
    }
  }

  /// برجسته‌سازی موقت کارتِ برداشته‌شده توسط انسان (قبل از تأیید بازی).
  Future<void> liftHumanCard(PlayingCard card, {required bool lift}) async {
    final comp = cardPool[card.id]!;
    final zone = handZones[Seat.south]!;
    final idx = zone.indexOf(comp);
    if (idx < 0) return;
    final slot = layout.humanHandSlot(idx, zone.length);
    await comp.animateMotion([
      MotionSegment(
        to: slot.position +
            Vector2(0, lift ? -layout.cardHeight * 0.34 : 0),
        scaleTo: lift ? 1.09 : 1.0,
        duration: Duration(milliseconds: (120 * _speed).round()),
        curve: Curves.easeOutCubic,
        arc: lift ? 10 : 0,
      ),
    ]);
  }

  // ================================================================
  // نمایش نوبت
  // ================================================================

  void showTurn(Seat seat) {
    if (!_sceneBuilt) return;
    _turnIndicator.showAt(
      layout.seatAnchor(seat) * 0.9 + layout.trickCenter * 0.1,
      layout.cardHeight * 0.95,
    );
  }

  void hideTurn() {
    if (!_sceneBuilt) return;
    _turnIndicator.hide();
  }

  // ================================================================
  // چینش مجدد دست (بعد از بازی/پخش/تغییر اندازه)
  // ================================================================

  Future<void> _relayoutHand(Seat seat, {required bool fast}) async {
    final zone = handZones[seat]!;
    final n = zone.length;
    final futures = <Future<void>>[];
    for (var i = 0; i < n; i++) {
      final comp = zone[i];
      final slot = layout.handSlot(seat, i, n);
      final scale = layout.handScale(seat);
      // لایه‌بندی: کارت‌های چپ پایین‌تر تا راست‌ترین رو باشد
      comp.priority = seat == Seat.south ? 100 + i : 20 + i;
      comp.slotIndex = i;
      comp.slotCount = n;
      futures.add(comp.animateMotion([
        MotionSegment(
          to: slot.position,
          angleTo: slot.angle,
          scaleTo: scale,
          duration: Duration(
              milliseconds: ((fast ? 150 : 240) * _speed).round()),
          curve: Curves.easeInOutCubic,
          arc: fast ? 0 : layout.cardHeight * 0.06,
        ),
      ]));
    }
    await Future.wait(futures);
  }

  /// چینش دست انسان مطابق ترتیب موتور (پس از انتخاب حکم → sortHand).
  Future<void> syncHumanHandOrder(List<PlayingCard> orderedHand) async {
    if (!_sceneBuilt) return;
    final zone = handZones[Seat.south]!;
    zone.sort((a, b) =>
        orderedHand.indexOf(a.card).compareTo(orderedHand.indexOf(b.card)));
    await _relayoutHand(Seat.south, fast: false);
  }

  // ================================================================
  // بازسازی صحنه از روی state ذخیره‌شده — بدون انیمیشن
  // ================================================================

  void rebuildFromState({
    required Map<Seat, List<PlayingCard>> hands,
    required Map<Seat, PlayingCard> centerCards,
    required Map<int, int> tricksWonByTeam,
  }) {
    if (!_sceneBuilt) return;
    resetTable();
    var parkedS = 0, parkedT1 = 0;
    final parked0 = tricksWonByTeam[0] ?? 0;
    final parked1 = tricksWonByTeam[1] ?? 0;

    // کارت‌های قبلاً برده‌شده → انبار تیم‌ها
    for (final comp in cardPool.values) {
      final inHand = hands.values.any((list) => list.contains(comp.card));
      final inCenter = centerCards.values.contains(comp.card);
      if (!inHand && !inCenter) {
        final teamIdx = (parkedS < parked0 * 4) ? 0 : 1;
        final target = layout.teamPilePosition(teamIdx);
        comp.position = target;
        comp.faceUp = false;
        comp.scale.setAll(0.0);
        comp.priority = 4;
        if (teamIdx == 0) {
          parkedS++;
        } else {
          parkedT1++;
        }
      }
    }

    // دست‌ها
    for (final seat in Seat.values) {
      final list = hands[seat]!;
      final zone = handZones[seat]!;
      for (var i = 0; i < list.length; i++) {
        final comp = cardPool[list[i].id]!;
        final slot = layout.handSlot(seat, i, list.length);
        comp
          ..position = slot.position.clone()
          ..angle = slot.angle
          ..scale = Vector2.all(layout.handScale(seat))
          ..faceUp = seat == Seat.south
          ..interactive = false
          ..playable = true
          ..priority = seat == Seat.south ? 100 + i : 20 + i;
        zone.add(comp);
      }
    }

    // مرکز
    var idx = 0;
    for (final entry in centerCards.entries) {
      final comp = cardPool[entry.value.id]!;
      final slot = layout.trickSlot(entry.key, idx);
      comp
        ..position = slot.position.clone()
        ..angle = slot.angle
        ..scale = Vector2.all(1.0)
        ..faceUp = true
        ..priority = 500 + idx;
      centerZone[entry.key] = comp;
      idx++;
    }
  }

  // ================================================================
  // Resize
  // ================================================================

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.x <= 0 || size.y <= 0) return;
    if (!_sceneBuilt) {
      _buildScene(size);
      return;
    }
    layout = TableLayout(size);
    _background.size = size.clone();
    for (final comp in cardPool.values) {
      comp.size.setValues(layout.cardWidth, layout.cardHeight);
      comp.cancelMotion();
    }
    // بازچینی استاتیک زون‌ها
    for (final seat in Seat.values) {
      final zone = handZones[seat]!;
      for (var i = 0; i < zone.length; i++) {
        final slot = layout.handSlot(seat, i, zone.length);
        zone[i]
          ..position = slot.position.clone()
          ..angle = slot.angle
          ..scale = Vector2.all(layout.handScale(seat));
      }
    }
    var idx = 0;
    for (final entry in centerZone.entries) {
      final slot = layout.trickSlot(entry.key, idx);
      entry.value..position = slot.position.clone()..angle = slot.angle;
      idx++;
    }
    for (final seat in Seat.values) {
      _nameLabels[seat]?.position = layout.namePosition(seat);
    }
  }
}

/// جلوگیری از هشدار unawaited — عمداً Future را رها می‌کنیم.
void unawaitedFuture(Future<void> future) {}
