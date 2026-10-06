//
// Tale Man (طالع من) — deterministic engine, TypeScript port.
//
// Bit-for-bit compatible with the Dart engine in lib/domain/…:
//  • fnv1a32 hashes rune-wise (seeds are ASCII in practice) with 32-bit
//    wrapping multiplies done via Math.imul.
//  • DetRandom is the same LCG (state = 1664525·s + 1013904223 mod 2³²).
//  • Every pick()/nextInt() call order matches the Dart code path.
//
// Known-answer vectors (must match lib/domain/horoscope/deterministic_random.dart):
//   fnv1a32('aries')                     = 0x346BCCB5
//   fnv1a32('scorpio|1405-7-14')         = 0xB07CA3E6
//   fnv1a32('scores|capricorn|1404-12-30') = 0xB2633D4A
//   fnv1a32('week|pisces|1405-1-1')      = 0xDF11C720
//   fnv1a32('compat|aries|pisces')       = 0xA25B06AA
//   fnv1a32('lucky|leo|1405-10-5')       = 0x0624DF55
//   fnv1a32('month|taurus|1405-5')       = 0x46C45269
//   LCG(12345) first outputs: 05391C44 043C7AD3 8B0C4216 A289127D E8F7B1B8
//

import jmoment from 'jalali-moment';

import content from './content/appContent.json';

const SIGNS = content.zodiacSigns;
const SIGN_BY_ID = Object.fromEntries(SIGNS.map((s) => [s.id, s]));

// ── Hash + PRNG ──────────────────────────────────────────────────────────

