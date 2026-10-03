// ---------------------------------------------------------------------------
// هوش مصنوعی بازی حکم
// شامل: شمارش کارت‌ها، تشخیص خالِ تمام‌شده‌ی حریفان، همکاری با یار،
//        بریدن و رد دادن هوشمند، کشیدن حکم و حفظ کارت‌های برنده.
// ---------------------------------------------------------------------------

import { SUITS, legalCards, beats, trickWinnerIndex } from './cards.js';
import { TEAM_OF, suitCounts } from './engine.js';

const rnd = (arr) => arr[Math.floor(Math.random() * arr.length)];

/** تمام کارت‌هایی که نه در دست من‌اند و نه بازی شده‌اند (یعنی دست سه نفر دیگر) */
function unseenCards(state, me) {
  const mine = new Set(state.players[me].hand.map((c) => c.id));
  const seen = new Set(state.seen);
  const onTable = state.trick.map((t) => t.card.id);
  onTable.forEach((id) => seen.add(id));
  const out = [];
  for (const s of SUITS) {
    for (let r = 2; r <= 14; r++) {
      const id = `${s}-${r}`;
      if (!mine.has(id) && !seen.has(id)) out.push({ s, r, id });
    }
  }
  return out;
}

/** آیا این کارت بالاترین کارت باقی‌مانده‌ی خالش است؟ (برگ برنده) */
function isMaster(card, unseen) {
  return !unseen.some((u) => u.s === card.s && u.r > card.r);
}

/** تعداد کارت‌های بالاتر از این کارت که هنوز دست حریفان است */
function higherOutstanding(card, unseen) {
  return unseen.filter((u) => u.s === card.s && u.r > card.r).length;
}

function lowest(cards) {
  return cards.reduce((a, b) => (b.r < a.r ? b : a));
}
function highest(cards) {
  return cards.reduce((a, b) => (b.r > a.r ? b : a));
}

// ---------------------------------------------------------------------------
// انتخاب حکم توسط حاکم بر اساس ۵ کارت اول
// ---------------------------------------------------------------------------
export function chooseTrumpAI(hand, difficulty = 'hard') {
  const counts = suitCounts(hand);
  let best = null;
  let bestScore = -Infinity;
  for (const s of SUITS) {
    const cards = hand.filter((c) => c.s === s);
    if (!cards.length) continue;
    let score = counts[s] * 2.6;
    for (const c of cards) {
      if (c.r === 14) score += 4.2;
      else if (c.r === 13) score += 3.0;
      else if (c.r === 12) score += 2.0;
      else if (c.r === 11) score += 1.2;
      else if (c.r === 10) score += 0.7;
      else score += 0.15;
    }
    if (counts[s] >= 3) score += 1.5;
    if (counts[s] >= 4) score += 2.0;
    if (difficulty === 'easy') score += Math.random() * 4;
    if (difficulty === 'normal') score += Math.random() * 1.5;
    if (score > bestScore) { bestScore = score; best = s; }
  }
  return best || rnd(SUITS);
}

// ---------------------------------------------------------------------------
// انتخاب کارت برای بازی
// ---------------------------------------------------------------------------
export function chooseCardAI(state, me) {
  const hand = state.players[me].hand;
  const trump = state.trump;
  const leadSuit = state.trick.length ? state.trick[0].card.s : null;
  const legal = legalCards(hand, leadSuit);
  if (legal.length === 1) return legal[0];

  const diff = state.settings.difficulty;
  // سطح آسان: گاهی تصادفی بازی می‌کند
  if (diff === 'easy' && Math.random() < 0.45) return rnd(legal);
  if (diff === 'normal' && Math.random() < 0.15) return rnd(legal);

  const unseen = unseenCards(state, me);
  return leadSuit
    ? followCard(state, me, legal, unseen, leadSuit, trump)
    : leadCard(state, me, legal, unseen, trump);
}

