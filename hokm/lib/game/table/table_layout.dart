import 'dart:math' as math;

import 'package:flame/game.dart' show Vector2;

import '../../game_engine/state/game_enums.dart';

/// هندسهٔ کامل میز برای حالت عمودی موبایل.
///
/// همهٔ اندازه‌ها از [viewSize] مشتق می‌شوند تا در هر گوشی
/// (با هر نسبت تصویر) چیدمان دردسترس و متناسب بماند:
/// * دست انسان: پایین — فنِ کمان‌مانند با هم‌پوشانی
/// * یار AI: بالا (رو)، حریف‌ها: چپ/راست (ستونی)
/// * مرکز: جای دور (trick) و دستهٔ کارت
class TableLayout {
  TableLayout(this.viewSize) {
    final w = viewSize.x;
    final h = viewSize.y;

    // کارت: عرض بر اساس عرض صفحه — ۱۳ کارت با هم‌پوشانی در دست انسان جا شوند.
    cardWidth = (w * 0.17).clamp(46.0, 78.0).toDouble();
    cardHeight = cardWidth / cardAspect;

    // مرکز دور
    trickCenter = Vector2(w / 2, h * 0.43);
    trickRadius = cardHeight * 0.62;

    // دست انسان
    humanHandCenter = Vector2(w / 2, h - cardHeight * 0.62 - 6);
    humanStep = math.min(cardWidth * 0.40, (w - cardWidth - 28) / 12);
    humanArcHeight = cardWidth * 0.16;

    // دست یار (بالا)
    northHandCenter = Vector2(w / 2, cardHeight * 0.42 + 44);
    northStep = cardWidth * 0.30;
    northScale = 0.72;

    // ستون‌های حریف‌ها
    backScale = 0.66;
    westHandCenter = Vector2(cardHeight * 0.36 * backScale + 8, h * 0.40);
    eastHandCenter = Vector2(w - cardHeight * 0.36 * backScale - 8, h * 0.40);
    sideStep = cardWidth * 0.26;

    // دکه (وسط میز — زمان بر و پخش)
    deckCenter = trickCenter.clone()..y -= cardHeight * 0.05;

    // محل نام‌ها
    nameOffsets = {
      Seat.south: Vector2(0, -cardHeight * 0.98),
      Seat.north: Vector2(0, cardHeight * 0.62),
      Seat.west: Vector2(cardHeight * 0.52, 0),
      Seat.east: Vector2(-cardHeight * 0.52, 0),
    };

    // جای انباشت دورهای بردهٔ هر تیم (گوشه‌ها)
    teamPile = {
      0: Vector2(w - 44, h - cardHeight - 66), // تیم انسان — راست پایین
      1: Vector2(44, cardHeight * 0.55 + 70), // تیم حریف — چپ بالا
    };
  }

  /// نسبت طول به عرض کارت استاندارد.
  static const double cardAspect = 63.5 / 88.9;

  final Vector2 viewSize;

  late final double cardWidth;
  late final double cardHeight;

  late final Vector2 trickCenter;
  late final double trickRadius;

  late final Vector2 humanHandCenter;
  late final double humanStep;
  late final double humanArcHeight;

  late final Vector2 northHandCenter;
  late final double northStep;
  late final double northScale;

  late final Vector2 westHandCenter;
  late final Vector2 eastHandCenter;
  late final double sideStep;
  late final double backScale;

  late final Vector2 deckCenter;

  late final Map<Seat, Vector2> nameOffsets;
  late final Map<int, Vector2> teamPile;

  // ---------- نقاط کلیدی ----------

  /// مرکز جایگاه هر نفر روی دورِ میز.
  Vector2 seatAnchor(Seat seat) => switch (seat) {
        Seat.south => humanHandCenter,
        Seat.north => northHandCenter,
        Seat.west => westHandCenter,
        Seat.east => eastHandCenter,
      };

  /// موقعیت دقیق کارتِ iام (از n) در دست انسان.
  ({Vector2 position, double angle}) humanHandSlot(int i, int n) {
    final mid = (n - 1) / 2.0;
    final offset = i - mid;
    final x = humanHandCenter.x + offset * humanStep;
    final y = humanHandCenter.y +
        (offset * offset / math.max(mid * mid, 1)) * humanArcHeight;
    final angle = offset * 0.038; // فن ملایم — حدود ±۸ درجه
    return (position: Vector2(x, y), angle: angle);
  }

  ({Vector2 position, double angle}) northHandSlot(int i, int n) {
    final mid = (n - 1) / 2.0;
    final x = northHandCenter.x + (i - mid) * northStep;
    return (position: Vector2(x, northHandCenter.y), angle: 0.0);
  }

  ({Vector2 position, double angle}) westHandSlot(int i, int n) {
    final mid = (n - 1) / 2.0;
    final y = westHandCenter.y + (i - mid) * sideStep;
    return (
      position: Vector2(westHandCenter.x, y),
      angle: -math.pi / 2,
    );
  }

  ({Vector2 position, double angle}) eastHandSlot(int i, int n) {
    final mid = (n - 1) / 2.0;
    final y = eastHandCenter.y + (i - mid) * sideStep;
    return (
      position: Vector2(eastHandCenter.x, y),
      angle: math.pi / 2,
    );
  }

  ({Vector2 position, double angle}) handSlot(Seat seat, int i, int n) =>
      switch (seat) {
        Seat.south => humanHandSlot(i, n),
        Seat.north => northHandSlot(i, n),
        Seat.west => westHandSlot(i, n),
        Seat.east => eastHandSlot(i, n),
      };

  /// مقیاس کارت در دست هر جایگاه (دست‌های «رو» کوچک‌ترند).
  double handScale(Seat seat) => switch (seat) {
        Seat.south => 1.0,
        Seat.north => northScale,
        Seat.west || Seat.east => backScale,
      };

  /// جای کارتِ بازی‌شدهٔ هر جایگاه در مرکز میز.
  ({Vector2 position, double angle}) trickSlot(Seat seat, int playIndex) {
    final base = switch (seat) {
      Seat.south => Vector2(0, trickRadius),
      Seat.north => Vector2(0, -trickRadius),
      Seat.west => Vector2(-trickRadius * 1.25, 0),
      Seat.east => Vector2(trickRadius * 1.25, 0),
    };
    // چرخش ارگانیکِ کم برای حس طبیعی — قطعی بر اساس جایگاه و ترتیب بازی.
    final wobble = ((seat.index + 1) * 137 + playIndex * 61) % 11 - 5;
    return (
      position: trickCenter + base,
      angle: wobble * math.pi / 180,
    );
  }

  /// جای نام بازیکن.
  Vector2 namePosition(Seat seat) => seatAnchor(seat) + nameOffsets[seat]!;

  /// هدف پرواز دورِ برده‌شده (انبار هر تیم).
  Vector2 teamPilePosition(int teamIndex) => teamPile[teamIndex]!;
}
