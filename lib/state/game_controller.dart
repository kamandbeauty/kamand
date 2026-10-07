/// کنترلر بازی: موتور شلم را به رابط کاربری وصل می‌کند، نوبت ربات‌ها را
/// زمان‌بندی می‌کند و بازی را ذخیره/بازیابی می‌کند.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/bot.dart';
import '../game/engine.dart';
import '../game/rules.dart';
import '../model/card.dart';
import '../model/enums.dart';
import 'settings.dart';

const List<String> kBotNames = <String>['شما', 'نسترن', 'کامران', 'بهرام'];

class GameController extends ChangeNotifier {
  GameController({required this.settings, Random? random})
      : _random = random ?? Random();

  AppSettings settings;
  final Random _random;

  ShelemEngine? engine;
  Timer? _timer;

  /// پیام کوتاهِ وضعیت (برای نوار بالای میز).
  String? message;

  /// کارت‌هایی که بازیکن برای «کنار گذاشتن» انتخاب کرده است.
  final List<PlayingCard> selectedDiscards = <PlayingCard>[];

  /// آخرین اخطار به کاربر (مثلاً بازی کردن کارت غیرمجاز).
  String? toast;

  static const String _saveKey = 'shelem_save_v1';

  bool get hasGame => engine != null;
  bool get isHumanTurn =>
      engine != null &&
      (engine!.phase == GamePhase.playing ||
          engine!.phase == GamePhase.declaringTrump) &&
      engine!.turn == 0;

  String nameOf(int player) =>
      player == 0 ? (settings.playerName.isEmpty ? 'شما' : settings.playerName)
                  : kBotNames[player];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── شروع / ادامه ─────────────────────────────────────────────────────
  void newGame() {
    _timer?.cancel();
    final ShelemEngine e = ShelemEngine(
      config: settings.rules,
      random: _random,
    )..startRound();
    engine = e;
    message = null;
    selectedDiscards.clear();
    _save();
    notifyListeners();
    _schedule();
  }