// --------------------------- وقتی شروع‌کننده‌ی دست هستم -------------------
function leadCard(state, me, legal, unseen, trump) {
  const hand = state.players[me].hand;
  const counts = suitCounts(hand);
  const partner = (me + 2) % 4;
  const opponents = [(me + 1) % 4, (me + 3) % 4];

  const trumps = hand.filter((c) => c.s === trump);
  const nonTrump = hand.filter((c) => c.s !== trump);
  const trumpsOut = unseen.filter((c) => c.s === trump).length;

  // ۱) کشیدن حکم: اگر حکم زیاد و قوی دارم و حریفان هنوز حکم دارند
  const oppHasTrump = opponents.some((o) => !state.voids[o][trump]);
  if (trumps.length >= 4 && trumpsOut > 0 && oppHasTrump) {
    const masterTrumps = trumps.filter((c) => isMaster(c, unseen));
    if (masterTrumps.length) return highest(masterTrumps);
    if (trumps.length >= 5) return highest(trumps);
  }

  // ۲) بازی کردن برگ برنده‌ی غیرحکم (آسِ باقی‌مانده) اگر حریفان از آن خال دارند
  const masters = nonTrump.filter((c) => isMaster(c, unseen));
  if (masters.length) {
    const safe = masters.filter((c) => {
      // اگر حریفی از آن خال تمام کرده و هنوز حکم دارد، ممکن است ببُرد
      const risky = opponents.some(
        (o) => state.voids[o][c.s] && !state.voids[o][trump] && trumpsOut > 0,
      );
      return !risky;
    });
    const pick = safe.length ? safe : (trumpsOut === 0 ? masters : []);
    if (pick.length) {
      // از خالی که بیشتر داریم شروع کن تا دست‌های بعدی هم بیفتد
      return pick.sort((a, b) => counts[b.s] - counts[a.s] || b.r - a.r)[0];
    }
  }

  // ۳) اگر حکم‌ها تمام شده‌اند، بلندترین کارت خال بلندم را بازی کن
  if (trumpsOut === 0 && nonTrump.length) {
    const longSuit = SUITS
      .filter((s) => s !== trump && counts[s] > 0)
      .sort((a, b) => counts[b] - counts[a])[0];
    const cards = hand.filter((c) => c.s === longSuit);
    return highest(cards);
  }

  // ۴) بازی کردن از خال کوتاه برای خالی کردن و امکان بریدن در دست‌های بعد
  if (nonTrump.length) {
    const shortSuits = SUITS
      .filter((s) => s !== trump && counts[s] > 0)
      .sort((a, b) => counts[a] - counts[b]);
    const target = shortSuits[0];
    const cards = hand.filter((c) => c.s === target);
    // اگر در آن خال کارت خیلی بالا داریم نگهش داریم و پایین‌ترین را بدهیم
    const nonMasters = cards.filter((c) => !isMaster(c, unseen));
    return lowest(nonMasters.length ? nonMasters : cards);
  }

  // ۵) فقط حکم دارم
  return highest(legal);
}