export function fnv1a32(input) {
  let hash = 0x811c9dc5;
  for (let i = 0; i < input.length; i++) {
    hash ^= input.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash >>> 0;
}

export class DetRandom {
  constructor(seed) {
    this._state = seed === 0 ? 0x6d2b79f5 : seed >>> 0;
  }
  nextUint32() {
    this._state = (Math.imul(1664525, this._state) + 1013904223) >>> 0;
    return this._state;
  }
  nextInt(max) {
    return this.nextUint32() % max;
  }
  pick(items) {
    return items[this.nextUint32() % items.length];
  }
}

export const clampInt = (v, min, max) => (v < min ? min : v > max ? max : v);

// ── Seeds ────────────────────────────────────────────────────────────────

export const dailySeed = (zodiacId, y, m, d) => fnv1a32(`${zodiacId}|${y}-${m}-${d}`);
export const weeklySeed = (zodiacId, weekStart) =>
  fnv1a32(`week|${zodiacId}|${weekStart[0]}-${weekStart[1]}-${weekStart[2]}`);
export const monthlySeed = (zodiacId, y, m) => fnv1a32(`month|${zodiacId}|${y}-${m}`);

// ── Zodiac ───────────────────────────────────────────────────────────────

export function zodiacForGregorian(month, day) {
  for (const sign of SIGNS) {
    const inStart = month === sign.startMonth && day >= sign.startDay;
    const inEnd = month === sign.endMonth && day <= sign.endDay;
    if (inStart || inEnd) return sign;
  }
  return null;
}

export const signById = (id) => SIGN_BY_ID[id];
export const signIndex = (sign) => SIGNS.findIndex((s) => s.id === sign.id);

// ── Scores ───────────────────────────────────────────────────────────────

function score(rng, signIdx, categoryIdx) {
  const bias = (signIdx * 7 + categoryIdx * 5) % 11 - 5;
  return clampInt(42 + rng.nextInt(50) + bias, 25, 97);
}

// ── Daily ────────────────────────────────────────────────────────────────

export function generateDaily(sign, date) {
  const [y, m, d] = date;
  const index = signIndex(sign);

  const scoreRng = new DetRandom(fnv1a32(`scores|${sign.id}|${y}-${m}-${d}`));
  const scores = {
    love: score(scoreRng, index, 0),
    career: score(scoreRng, index, 1),
    finance: score(scoreRng, index, 2),
    mood: score(scoreRng, index, 3),
    energy: score(scoreRng, index, 4),
  };

  const textRng = new DetRandom(fnv1a32(`text|${sign.id}|${y}-${m}-${d}`));
  const texts = {
    generalText: textRng.pick(sign.daily.general),
    loveText: textRng.pick(sign.daily.love),
    careerText: textRng.pick(sign.daily.career),
    financeText: textRng.pick(sign.daily.finance),
    moodText: textRng.pick(sign.daily.mood),
    warningText: textRng.pick(sign.daily.warning),
    opportunityText: textRng.pick(sign.daily.opportunity),
  };

  const luckyRng = new DetRandom(fnv1a32(`lucky|${sign.id}|${y}-${m}-${d}`));
  const lucky = {
    color: luckyRng.pick(sign.luckyColors),
    number: luckyRng.pick(sign.luckyNumbers),
    time: luckyRng.pick(sign.luckyTimes),
  };

  return {
    zodiacId: sign.id,
    date: `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`,
    scores,
    lucky,
    ...texts,
  };
}

export function personalJitter(profileId, zodiacId, dayKey, baseScore) {
  const j = (fnv1a32(`jitter|${profileId}|${zodiacId}|${dayKey}`) % 7) - 3;
  return clampInt(baseScore + j, 0, 100);
}

// ── Weekly ───────────────────────────────────────────────────────────────

export function generateWeekly(sign, weekStart) {
  const days = [];
  for (let i = 0; i < 7; i++) {
    const date = addJalaliDays(weekStart, i);
    days.push({ date, scores: generateDaily(sign, date).scores });
  }
  const summaryText = new DetRandom(weeklySeed(sign.id, weekStart)).pick(
    sign.weekly.summaries,
  );
  return { zodiacId: sign.id, weekStart, days, summaryText };
}

// ── Monthly ──────────────────────────────────────────────────────────────

export function generateMonthly(sign, year, month) {
  const index = signIndex(sign);
  const scoreRng = new DetRandom(fnv1a32(`mscores|${sign.id}|${year}-${month}`));
  const scores = {
    love: score(scoreRng, index, 0),
    career: score(scoreRng, index, 1),
    finance: score(scoreRng, index, 2),
    mood: score(scoreRng, index, 3),
    energy: score(scoreRng, index, 4),
  };
  const textRng = new DetRandom(monthlySeed(sign.id, year, month));
  return {
    zodiacId: sign.id,
    year,
    month,
    scores,
    focusText: textRng.pick(sign.monthly.focus),
    loveText: textRng.pick(sign.monthly.love),
    careerText: textRng.pick(sign.monthly.career),
    financeText: textRng.pick(sign.monthly.finance),
    energyText: textRng.pick(sign.monthly.energy),
    opportunityText: textRng.pick(sign.monthly.opportunity),
    warningText: textRng.pick(sign.monthly.warning),
  };
}

// ── Compatibility ────────────────────────────────────────────────────────

const ASPECT_BASE = {
  conjunction: 79,
  semisextile: 69,
  sextile: 84,
  square: 58,
  trine: 90,
  quincunx: 60,
  opposition: 71,
};

const ELEMENT_FACTOR = {
  'fire-fire': 1.0, 'earth-earth': 1.0, 'air-air': 1.0, 'water-water': 1.0,
  'fire-air': 0.95, 'earth-water': 0.95, 'fire-earth': 0.6, 'air-water': 0.65,
  'fire-water': 0.55, 'air-earth': 0.55,
};

export function aspectForDistance(distance) {
  switch (distance) {
    case 0: return 'conjunction';
    case 1: case 11: return 'semisextile';
    case 2: case 10: return 'sextile';
    case 3: case 9: return 'square';
    case 4: case 8: return 'trine';
    case 6: return 'opposition';
    default: return 'quincunx';
  }
}

function overallOf(s) {
  const v = Math.round(
    s.love * 0.28 + s.attraction * 0.2 + s.communication * 0.2 +
    s.trust * 0.16 + s.longTerm * 0.16,
  );
  return clampInt(v, 0, 100);
}

export function computeCompatibility(idA, idB) {
  const a = signById(idA);
  const b = signById(idB);
  const ia = signIndex(a);
  const ib = signIndex(b);
  const distance = (((ib - ia) % 12) + 12) % 12;
  const aspectId = aspectForDistance(distance);

  const first = idA < idB ? idA : idB;
  const second = idA < idB ? idB : idA;
  const pairSeed = fnv1a32(`compat|${first}|${second}`);
  const rng = new DetRandom(pairSeed);

  const base = ASPECT_BASE[aspectId];
  const ek = [a.elementId, b.elementId].sort().join('-');
  const factor = ELEMENT_FACTOR[ek] ?? 0.6;
  const elementAdj = Math.round(factor * 16 - 8);

  const dim = (spread) =>
    clampInt(base + elementAdj + rng.nextInt(spread) - Math.floor(spread / 2), 12, 99);

  const scores = {
    love: dim(15),
    attraction: dim(21),
    communication: dim(13),
    trust: dim(11),
    longTerm: dim(13),
  };
  scores.overall = overallOf(scores);

  const aspect = content.compatibility.aspectTexts[aspectId];
  const why = new DetRandom((pairSeed ^ 0x9e3779b9) >>> 0)
    .pick(aspect.why)
    .replaceAll('{a}', a.nameFa)
    .replaceAll('{b}', b.nameFa);

  return {
    signA: a,
    signB: b,
    scores,
    aspectId,
    aspectTitle: aspect.title,
    whyText: why,
    elementChemistryText: content.compatibility.elementChemistry[ek] ??
      content.compatibility.elementChemistry['fire-fire'],
  };
}

export function rankedFor(idA) {
  return SIGNS
    .filter((s) => s.id !== idA)
    .map((s) => computeCompatibility(idA, s.id))
    .sort((x, y) => y.scores.overall - x.scores.overall);
}

export const compatLabels = content.compatibility.labels;

// ── Jalali calendar helpers (via jalali-moment) ──────────────────────────

/** Today as a Jalali [y, m, d] triple. */
export function todayJalali() {
  const j = jmoment();
  return [j.jYear(), j.jMonth() + 1, j.jDate()];
}

/** Jalali date object (jmoment) from a [y, m, d] triple. */
export function jalaliMoment([y, m, d]) {
  return jmoment(`${y}/${m}/${d}`, 'jYYYY/jM/jD');
}

/** Convert Jalali [y,m,d] → JS Date (local midnight). */
export function jalaliToGregorian(triple) {
  const g = jalaliMoment(triple).format('YYYY-M-D');
  const [y, m, d] = g.split('-').map(Number);
  return new Date(y, m - 1, d);
}

/** Convert JS Date → Jalali [y,m,d]. */
export function gregorianToJalali(date) {
  const j = jmoment(date);
  return [j.jYear(), j.jMonth() + 1, j.jDate()];
}

/** Week start (Saturday) containing today, as a Jalali triple. */
export function weekStartJalali() {
  const now = new Date();
  const daysSinceSaturday = (now.getDay() + 1) % 7; // Sat→0 … Fri→6
  const sat = new Date(now.getFullYear(), now.getMonth(), now.getDate() - daysSinceSaturday);
  return gregorianToJalali(sat);
}

export function addJalaliDays(triple, days) {
  const g = jalaliToGregorian(triple);
  g.setDate(g.getDate() + days);
  return gregorianToJalali(g);
}

export function jalaliDayOfWeek(triple) {
  return jalaliToGregorian(triple).getDay(); // 0=Sun … 6=Sat
}

export const isJalaliValid = (y, m, d) => jalaliMoment([y, m, d]).isValid();
export const jalaliMonthLength = (y, m) => jalaliMoment([y, m, 1]).jDaysInMonth();
export const jalaliIsLeap = (y) => jmoment.jIsLeapJYear(y);

// ── Self-check (cross-platform determinism contract) ─────────────────────
// Runs once on import in dev; failures mean the port drifted from Dart.
const VECTORS = {
  '': 0x811c9dc5,
  aries: 0x346bccb5,
  'scorpio|1405-7-14': 0xb07ca3e6,
  'scores|capricorn|1404-12-30': 0xb2633d4a,
  'week|pisces|1405-1-1': 0xdf11c720,
  'compat|aries|pisces': 0xa25b06aa,
  'lucky|leo|1405-10-5': 0x0624df55,
  'month|taurus|1405-5': 0x46c45269,
};
let _engineOk = true;
for (const [k, v] of Object.entries(VECTORS)) {
  if (fnv1a32(k) !== v) {
    _engineOk = false;
    console.error(`engine.js: fnv1a32 vector mismatch for ${JSON.stringify(k)}`);
  }
}
const r = new DetRandom(12345);
for (const v of [0x05391c44, 0x043c7ad3, 0x8b0c4216, 0xa289127d, 0xe8f7b1b8]) {
  if (r.nextUint32() !== v) {
    _engineOk = false;
    console.error('engine.js: LCG vector mismatch');
    break;
  }
}
export const engineSelfCheckOk = _engineOk;
