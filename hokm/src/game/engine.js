// ---------------------------------------------------------------------------
// موتور بازی حکم — تمام قوانین رسمی
//
// نشستن بازیکنان (خلاف عقربه‌های ساعت):
//   0 = شما (پایین)   1 = حریف راست   2 = یار شما (بالا)   3 = حریف چپ
//   تیم ۰ = بازیکن‌های ۰ و ۲   |   تیم ۱ = بازیکن‌های ۱ و ۳
//
// فازها:
//   idle → hakemDeal → hakemFound → chooseTrump → dealing → playing
//        → trickEnd → roundEnd → gameEnd
// ---------------------------------------------------------------------------

import {
  makeDeck, shuffle, sortHand, legalCards, trickWinnerIndex, SUITS,
} from './cards.js';

export const TEAM_OF = [0, 1, 0, 1];
export const NEXT = (i) => (i + 1) % 4;

export const DEFAULT_SETTINGS = {
  playerName: 'شما',
  speed: 'normal',            // slow | normal | fast
  sound: true,
  difficulty: 'hard',         // easy | normal | hard
  cardBack: 'back-red',
  surface: 'carpet-red',
  // قوانین
  targetMode: 'points',       // points = تا رسیدن به امتیاز هدف | rounds = تعداد راند ثابت
  targetPoints: 7,
  targetRounds: 10,
  kotEnabled: true,           // کت (۷ بر صفر) = ۲ امتیاز
  hakemKotEnabled: true,      // کت کردنِ حاکم توسط تیم مقابل = ۳ امتیاز
  showHints: true,            // هایلایت کارت‌های مجاز
  sortHand: true,
};

export const PLAYER_NAMES = ['شما', 'نسترن', 'کامران', 'بهرام'];

export function initialState(settings = DEFAULT_SETTINGS) {
  return {
    phase: 'idle',
    settings: { ...DEFAULT_SETTINGS, ...settings },
    players: [0, 1, 2, 3].map((i) => ({
      index: i,
      name: i === 0 ? (settings.playerName || 'شما') : PLAYER_NAMES[i],
      team: TEAM_OF[i],
      hand: [],
    })),
    deck: [],
    hakem: null,
    firstHakemDecided: false,
    trump: null,
    turn: null,
    leader: null,
    trick: [],              // [{player, card}]
    lastTrick: null,        // {cards:[{player,card}], winner, leader}
    tricksWon: [0, 0],      // تعداد دست‌های برده‌ی هر تیم در راند جاری
    trickPiles: [[], []],   // کارت‌های جمع‌شده‌ی هر تیم
    roundTricks: [],        // تمام دست‌های کامل‌شده‌ی راند جاری
    scores: [0, 0],
    round: 0,
    hakemReveal: [],        // کارت‌های رو شده در مرحله‌ی تعیین حاکم
    hakemRevealTurn: null,
    history: [],            // سابقه‌ی راندها برای جدول امتیاز
    roundResult: null,      // {winnerTeam, points, kot, hakemKot, tricks:[a,b]}
    gameResult: null,       // {winnerTeam}
    message: null,
    // حافظه‌ی هوش مصنوعی
    seen: [],               // آی‌دی تمام کارت‌های بازی شده در راند جاری
    voids: [{}, {}, {}, {}],// voids[p][suit] = true یعنی بازیکن p از آن خال ندارد
    stats: { gamesPlayed: 0 },
  };
}

// ---------------------------------------------------------------------------
// شروع بازی جدید
// ---------------------------------------------------------------------------
export function newGame(settings) {
  const st = initialState(settings);
  st.phase = 'hakemDeal';
  st.deck = shuffle(makeDeck());
  st.hakemRevealTurn = Math.floor(Math.random() * 4); // کارت‌پخش‌کن تصادفی
  st.message = 'تعیین حاکم: اولین بازیکنی که آس بیاورد حاکم می‌شود';
  return st;
}