  Future<bool> loadSavedGame() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_saveKey);
      if (raw == null) return false;
      final ShelemEngine e = ShelemEngine.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
        random: _random,
      );
      if (e.phase == GamePhase.gameOver) return false;
      engine = e;
      notifyListeners();
      _schedule();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> savedGameExists() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(_saveKey) != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _save() async {
    final ShelemEngine? e = engine;
    if (e == null) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (e.phase == GamePhase.gameOver) {
        await prefs.remove(_saveKey);
      } else {
        await prefs.setString(_saveKey, jsonEncode(e.toJson()));
      }
    } catch (_) {
      // ذخیره‌سازی بهترین‌تلاش است.
    }
  }

  void quitToMenu() {
    _timer?.cancel();
    _timer = null;
    engine = null;
    notifyListeners();
  }

  /// قوانینی که وسطِ راند تغییر کرده‌اند و باید از راند بعد اعمال شوند.
  GameConfig? _pendingRules;

  void applySettings(AppSettings next) {
    settings = next;
    final ShelemEngine? e = engine;
    if (e == null) {
      _pendingRules = null;
    } else if (e.phase == GamePhase.roundComplete ||
        e.phase == GamePhase.gameOver ||
        e.phase == GamePhase.dealing) {
      e.config = next.rules;
      _pendingRules = null;
    } else {
      // تغییرِ تعدادِ گل/جوکر وسطِ راند بازی را خراب می‌کند؛ از راند بعد.
      _pendingRules = next.rules;
    }
    next.save();
    _schedule();
    notifyListeners();
  }

  // ── کنش‌های بازیکن ───────────────────────────────────────────────────
  void humanBid(int value) {
    final ShelemEngine e = engine!;
    if (e.phase != GamePhase.bidding || e.bidder != 0) return;
    _click();
    e.placeBid(value);
    _after();
  }

  void humanPass() {
    final ShelemEngine e = engine!;
    if (e.phase != GamePhase.bidding || e.bidder != 0) return;
    if (!e.canPass) {
      toast = 'شما بالاترین خواننده‌اید و نمی‌توانید پاس بدهید';
      notifyListeners();
      return;
    }
    _click();
    e.passBid();
    _after();
  }

  void humanTakeKitty() {
    final ShelemEngine e = engine!;
    if (e.phase != GamePhase.kitty || e.hakem != 0) return;
    _click();
    e.takeKitty();
    _after();
  }

  void toggleDiscard(PlayingCard card) {
    final ShelemEngine e = engine!;
    if (e.phase != GamePhase.discarding || e.hakem != 0) return;
    if (selectedDiscards.contains(card)) {
      selectedDiscards.remove(card);
    } else {
      if (selectedDiscards.length >= e.config.kittySize) {
        toast = 'فقط ${e.config.kittySize} برگ می‌توانید کنار بگذارید';
        notifyListeners();
        return;
      }
      selectedDiscards.add(card);
    }
    _click();
    notifyListeners();
  }

  void confirmDiscards() {
    final ShelemEngine e = engine!;
    if (selectedDiscards.length != e.config.kittySize) {
      toast = 'باید دقیقاً ${e.config.kittySize} برگ انتخاب کنید';
      notifyListeners();
      return;
    }
    _click();
    e.discardCards(List<PlayingCard>.of(selectedDiscards));
    selectedDiscards.clear();
    _after();
  }

  void humanDeclareTrump(Suit suit) {
    final ShelemEngine e = engine!;
    if (e.awaitingJokerTrump) {
      e.declareTrumpSuit(suit);
    } else if (e.phase == GamePhase.declaringTrump) {
      e.declareTrumpBeforeLead(suit);
    } else {
      return;
    }
    _click();
    _after();
  }

  void humanPlay(PlayingCard card) {
    final ShelemEngine e = engine!;
    if (!isHumanTurn) {
      toast = 'نوبت شما نیست';
      notifyListeners();
      return;
    }
    if (!e.canPlay(0, card)) {
      final Suit? lead = e.trick.isEmpty ? null : e.leadSuit;
      toast = e.mustLeadTrumpFirst
          ? 'اولین برگِ حاکم باید از خالِ حکم باشد'
          : (lead != null
              ? 'باید از خالِ ${lead.fa} بازی کنید'
              : 'این کارت مجاز نیست');
      if (settings.haptics) HapticFeedback.heavyImpact();
      notifyListeners();
      return;
    }
    if (e.phase == GamePhase.declaringTrump && card.isJoker) {
      // حکم باید جداگانه اعلام شود؛ رابط کاربری منوی خال را نشان می‌دهد.
      e.playCard(0, card);
      _click();
      _after();
      return;
    }
    _click();
    e.playCard(0, card);
    _after();
  }

  void nextRound() {
    final ShelemEngine e = engine!;
    if (e.phase != GamePhase.roundComplete) return;
    _click();
    if (_pendingRules != null) {
      e.config = _pendingRules!;
      _pendingRules = null;
    }
    e.startRound();
    _after();
  }

  void clearToast() {
    if (toast != null) {
      toast = null;
      notifyListeners();
    }
  }

  // ── حلقهٔ ربات‌ها ────────────────────────────────────────────────────
  void _after() {
    _save();
    notifyListeners();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final ShelemEngine? e = engine;
    if (e == null) return;
    final Duration d = settings.speed.botDelay;

    switch (e.phase) {
      case GamePhase.bidding:
        if (e.bidder != 0) {
          _timer = Timer(d, () => _run(() => _botBid(e)));
        }
      case GamePhase.kitty:
        if (e.hakem != 0) {
          _timer = Timer(d, () => _run(() {
                if (e.phase == GamePhase.kitty) e.takeKitty();
              }));
        }
      case GamePhase.discarding:
        if (e.hakem != 0) {
          _timer = Timer(d * 1.4, () => _run(() => _botDiscard(e)));
        }
      case GamePhase.declaringTrump:
        if (e.turn != 0) {
          _timer = Timer(d * 1.3, () => _run(() => _botLeadFirst(e)));
        }
      case GamePhase.playing:
        if (e.turn != 0) {
          _timer = Timer(d, () => _run(() => _botPlay(e)));
        }
      case GamePhase.trickComplete:
        _timer = Timer(d * 1.6, () => _run(() => _collect(e)));
      case GamePhase.dealing:
      case GamePhase.roundComplete:
      case GamePhase.gameOver:
        break;
    }
  }

  void _run(void Function() action) {
    final ShelemEngine? e = engine;
    if (e == null) return;
    try {
      action();
    } catch (err) {
      // هیچ خطایی نباید بازی را قفل کند: یک حرکتِ مجازِ ساده انجام می‌دهیم.
      debugPrint('خطا در نوبت ربات: $err');
      _recover(e);
    }
    _save();
    notifyListeners();
    _schedule();
  }

  /// خروج از بن‌بست: ساده‌ترین حرکتِ مجاز را انجام می‌دهد.
  void _recover(ShelemEngine e) {
    try {
      switch (e.phase) {
        case GamePhase.bidding:
          if (e.canPass) {
            e.passBid();
          } else {
            final List<int> bids = e.availableBids();
            if (bids.isNotEmpty) e.placeBid(bids.first);
          }
        case GamePhase.kitty:
          e.takeKitty();
        case GamePhase.discarding:
          e.discardCards(
            e.hands[e.hakem!].take(e.config.kittySize).toList(),
          );
        case GamePhase.declaringTrump:
        case GamePhase.playing:
          final List<PlayingCard> legal = e.legalFor(e.turn);
          if (legal.isNotEmpty) {
            final PlayingCard c = legal.first;
            e.playCard(
              e.turn,
              c,
              declaredTrump: c.isJoker ? Suit.spades : null,
            );
          }
        case GamePhase.trickComplete:
          e.collectTrick();
        case GamePhase.dealing:
        case GamePhase.roundComplete:
        case GamePhase.gameOver:
          break;
      }
    } catch (err) {
      debugPrint('بازیابی هم شکست خورد: $err');
    }
  }

  void _botBid(ShelemEngine e) {
    // وضعیت ممکن است بین زمان‌بندی و اجرای تایمر عوض شده باشد.
    if (e.phase != GamePhase.bidding || e.bidder == 0) return;
    final int? value = ShelemBot.chooseBid(
      e,
      e.bidder,
      settings.difficulty,
      rng: _random,
    );
    if (value == null || !e.canBid(value)) {
      if (e.canPass) {
        e.passBid();
      } else {
        // بالاترین خواننده است و همه هنوز پاس نداده‌اند: نوبت باید بچرخد.
        final List<int> bids = e.availableBids();
        if (bids.isNotEmpty) e.placeBid(bids.first);
      }
    } else {
      e.placeBid(value);
    }
  }

  void _botDiscard(ShelemEngine e) {
    if (e.phase != GamePhase.discarding || e.hakem == null || e.hakem == 0) {
      return;
    }
    final int hakem = e.hakem!;
    final Suit trump = ShelemBot.bestTrump(e.hands[hakem]);
    final List<PlayingCard> cards = ShelemBot.chooseDiscards(
      e.hands[hakem],
      e.config.kittySize,
      trump,
    );
    e.discardCards(cards);
  }

  void _botLeadFirst(ShelemEngine e) {
    if (e.phase != GamePhase.declaringTrump || e.turn == 0) return;
    final int p = e.turn;
    final Suit trump = ShelemBot.bestTrump(e.hands[p]);
    final List<PlayingCard> trumps = e.hands[p]
        .where((PlayingCard c) => c.suit == trump)
        .toList();
    if (trumps.isEmpty) {
      // هیچ برگی از آن خال ندارد (فقط جوکر): با جوکر اعلام می‌کند.
      final PlayingCard joker = e.hands[p].firstWhere(
        (PlayingCard c) => c.isJoker,
        orElse: () => e.hands[p].first,
      );
      e.playCard(p, joker, declaredTrump: trump);
      return;
    }
    trumps.sort((PlayingCard a, PlayingCard b) => b.rank.compareTo(a.rank));
    e.playCard(p, trumps.first);
    message = 'حکم: ${trump.fa}';
  }

  void _botPlay(ShelemEngine e) {
    if (e.phase != GamePhase.playing || e.turn == 0) return;
    final int p = e.turn;
    final PlayingCard card = ShelemBot.chooseCard(
      e,
      p,
      settings.difficulty,
      rng: _random,
    );
    e.playCard(p, card);
    if (settings.sound) SystemSound.play(SystemSoundType.click);
  }

  void _collect(ShelemEngine e) {
    if (e.phase != GamePhase.trickComplete) return;
    final int winner = trickWinner(e.trick, e.trump);
    e.collectTrick();
    if (settings.haptics && teamOf(winner) == 0) {
      HapticFeedback.lightImpact();
    }
  }

  void _click() {
    if (settings.sound) SystemSound.play(SystemSoundType.click);
    if (settings.haptics) HapticFeedback.selectionClick();
  }
}