// --------------------------- وقتی باید جواب بدهم -------------------------
function followCard(state, me, legal, unseen, leadSuit, trump) {
  const hand = state.players[me].hand;
  const trick = state.trick;
  const partner = (me + 2) % 4;
  const position = trick.length;              // 1 = نفر دوم ... 3 = نفر آخر
  const isLast = position === 3;

  const wi = trickWinnerIndex(trick, trump);
  const winnerPlayer = trick[wi].player;
  const bestCard = trick[wi].card;
  const partnerWinning = TEAM_OF[winnerPlayer] === TEAM_OF[me];

  const sameSuit = legal.filter((c) => c.s === leadSuit);

  // ---------------- حالت اول: از خال زمین دارم (باید همان را بازی کنم) ----
  if (sameSuit.length) {
    const winners = sameSuit.filter((c) => beats(c, bestCard, trump, leadSuit));

    if (partnerWinning) {
      // یارم برنده است
      const partnerSafe = isLast
        || (bestCard.s === trump)
        || isMaster(bestCard, unseen);
      if (partnerSafe) return lowest(sameSuit);
      // اگر کارت یارم ضعیف است و من می‌توانم مطمئن‌تر ببرم
      if (winners.length) {
        const sure = winners.filter((c) => isMaster(c, unseen));
        if (sure.length) return lowest(sure);
      }
      return lowest(sameSuit);
    }

    // حریف برنده است → سعی کن با کمترین کارت ممکن ببری
    if (winners.length) {
      if (isLast) return lowest(winners);
      const sure = winners.filter((c) => isMaster(c, unseen));
      if (sure.length) return lowest(sure);
      // نفر دوم: بردن با کارت متوسط ریسک دارد، ولی اگر برگ برنده نداریم
      // و کارت نسبتاً بالایی داریم، بازی می‌کنیم تا حریف را مجبور کنیم
      const strong = winners.filter((c) => higherOutstanding(c, unseen) <= 1);
      if (strong.length) return lowest(strong);
      return lowest(sameSuit);
    }
    return lowest(sameSuit);
  }

  // ---------------- حالت دوم: از خال زمین ندارم → بریدن یا رد دادن -------
  const trumps = hand.filter((c) => c.s === trump);
  const discards = hand.filter((c) => c.s !== trump);

  if (partnerWinning) {
    const partnerSafe = isLast || bestCard.s === trump || isMaster(bestCard, unseen);
    if (partnerSafe) return bestDiscard(discards, trumps, unseen, state, me, trump);
    // یارم شاید ببازد؛ اگر حکم دارم و دست مهم است، می‌برم
    if (trumps.length) {
      const over = trumps.filter((c) => beats(c, bestCard, trump, leadSuit));
      if (over.length) return lowest(over);
    }
    return bestDiscard(discards, trumps, unseen, state, me, trump);
  }

  // حریف برنده است → اگر می‌توانم می‌بُرم
  if (trumps.length) {
    const over = trumps.filter((c) => beats(c, bestCard, trump, leadSuit));
    if (over.length) {
      if (isLast) return lowest(over);
      // اگر هنوز بازیکنی بعد از من هست که ممکن است حکم بالاتر بزند،
      // با حکمی می‌بُرم که احتمال سرشدن کمتری دارد
      const remaining = [1, 2, 3].slice(0, 3 - position).map((k) => (me + k) % 4);
      const oppAfter = remaining.filter((p) => TEAM_OF[p] !== TEAM_OF[me]);
      const oppMayTrump = oppAfter.some((p) => !state.voids[p][trump]);
      if (!oppMayTrump) return lowest(over);
      const safeOver = over.filter((c) => higherOutstanding(c, unseen) === 0);
      return safeOver.length ? lowest(safeOver) : lowest(over);
    }
    // حکم دارم ولی از حکمِ روی زمین بالاتر نیست → رد می‌دهم
  }
  return bestDiscard(discards, trumps, unseen, state, me, trump);
}

/** انتخاب بهترین کارت برای «رد دادن» */
function bestDiscard(discards, trumps, unseen, state, me, trump) {
  if (!discards.length) return lowest(trumps);
  const counts = suitCounts(discards);
  // کارت‌های برنده (آس/شاهِ باقی‌مانده) را نگه می‌داریم
  const keepers = new Set(
    discards.filter((c) => isMaster(c, unseen)).map((c) => c.id),
  );
  const candidates = discards.filter((c) => !keepers.has(c.id));
  const pool = candidates.length ? candidates : discards;
  // از کوتاه‌ترین خال، پایین‌ترین کارت را رد بده تا آن خال زودتر تمام شود
  const sorted = pool.slice().sort((a, b) => {
    if (counts[a.s] !== counts[b.s]) return counts[a.s] - counts[b.s];
    return a.r - b.r;
  });
  const targetSuit = sorted[0].s;
  return lowest(pool.filter((c) => c.s === targetSuit));
}

/** راهنمای کارت پیشنهادی برای بازیکن انسان */
export function hintCard(state) {
  try {
    return chooseCardAI({ ...state, settings: { ...state.settings, difficulty: 'hard' } }, 0);
  } catch {
    return null;
  }
}