/** یک کارت در مرحله‌ی تعیین حاکم رو می‌کند */
export function hakemDealStep(state) {
  const st = clone(state);
  const card = st.deck.pop();
  const player = st.hakemRevealTurn;
  st.hakemReveal.push({ player, card });
  if (card.r === 14) {
    st.hakem = player;
    st.firstHakemDecided = true;
    st.phase = 'hakemFound';
    st.message = `${st.players[player].name} حاکم شد`;
  } else {
    st.hakemRevealTurn = NEXT(player);
  }
  return st;
}

/** پخش ۵ کارت اول به حاکم تا حکم را تعیین کند */
export function startRound(state, hakemIndex) {
  const st = clone(state);
  st.round += 1;
  st.hakem = hakemIndex;
  st.trump = null;
  st.trick = [];
  st.lastTrick = null;
  st.tricksWon = [0, 0];
  st.trickPiles = [[], []];
  st.roundTricks = [];
  st.seen = [];
  st.voids = [{}, {}, {}, {}];
  st.roundResult = null;
  st.hakemReveal = [];
  st.deck = shuffle(makeDeck());
  st.players.forEach((p) => { p.hand = []; });
  // حاکم ۵ کارت اول را می‌گیرد
  for (let i = 0; i < 5; i++) st.players[hakemIndex].hand.push(st.deck.pop());
  st.players[hakemIndex].hand = sortHand(st.players[hakemIndex].hand, null);
  st.phase = 'chooseTrump';
  st.turn = hakemIndex;
  st.message = hakemIndex === 0
    ? 'حکم را انتخاب کنید'
    : `${st.players[hakemIndex].name} در حال انتخاب حکم است...`;
  return st;
}

/** حاکم حکم را اعلام می‌کند */
export function chooseTrump(state, suit) {
  const st = clone(state);
  st.trump = suit;
  st.phase = 'dealing';
  st.message = null;
  return st;
}

/**
 * پخش بقیه‌ی کارت‌ها: ابتدا به بقیه ۵ تا، سپس دور ۴ تایی و دور ۴ تایی
 * در پایان هر بازیکن ۱۳ کارت دارد.
 */
export function dealRest(state) {
  const st = clone(state);
  const h = st.hakem;
  // ۵ کارت اول برای سه بازیکن دیگر
  for (let k = 1; k <= 3; k++) {
    const p = (h + k) % 4;
    for (let i = 0; i < 5; i++) st.players[p].hand.push(st.deck.pop());
  }
  // دو دور ۴ تایی برای همه (شروع از حاکم)
  for (let round = 0; round < 2; round++) {
    for (let k = 0; k < 4; k++) {
      const p = (h + k) % 4;
      for (let i = 0; i < 4; i++) st.players[p].hand.push(st.deck.pop());
    }
  }
  st.players.forEach((p) => { p.hand = sortHand(p.hand, st.trump); });
  st.phase = 'playing';
  st.leader = h;           // دست اول را حاکم شروع می‌کند
  st.turn = h;
  st.trick = [];
  return st;
}

// ---------------------------------------------------------------------------
// بازی کردن کارت
// ---------------------------------------------------------------------------
export function canPlay(state, playerIndex, card) {
  if (state.phase !== 'playing') return false;
  if (state.turn !== playerIndex) return false;
  const hand = state.players[playerIndex].hand;
  if (!hand.some((c) => c.id === card.id)) return false;
  const leadSuit = state.trick.length ? state.trick[0].card.s : null;
  return legalCards(hand, leadSuit).some((c) => c.id === card.id);
}

export function playCard(state, playerIndex, card) {
  const st = clone(state);
  const p = st.players[playerIndex];
  const leadSuit = st.trick.length ? st.trick[0].card.s : null;
  // ثبت نداشتن خال (برای حافظه‌ی هوش مصنوعی و نمایش)
  if (leadSuit && card.s !== leadSuit) st.voids[playerIndex][leadSuit] = true;
  p.hand = p.hand.filter((c) => c.id !== card.id);
  st.trick.push({ player: playerIndex, card });
  st.seen.push(card.id);
  if (st.trick.length === 4) {
    st.phase = 'trickEnd';
    st.turn = null;
  } else {
    st.turn = NEXT(playerIndex);
  }
  return st;
}

