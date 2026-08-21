import 'dart:math' as math;
import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/painting.dart'
    show TextPainter, TextSpan, TextStyle;

import '../game_engine/managers/deal_manager.dart';
import '../game_engine/managers/hukum_manager.dart';
import '../game_engine/models/playing_card.dart';
import '../game_engine/state/game_enums.dart';
import '../storage/settings_model.dart';
import 'art/game_art.dart';
import 'components/card_component.dart';
import 'components/table_background.dart';
import 'components/hakim_crown.dart';
import 'components/trick_badge.dart';
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

  /// پشته‌های دست‌های بردهٔ هر بازیکن (جلوی خودش) — هر دست ۴ کارت.
  final Map<Seat, List<CardComponent>> trickPiles = {
    for (final s in Seat.values) s: <CardComponent>[],
  };

  /// نشان‌های شمارندهٔ دست جلوی هر بازیکن.
  final Map<Seat, TrickBadge> _trickBadges = {};

  /// رویداد لمس کارت انسان (توسط GameController ست می‌شود).
  void Function(PlayingCard card)? onHumanCardTapped;

  final math.Random _rng = math.Random();

  // ================================================================
  // راه‌اندازی
  // ================================================================

  bool _sceneBuilt = false;

  /// اگر ساخت صحنه شکست بخورد، متن خطا را روی بوم نشان می‌دهیم تا
  /// کاربر به‌جای صفحهٔ خاکستریِ بی‌معنا، خودِ خطا را ببیند و گزارش کند.
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final err = lastSceneError;
    if (err == null) return;
    final w = hasLayout ? canvasSize.x : 320.0;
    final tp = TextPainter(
      text: TextSpan(
        text: 'Scene build error:\n$err',
        style: const TextStyle(
          color: Color(0xFFFF9090),
          fontSize: 13,
          height: 1.35,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 8,
      ellipsis: '…',
    )..layout(maxWidth: w * 0.9);
    canvas.drawRect(
      Rect.fromLTWH(0, 120, w, tp.height + 28),
      Paint()..color = const Color(0xCC1A0408),
    );
    tp.paint(canvas, Offset(w * 0.05, 134));
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // تصاویر اختیاری (بک‌گراند/پشت کارت) — نبودشان مجاز و بی‌اثر است.
    try {
      await GameArt.instance.load();
    } on Object catch (e) {
      debugPrint('GameArt load failed (procedural fallback): $e');
    }
    // اگر اندازه همین حالا معلوم است، صحنه را بساز؛ در غیر این صورت
    // اولین onGameResize آن را می‌سازد.
    if (size.x > 0 && size.y > 0) _buildScene(size);
  }

  /// آخرین خطای ساخت صحنه (برای عیب‌یابی — در logcat هم چاپ می‌شود).
  Object? lastSceneError;

  void _buildScene(Vector2 viewSize) {
    if (_sceneBuilt) return;
    try {
      _buildSceneUnsafe(viewSize);
      _sceneBuilt = true;
      _lastSize = viewSize.clone();
    } on Object catch (e, st) {
      // ساخت ناموفق صحنه نباید اپ را بشکند؛ پایان‌نیافتن _sceneBuilt
      // باعث تلاش دوباره در resize بعدی می‌شود.
      lastSceneError = e;
      debugPrint('HokmGame._buildScene failed: $e\n$st');
    }
  }

  void _buildSceneUnsafe(Vector2 viewSize) {
    layout = TableLayout(viewSize);
    palette = TablePalette.of(_settings.tableTheme);

    _background = TableBackground(palette: palette)
      ..size = viewSize.clone()
      ..position = Vector2.zero()
      ..priority = 0
      ..feltImage = GameArt.instance.tableImage(_settings.tableTheme);
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
          onTapped: (c) {
            debugComponentTapCount++;
            onHumanCardTapped?.call(c);
          },
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

  /// نشان «حاکم» کنار نام — تاجِ طلایی بالای نام (پس از انتخاب حکم ظاهر می‌شود).
  void setHakimBadge(Seat? seat) {
    if (!_sceneBuilt) return;
    for (final badge in _hakimBadges.values) {
      badge.removeFromParent();
    }
    _hakimBadges.clear();
    if (seat == null) return;
    final base = layout.namePosition(seat);
    final crownOffset = seat == Seat.south
        ? Vector2(0, -30)
        : seat == Seat.north
            ? Vector2(0, 18)
            : Vector2(0, -14);
    final crown = HakimCrown(gold: palette.accent)
      ..position = base + crownOffset
      ..priority = 3;
    final label = TextComponent(
      text: 'حاکم',
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: 'VazirmatnFD',
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: palette.accent,
        ),
      ),
    )
      ..anchor = Anchor.center
      ..position = Vector2(15, 27) // زیر بدنهٔ تاج (مختصات محلی تاج)
      ..priority = 3;
    crown.add(label);
    _hakimBadges[seat] = crown;
    add(crown);
  }

  // ================================================================
  // تنظیمات زنده
  // ================================================================

  bool get isSceneReady => _sceneBuilt;

  // ================================================================
  // پایش و نگهبان (دیباگ CI + محافظت در برابر گیرکردن انیمیشن)
  // ================================================================

  /// شمارندهٔ تیک‌های حلقهٔ بازی (برای تست‌ها و عیب‌یابی زنده).
  int debugUpdateTickCount = 0;

  /// آخرین dt دریافتی از حلقهٔ Flame.
  double debugLastDt = 0;

  /// تعداد کارت‌هایی که هنوز در صف حرکت‌اند.
  int get debugMovingCards => cardPool.values.where((c) => c.isMoving).length;

  /// شمارندهٔ لمس‌های رسیده به کامپوننت کارت (دیباگ مسیر hit-test).
  int debugComponentTapCount = 0;

  @override
  void update(double dt) {
    super.update(dt);
    debugUpdateTickCount++;
    debugLastDt = dt;
  }

  /// خاتمهٔ اجباری همهٔ حرکت‌های در جریان — نگهبانِ انیمیشنِ کنترلر
  /// از این استفاده می‌کند تا حتی اگر صفِ حرکتِ کارتی به هر دلیلی
  /// تکان نخورد، جریان منطقی مسابقه هرگز برای همیشه قفل نشود.
  /// انیمیشن‌ها تزئینی‌اند؛ قانون بازی هرگز نباید گروگانِ آن‌ها باشد.
  void cancelAllMotions({bool jumpToEnd = true}) {
    for (final comp in cardPool.values) {
      comp.cancelMotion(jumpToEnd: jumpToEnd);
    }
  }

  /// جلو بردنِ دستیِ فقط صف‌های حرکت کارت‌ها به میزانِ [dtSeconds].
  /// مخصوص محیط‌های تستی است که حلقهٔ Flame تیک نمی‌زند؛ عمداً
  /// updateTree صدا زده نمی‌شود تا افزودن/حذف کامپوننت‌ها یا تغییر
  /// اولویت‌ها در میانهٔ پیمایش تداخلی ایجاد نکند.
  void stepMotionsManually(double dtSeconds) {
    for (final comp in cardPool.values) {
      comp.updateMotion(dtSeconds);
    }
  }

  void applySettings(SettingsModel settings) {
    _settings = settings;
    if (!_sceneBuilt) return;
    palette = TablePalette.of(settings.tableTheme);
    _background.palette = palette;
    _background.feltImage = GameArt.instance.tableImage(settings.tableTheme);
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
    for (final pile in trickPiles.values) {
      pile.clear();
    }
    for (final badge in _trickBadges.values) {
      badge.removeFromParent();
    }
    _trickBadges.clear();
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
        ..winner = false
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
    // بسیار مهم: زون‌ها و پشته‌های دست قبل باید پاک شوند؛
    // وگرنه از دستِ دوم به بعد چیدمان روی بقایای دست قبلی به‌هم می‌ریزد.
    resetTable();

    final all = cardPool.values.toList();

    // ۱) هجوم کارت‌ها از چهار سمت به مرکز — با قوسِ بلند و چرخشِ آزاد
    final futures = <Future<void>>[];
    for (var i = 0; i < all.length; i++) {
      final comp = all[i];
      comp.faceUp = false;
      comp.scale.setAll(0.62);
      comp.priority = 40 + i;
      final from = switch (i % 4) {
        0 => Vector2(
            layout.viewSize.x / 2, layout.viewSize.y + layout.cardHeight),
        1 => Vector2(layout.viewSize.x / 2, -layout.cardHeight),
        2 =>
          Vector2(-layout.cardWidth, layout.viewSize.y * (0.25 + (i % 5) * 0.1)),
        _ => Vector2(layout.viewSize.x + layout.cardWidth,
            layout.viewSize.y * (0.25 + (i % 5) * 0.1)),
      };
      comp.position = from;
      comp.angle = (_rng.nextDouble() * 30 - 15) * math.pi / 180;
      futures.add(comp.animateMotion([
        MotionSegment(
          to: layout.deckCenter +
              Vector2(_rng.nextDouble() * 10 - 5, _rng.nextDouble() * 8 - 4),
          angleTo: (_rng.nextDouble() * 10 - 5) * math.pi / 180,
          duration: Duration(
              milliseconds: ((380 + (i % 8) * 34) * _speed).round()),
          curve: HokmCurves.deal,
          arc: layout.cardHeight * 0.5,
        ),
      ]));
      if (i % 10 == 9) {
        await Future.wait(futures);
        futures.clear();
      }
    }
    await Future.wait(futures);

    // ۲) مربع‌شدنِ دکه با برخوردِ نرم (تقِ بازیگر)
    await Future.wait(all.map((c) => c.animateMotion([
          MotionSegment(
            to: layout.deckCenter,
            angleTo: 0,
            duration: Duration(milliseconds: (200 * _speed).round()),
            curve: Curves.easeOutBack,
          ),
        ])));

    // ۳) دو نیم‌دسته × ۲ بار — شکافت بلند + ریفلِ زیگزاگی
    for (var round = 0; round < 2; round++) {
      final halfNo = all.length ~/ 2;
      final left = all.sublist(0, halfNo);
      final right = all.sublist(halfNo);
      final offset = layout.cardWidth * 0.95;
      final gap = layout.cardHeight * 0.14;

      // شکافتن دو نیم‌دسته با خیز (دسته‌ها از روی میز بلند می‌شوند)
      final splitFutures = <Future<void>>[];
      for (final c in left) {
        splitFutures.add(c.animateMotion([
          MotionSegment(
            to: layout.deckCenter + Vector2(-offset, -gap * 0.4),
            angleTo: -7 * math.pi / 180,
            scaleTo: 0.66,
            duration: Duration(milliseconds: (280 * _speed).round()),
            curve: HokmCurves.snatch,
            arc: gap * 1.4,
          ),
        ]));
      }
      for (final c in right) {
        splitFutures.add(c.animateMotion([
          MotionSegment(
            to: layout.deckCenter + Vector2(offset, -gap * 0.4),
            angleTo: 7 * math.pi / 180,
            scaleTo: 0.66,
            duration: Duration(milliseconds: (280 * _speed).round()),
            curve: HokmCurves.snatch,
            arc: gap * 1.4,
          ),
        ]));
      }
      await Future.wait(splitFutures);
      await Future<void>.delayed(Duration(milliseconds: (90 * _speed).round()));

      // درهم‌رفتن (ریفل) — زیگزاگ با پرش‌های ریز
      final riffleFutures = <Future<void>>[];
      for (var i = 0; i < halfNo; i++) {
        final fromLeft = left[i];
        final fromRight = (i < right.length) ? right[i] : null;
        final zig = (i % 2 == 0 ? -1.0 : 1.0) * layout.cardWidth * 0.05;
        riffleFutures.add(fromLeft.animateMotion([
          MotionSegment(
            to: layout.deckCenter + Vector2(zig, (i * 0.55)),
            angleTo: 0,
            scaleTo: 0.62,
            duration: Duration(
                milliseconds: ((170 + i * 6) * _speed).round()),
            curve: Curves.easeOutCubic,
            arc: layout.cardHeight * 0.12,
          ),
        ]));
        if (fromRight != null) {
          riffleFutures.add(fromRight.animateMotion([
            MotionSegment(
              to: layout.deckCenter + Vector2(-zig, (i * 0.55) + 0.9),
              angleTo: 0,
              scaleTo: 0.62,
              duration: Duration(
                  milliseconds: ((185 + i * 6) * _speed).round()),
              curve: Curves.easeOutCubic,
              arc: layout.cardHeight * 0.12,
            ),
          ]));
        }
      }
      await Future.wait(riffleFutures);
    }

    // ۴) بریدن دکه — نیمهٔ بالا می‌پرد کنار، نیمهٔ پایین می‌نشیند زیرش
    {
      final halfNo = all.length ~/ 2;
      final topHalf = all.sublist(0, halfNo);
      final bottomHalf = all.sublist(halfNo);
      final cutGap = layout.cardWidth * 1.15;
      final cutFutures = <Future<void>>[
        for (final c in topHalf)
          c.animateMotion([
            MotionSegment(
              to: layout.deckCenter + Vector2(-cutGap, -layout.cardHeight * 0.12),
              angleTo: -5 * math.pi / 180,
              duration: Duration(milliseconds: (240 * _speed).round()),
              curve: HokmCurves.snatch,
              arc: layout.cardHeight * 0.4,
            ),
          ]),
        for (final c in bottomHalf)
          c.animateMotion([
            MotionSegment(
              to: layout.deckCenter + Vector2(cutGap * 0.9, 0),
              angleTo: 2 * math.pi / 180,
              duration: Duration(milliseconds: (240 * _speed).round()),
              curve: Curves.easeInOutCubic,
              arc: layout.cardHeight * 0.10,
            ),
          ]),
      ];
      await Future.wait(cutFutures);
      await Future<void>.delayed(Duration(milliseconds: (60 * _speed).round()));
      // برگشت نیمهٔ بلندشده روی نیمهٔ دیگر (کات کامل می‌شود)
      await Future.wait(topHalf.map((c) => c.animateMotion([
            MotionSegment(
              to: layout.deckCenter + Vector2(cutGap * 0.9, -1.2),
              angleTo: 0,
              duration: Duration(milliseconds: (220 * _speed).round()),
              curve: HokmCurves.settle,
              arc: layout.cardHeight * 0.22,
            ),
          ])));
    }

    // ۵) مربع نهایی + نشست نرم + جرقهٔ ظریف زر روی دکه
    await Future.wait(all.map((c) => c.animateMotion([
          MotionSegment(
            to: layout.deckCenter,
            angleTo: 0,
            scaleTo: 0.62,
            duration: Duration(milliseconds: (210 * _speed).round()),
            curve: HokmCurves.settle,
          ),
        ])));
    add(WinGlowPulse(
      center: layout.deckCenter,
      color: palette.accent,
      maxRadius: layout.cardWidth * 0.9,
      sparkCount: 8,
    ));

    // تنظیم ترتیب اولویت دکه (بالای دکه = آخرین کارت)
    var pr = 10;
    for (final c in all) {
      c.priority = pr++;
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
        unawaitedFuture(_flyAndLand(comp, slot, scale, isFaceUp, dealIndex));
        zone.add(comp);
        // ریتم آرام‌تر — دست‌دادن باید دیده شود (۵→۴→۴)
        await Future<void>.delayed(
            Duration(milliseconds: (105 * _speed).round() + (dealIndex % 3) * 12));
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

  /// پروازِ یک کارت از دکه به جایش در دست — قوس بلند، پیچش ملایم در مسیر،
  /// «نشستِ نرم» دو مرحله‌ای، و برای کارت‌های انسان یک فلیپِ سه‌بعدی‌نما.
  Future<void> _flyAndLand(CardComponent comp,
      ({Vector2 position, double angle}) slot, double scale,
      bool faceUp, int dealIndex) async {
    // پیچش کوچکِ قطعی در میانهٔ راه — حس پرتاب ورق به‌جای رباتیک
    final wobble = ((dealIndex * 37) % 9 - 4) * 0.016;
    await comp.animateMotion([
      MotionSegment(
        to: slot.position + Vector2(0, -layout.cardHeight * 0.05),
        angleTo: (slot.angle + wobble),
        scaleTo: scale * 1.04,
        duration: Duration(milliseconds: (330 * _speed).round()),
        curve: HokmCurves.deal,
        arc: layout.cardHeight * 0.72,
      ),
      // نشست نرم — کمی رد شدن از هدف و برگشت
      MotionSegment(
        to: slot.position,
        angleTo: slot.angle,
        scaleTo: scale,
        duration: Duration(milliseconds: (130 * _speed).round()),
        curve: HokmCurves.settle,
      ),
    ]);
    // کارت‌های انسان: رو شدن با فلیپِ سه‌بعدی‌نما + برقِ ظریف
    if (faceUp) {
      await comp.flip(
        duration: Duration(milliseconds: (300 * _speed).round()),
        onHalf: () => comp.faceUp = true,
      );
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

    // برقِ ورق‌طلا روی کارت برندهٔ دست
    centerZone[winner]?.winner = true;

    add(WinGlowPulse(
      center: layout.seatAnchor(winner) * 0.82 + layout.trickCenter * 0.18,
      color: palette.accent,
      maxRadius: layout.cardHeight * 0.8,
    ));

    // مقصد: پشتهٔ جلوی خودِ برنده (نه گوشهٔ تیم) — هر دست ۴ کارتِ
    // کوچک که مورب روی هم می‌نشینند تا ضخامت پشته دیده شود.
    final pile = trickPiles[winner]!;
    final trickIndex = pile.length ~/ 4; // شمارهٔ این دست (۰میلادی)
    final base = layout.seatPilePosition(winner);
    final futures = <Future<void>>[];
    var i = 0;
    for (final comp in centerZone.values) {
      _bringToFront(comp, 600 + i);
      futures.add(comp.animateMotion([
        MotionSegment(
          to: base + layout.pileCardOffset(trickIndex, i),
          angleTo: 0,
          scaleTo: layout.pileScale,
          duration: Duration(milliseconds: (380 * _speed).round()),
          curve: Curves.easeInOutCubic,
          arc: layout.cardHeight * 0.3,
        ),
      ]));
      i++;
    }
    await Future.wait(futures);
    // پارک کارت‌ها به‌صورت قابل‌مشاهده در پشتهٔ برنده (پشتِ کارت کوچک)
    i = 0;
    for (final comp in centerZone.values) {
      comp
        ..faceUp = false
        ..winner = false
        ..priority = 40 + trickIndex;
      pile.add(comp);
      i++;
    }
    centerZone.clear();
    // نشان شمارندهٔ برد جلوی برنده تپش می‌زند و عددش زیاد می‌شود.
    _ensureBadge(winner).bump(trickIndex + 1);
    await Future<void>.delayed(Duration(milliseconds: (120 * _speed).round()));
  }

  /// جای نشان شمارنده — بالا-راستِ پشتهٔ کوچک جلوی بازیکن.
  Vector2 _badgePosition(Seat seat) =>
      layout.seatPilePosition(seat) +
      Vector2(layout.cardWidth * layout.pileScale * 0.95,
          -layout.cardHeight * layout.pileScale * 0.85);

  /// نشان شمارندهٔ هر جایگاه را (در صورت نبودن) می‌سازد و برمی‌گرداند.
  TrickBadge _ensureBadge(Seat seat) {
    var badge = _trickBadges[seat];
    if (badge == null) {
      badge = TrickBadge(accent: palette.accent)
        ..size = Vector2.all(24)
        ..anchor = Anchor.center
        ..priority = 750
        ..position = _badgePosition(seat);
      _trickBadges[seat] = badge;
      add(badge);
    }
    return badge;
  }

  /// جشنِ بردن دست (دور): موج نور روی پشته‌های تیم برنده + تپش نشان‌ها.
  /// درست پیش از نمایش برگهٔ نتیجهٔ دست صدا زده می‌شود.
  void celebrateRoundWinner(int winnerTeamIndex) {
    if (!_sceneBuilt) return;
    for (final seat in Seat.values) {
      if (seat.teamIndex != winnerTeamIndex) continue;
      add(WinGlowPulse(
        center: layout.seatPilePosition(seat),
        color: palette.accent,
        maxRadius: layout.cardWidth * 1.15,
        sparkCount: 10,
      ));
      final badge = _trickBadges[seat];
      if (badge != null && badge.count > 0) badge.bump(badge.count);
    }
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
    // کارت‌های قبلاً برده‌شده → پشتهٔ هر بازیکن (۴ کارت به ازای هر دست).
    // state فقط تعداد دست‌های «تیم» را می‌داند؛ برای نمایش، دست‌ها بین
    // دو یار تقسیم می‌شوند (تیم انسان را جلوی south/north نشان می‌دهیم).
    const teamSeats = {
      0: [Seat.south, Seat.north],
      1: [Seat.west, Seat.east],
    };
    var parked = 0;
    final limitTeam0 = (tricksWonByTeam[0] ?? 0) * 4;

    for (final comp in cardPool.values) {
      final inHand = hands.values.any((list) => list.contains(comp.card));
      final inCenter = centerCards.values.contains(comp.card);
      if (!inHand && !inCenter) {
        final teamIdx = (parked < limitTeam0) ? 0 : 1;
        final inTeam = teamIdx == 0 ? parked : parked - limitTeam0;
        final tricks = tricksWonByTeam[teamIdx] ?? 0;
        final firstTricks = (tricks + 1) ~/ 2; // سهم بازیکن اول تیم
        final trickIndex = inTeam ~/ 4;
        final seat = teamSeats[teamIdx]![trickIndex < firstTricks ? 0 : 1];
        final localTrick =
            trickIndex < firstTricks ? trickIndex : trickIndex - firstTricks;
        comp
          ..position = layout.seatPilePosition(seat) +
              layout.pileCardOffset(localTrick, inTeam % 4)
          ..faceUp = false
          ..scale = Vector2.all(layout.pileScale)
          ..priority = 40 + localTrick;
        trickPiles[seat]!.add(comp);
        parked++;
      }
    }
    // نشان‌های شمارنده روی پشته‌های بازسازی‌شده
    for (final seat in Seat.values) {
      final count = trickPiles[seat]!.length ~/ 4;
      if (count > 0) _ensureBadge(seat).bump(count);
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

  Vector2? _lastSize;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.x <= 0 || size.y <= 0) return;
    if (!_sceneBuilt) {
      _buildScene(size);
      return;
    }
    // GameWidget در هر build این متد را صدا می‌زند؛ اگر اندازه تغییر
    // نکرده باشد (مثلاً HUD به‌روزرسانی شده) نباید چیدمان و حرکت‌ها
    // خراب شوند — بازچینی فقط هنگام تغییر واقعی اندازه.
    final last = _lastSize;
    if (last != null &&
        (last.x - size.x).abs() < 0.5 &&
        (last.y - size.y).abs() < 0.5) {
      return;
    }
    _lastSize = size.clone();
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
    // پشته‌های برده و نشان‌های شمارنده
    for (final seat in Seat.values) {
      final pile = trickPiles[seat]!;
      for (var j = 0; j < pile.length; j++) {
        pile[j].position =
            layout.seatPilePosition(seat) + layout.pileCardOffset(j ~/ 4, j % 4);
      }
      final badge = _trickBadges[seat];
      if (badge != null) badge.position = _badgePosition(seat);
    }
    for (final seat in Seat.values) {
      _nameLabels[seat]?.position = layout.namePosition(seat);
    }
  }
}

/// جلوگیری از هشدار unawaited — عمداً Future را رها می‌کنیم.
void unawaitedFuture(Future<void> future) {}
