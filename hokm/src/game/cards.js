// ---------------------------------------------------------------------------
// کارت‌ها و خال‌ها — پایه‌ی بازی حکم
// ---------------------------------------------------------------------------

export const SUITS = ['spades', 'hearts', 'clubs', 'diamonds'];

export const SUIT_INFO = {
  spades: { sym: '♠', fa: 'پیک', color: 'black' },
  hearts: { sym: '♥', fa: 'دل', color: 'red' },
  clubs: { sym: '♣', fa: 'گشنیز', color: 'black' },
  diamonds: { sym: '♦', fa: 'خشت', color: 'red' },
};

// ۲ تا ۱۴ (۱۱=سرباز، ۱۲=بی‌بی، ۱۳=شاه، ۱۴=آس)
export const MIN_RANK = 2;
export const MAX_RANK = 14;

export const RANK_LABEL = {
  2: '2', 3: '3', 4: '4', 5: '5', 6: '6', 7: '7', 8: '8', 9: '9', 10: '10',
  11: 'J', 12: 'Q', 13: 'K', 14: 'A',
};

export const RANK_FA = {
  2: '۲', 3: '۳', 4: '۴', 5: '۵', 6: '۶', 7: '۷', 8: '۸', 9: '۹', 10: '۱۰',
  11: 'سرباز', 12: 'بی‌بی', 13: 'شاه', 14: 'آس',
};

export const cardId = (s, r) => `${s}-${r}`;

export function makeDeck() {
  const deck = [];
  for (const s of SUITS) {
    for (let r = MIN_RANK; r <= MAX_RANK; r++) deck.push({ s, r, id: cardId(s, r) });
  }
  return deck;
}

export function shuffle(arr, rng = Math.random) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

export function toPersianDigits(input) {
  const map = '۰۱۲۳۴۵۶۷۸۹';
  return String(input).replace(/\d/g, (d) => map[+d]);
}

/** مرتب‌سازی دست: خال‌ها کنار هم، حکم اول، داخل هر خال از بزرگ به کوچک */
export function sortHand(hand, trump) {
  const order = (s) => {
    if (s === trump) return -1;
    return SUITS.indexOf(s);
  };
  return hand.slice().sort((a, b) => {
    if (a.s !== b.s) return order(a.s) - order(b.s);
    return b.r - a.r;
  });
}

/** کارت‌هایی که طبق قانون مجاز به بازی کردن هستند */
export function legalCards(hand, leadSuit) {
  if (!leadSuit) return hand.slice();
  const follow = hand.filter((c) => c.s === leadSuit);
  // قانون: اگر از خال زمین داری، حتماً باید همان خال را بازی کنی
  return follow.length ? follow : hand.slice();
}

/** برنده‌ی یک دست (trick) را برمی‌گرداند: ایندکس در آرایه‌ی trick */
export function trickWinnerIndex(trick, trump) {
  if (!trick.length) return -1;
  const leadSuit = trick[0].card.s;
  let best = 0;
  for (let i = 1; i < trick.length; i++) {
    const c = trick[i].card;
    const b = trick[best].card;
    if (c.s === b.s) {
      if (c.r > b.r) best = i;
    } else if (c.s === trump) {
      // بریدن: حکم همیشه بالاتر از خال زمین است
      best = i;
    } else if (b.s !== trump && c.s === leadSuit && b.s !== leadSuit) {
      best = i;
    }
  }
  return best;
}

export function beats(card, bestCard, trump, leadSuit) {
  if (!bestCard) return true;
  if (card.s === bestCard.s) return card.r > bestCard.r;
  if (card.s === trump) return true;
  if (bestCard.s === trump) return false;
  return bestCard.s !== leadSuit && card.s === leadSuit;
}