/** جمع کردن دست و تعیین برنده‌ی آن */
export function collectTrick(state) {
  const st = clone(state);
  const wi = trickWinnerIndex(st.trick, st.trump);
  const winner = st.trick[wi].player;
  const team = TEAM_OF[winner];
  st.tricksWon[team] += 1;
  st.trickPiles[team].push(st.trick.map((t) => t.card));
  st.lastTrick = { cards: st.trick.slice(), winner, leader: st.leader, trump: st.trump };
  st.roundTricks.push({ cards: st.trick.slice(), winner, leader: st.leader, index: st.roundTricks.length + 1 });
  st.trick = [];
  st.leader = winner;
  st.turn = winner;

  const need = 7;
  if (st.tricksWon[0] >= need || st.tricksWon[1] >= need) {
    return finishRound(st);
  }
  st.phase = 'playing';
  return st;
}

/** محاسبه‌ی امتیاز راند با در نظر گرفتن کت و کتِ حاکم */
export function finishRound(state) {
  const st = clone(state);
  const winnerTeam = st.tricksWon[0] >= 7 ? 0 : 1;
  const loserTeam = 1 - winnerTeam;
  const hakemTeam = TEAM_OF[st.hakem];
  const s = st.settings;

  let points = 1;
  let kot = false;
  let hakemKot = false;
  if (st.tricksWon[loserTeam] === 0) {
    kot = true;
    if (s.kotEnabled) points = 2;
    // کت کردن حاکم (تیم مقابلِ حاکم، حاکم را ۷ بر ۰ می‌برد) = ۳ امتیاز
    if (s.hakemKotEnabled && winnerTeam !== hakemTeam) {
      hakemKot = true;
      points = 3;
    }
  }

  st.scores[winnerTeam] += points;
  st.roundResult = {
    winnerTeam, points, kot, hakemKot,
    tricks: st.tricksWon.slice(),
    hakem: st.hakem,
    trump: st.trump,
  };
  st.history.push({
    round: st.round,
    hakem: st.hakem,
    trump: st.trump,
    tricks: st.tricksWon.slice(),
    points: winnerTeam === 0 ? [points, 0] : [0, points],
    totals: st.scores.slice(),
    kot, hakemKot,
  });

  // پایان بازی؟
  let over = false;
  if (s.targetMode === 'points') {
    over = st.scores[0] >= s.targetPoints || st.scores[1] >= s.targetPoints;
  } else {
    over = st.round >= s.targetRounds;
  }

  if (over) {
    const w = st.scores[0] === st.scores[1] ? -1 : (st.scores[0] > st.scores[1] ? 0 : 1);
    st.gameResult = { winnerTeam: w, scores: st.scores.slice() };
    st.phase = 'gameEnd';
  } else {
    st.phase = 'roundEnd';
  }
  return st;
}

/**
 * حاکم راند بعد:
 *  - اگر تیم حاکم راند را برده باشد، حاکم حفظ می‌شود.
 *  - در غیر این صورت حاکمی به نفر بعدی (سمت راست حاکم) منتقل می‌شود.
 */
export function nextHakem(state) {
  const r = state.roundResult;
  if (!r) return state.hakem ?? 0;
  return TEAM_OF[state.hakem] === r.winnerTeam ? state.hakem : NEXT(state.hakem);
}

export function nextRound(state) {
  return startRound(state, nextHakem(state));
}

// ---------------------------------------------------------------------------
export function clone(o) {
  return JSON.parse(JSON.stringify(o));
}

export function speedMs(speed) {
  return { slow: 1250, normal: 750, fast: 380 }[speed] ?? 750;
}

export function suitCounts(hand) {
  const c = {};
  for (const s of SUITS) c[s] = 0;
  for (const card of hand) c[card.s] += 1;
  return c;
}
