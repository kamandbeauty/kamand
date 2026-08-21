/**
 * Renders the new Ideal Gathering graphics onto the app shell: the cosmic
 * nebula theme (dark purple sky, three nebula glows, the deterministic star
 * field, glass cards, the glowing cosmic-cta button and the amber accents).
 *
 * Everything is read out of the real sources so the picture cannot claim
 * anything the code does not do:
 *   - the nebula palette out of the theme registry (class-havato-themes.php)
 *   - the labels out of the string map (class-havato-i18n.php)
 *   - the tabs out of havato-app.js
 *   - the star positions out of the same LCG the reference project's
 *     CosmicBackdrop uses (seed = i * 9301 + 49297) — the very stars the
 *     .hv-cosmic-stars box-shadow replays in havato-app.css.
 *
 * Vazirmatn has no glyphs for emoji / dingbats, so every decorative icon is
 * drawn as a vector shape (the same convention as the existing suites).
 *
 * Rasterised with resvg (no browser available in this sandbox), like every
 * other render-* suite.
 */
const { Resvg } = require('@resvg/resvg-js');
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', 'design', 'screenshots');
const FONTS = path.join(__dirname, 'fonts');
const SRC = path.join(__dirname, '..', 'havato');
const I18N = fs.readFileSync(path.join(SRC, 'includes', 'class-havato-i18n.php'), 'utf8');
const THEMES = fs.readFileSync(path.join(SRC, 'includes', 'class-havato-themes.php'), 'utf8');
const JS = fs.readFileSync(path.join(SRC, 'assets', 'js', 'havato-app.js'), 'utf8');

function ensureFonts() {
  const want = [
    ['vazirmatn-arabic-400-normal.woff2', 'Vazirmatn-Regular.ttf'],
    ['vazirmatn-arabic-700-normal.woff2', 'Vazirmatn-Bold.ttf'],
    ['vazirmatn-latin-400-normal.woff2', 'VazirmatnLatin-Regular.ttf'],
    ['vazirmatn-latin-700-normal.woff2', 'VazirmatnLatin-Bold.ttf']
  ];
  fs.mkdirSync(FONTS, { recursive: true });
  if (want.every(([, o]) => fs.existsSync(path.join(FONTS, o)))) return Promise.resolve();
  const woff2 = require('wawoff2');
  const src = path.join(__dirname, 'node_modules', '@fontsource', 'vazirmatn', 'files');
  return want.reduce((c, [from, to]) => c.then(() => {
    const dst = path.join(FONTS, to);
    if (fs.existsSync(dst)) return null;
    return woff2.decompress(fs.readFileSync(path.join(src, from)))
      .then(t => fs.writeFileSync(dst, Buffer.from(t)));
  }), Promise.resolve());
}

function fa(key) {
  const re = new RegExp("'" + key + "'\\s*=>\\s*array\\(\\s*\\n?\\s*'fa'\\s*=>\\s*'((?:[^'\\\\]|\\\\.)*)'");
  const m = re.exec(I18N);
  if (!m) throw new Error('missing i18n key: ' + key);
  return m[1].replace(/\\'/g, "'");
}

// Read the nebula palette out of the registry.
const nStart = THEMES.indexOf("'nebula' => array(");
const nEnd = THEMES.indexOf('\n\t\t);', nStart);
const nBlock = THEMES.slice(nStart, nEnd);
const col = k => {
  const m = new RegExp("'" + k + "'\\s*=> '(#[0-9a-fA-F]{6})'").exec(nBlock);
  if (!m) throw new Error('missing nebula colour: ' + k);
  return m[1];
};
const T = {
  canvas: col('canvas'), card: col('card'), text: col('text'), soft: col('text_soft'),
  base: col('base'), light: col('light'), deep: col('deep'), accent: col('accent')
};

// The exact Ideal Gathering hard tokens (also shipped in havato-app.css).
const IG = {
  purple: '#7C3AED', violet: '#6D28D9', mid: '#8B5CF6',
  darkPrimary: '#A78BFA', darkSecondary: '#C4B5FD',
  darkBg: '#0F0A1E', midBg: '#1E1038', glowBg: '#2A1055',
  tangerine: '#DE9400', sunshine: '#FAC547',
  star: '#EDE9FE'
};

// Read the tab list so the bar cannot drift from the code.
const tabBlock = JS.slice(JS.indexOf('function tabsFor'), JS.indexOf('function buildTabs'));
const TABS = [...tabBlock.matchAll(/id: '(\w+)', label: '(\w+)'/g)].map(m => ({ id: m[1], label: fa(m[2]) }));
if (TABS.length !== 5) { console.error('expected 5 tabs, read ' + TABS.length); process.exit(1); }

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const rtl = (x, y, s, sz, w, fill, op) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}"${op ? ` fill-opacity="${op}"` : ''} direction="rtl" text-anchor="end">${esc(s)}</text>`;
const ctr = (x, y, s, sz, w, fill, op) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}"${op ? ` fill-opacity="${op}"` : ''} direction="rtl" text-anchor="middle">${esc(s)}</text>`;

/* ---- vector icons (Vazirmatn ships no dingbats) ---- */
const sparkle = (x, y, r, fill, op) =>
  `<path d="M${x},${y - r} Q${x},${y} ${x + r},${y} Q${x},${y} ${x},${y + r} Q${x},${y} ${x - r},${y} Q${x},${y} ${x},${y - r} Z" fill="${fill}"${op ? ` fill-opacity="${op}"` : ''}/>`;
const cup = (x, y, s, fill) => {
  const w = s, h = s * 0.92;
  return `<path d="M${x - w / 2},${y - h / 2} h${w} v${h * 0.45} a${w * 0.42},${w * 0.42} 0 0 1 -${w * 0.42},${w * 0.42} h-${w * 0.16} a${w * 0.42},${w * 0.42} 0 0 1 -${w * 0.42},-${w * 0.42} z" fill="none" stroke="${fill}" stroke-width="${Math.max(2, s * 0.09)}"/>` +
    `<path d="M${x + w / 2},${y - h * 0.16} a${w * 0.3},${w * 0.3} 0 0 0 ${w * 0.3},${w * 0.3}" fill="none" stroke="${fill}" stroke-width="${Math.max(2, s * 0.09)}" stroke-linecap="round"/>`;
};
const cal = (x, y, s, fill) =>
  `<rect x="${x - s / 2}" y="${y - s * 0.42}" width="${s}" height="${s * 0.84}" rx="${s * 0.14}" fill="none" stroke="${fill}" stroke-width="${Math.max(2, s * 0.1)}"/>` +
  `<path d="M${x - s * 0.18},${y - s * 0.62} v${s * 0.28} M${x + s * 0.18},${y - s * 0.62} v${s * 0.28}" stroke="${fill}" stroke-width="${Math.max(2, s * 0.1)}" stroke-linecap="round"/>` +
  `<path d="M${x - s / 2},${y - s * 0.08} h${s}" stroke="${fill}" stroke-width="${Math.max(2, s * 0.1)}"/>`;
const pin = (x, y, s, fill) =>
  `<path d="M${x},${y - s * 0.62} a${s * 0.34},${s * 0.34} 0 0 1 ${s * 0.34},${s * 0.34} c0,${s * 0.28} -${s * 0.34},${s * 0.62} -${s * 0.34},${s * 0.62} c0,0 -${s * 0.34},-${s * 0.34} -${s * 0.34},-${s * 0.62} a${s * 0.34},${s * 0.34} 0 0 1 ${s * 0.34},-${s * 0.34} z" fill="${fill}"/>` +
  `<circle cx="${x}" cy="${y - s * 0.28}" r="${s * 0.13}" fill="${IG.darkBg}"/>`;
const people = (x, y, s, fill) =>
  `<circle cx="${x - s * 0.16}" cy="${y - s * 0.1}" r="${s * 0.19}" fill="${fill}"/>` +
  `<circle cx="${x + s * 0.16}" cy="${y - s * 0.1}" r="${s * 0.19}" fill="${fill}"/>` +
  `<path d="M${x - s * 0.16},${y + s * 0.34} a${s * 0.24},${s * 0.24} 0 0 1 ${s * 0.48},0" fill="none" stroke="${fill}" stroke-width="${Math.max(2, s * 0.08)}" stroke-linecap="round"/>` +
  `<path d="M${x + s * 0.16},${y + s * 0.34} a${s * 0.24},${s * 0.24} 0 0 1 ${s * 0.48},0" fill="none" stroke="${fill}" stroke-width="${Math.max(2, s * 0.08)}" stroke-linecap="round"/>`;
const chat = (x, y, s, fill) =>
  `<rect x="${x - s * 0.42}" y="${y - s * 0.36}" width="${s * 0.84}" height="${s * 0.58}" rx="${s * 0.14}" fill="none" stroke="${fill}" stroke-width="${Math.max(2, s * 0.08)}"/>` +
  `<path d="M${x - s * 0.2},${y + s * 0.22} l-${s * 0.08},${s * 0.2} l${s * 0.2},-${s * 0.12}" fill="none" stroke="${fill}" stroke-width="${Math.max(2, s * 0.08)}" stroke-linecap="round" stroke-linejoin="round"/>`;
const home = (x, y, s, fill) =>
  `<path d="M${x - s * 0.42},${y - s * 0.05} l${s * 0.42},-${s * 0.34} l${s * 0.42},${s * 0.34} v${s * 0.36} a${s * 0.06},${s * 0.06} 0 0 1 -${s * 0.06},${s * 0.06} h-${s * 0.72} a${s * 0.06},${s * 0.06} 0 0 1 -${s * 0.06},-${s * 0.06} z" fill="none" stroke="${fill}" stroke-width="${Math.max(2, s * 0.08)}" stroke-linejoin="round"/>`;
const grid = (x, y, s, fill) =>
  [0, 1].map(r => [0, 1].map(c => `<rect x="${x - s * 0.38 + c * s * 0.42}" y="${y - s * 0.38 + r * s * 0.42}" width="${s * 0.34}" height="${s * 0.34}" rx="${s * 0.08}" fill="none" stroke="${fill}" stroke-width="${Math.max(2, s * 0.08)}"/>`).join('')).join('');
const user = (x, y, s, fill) =>
  `<circle cx="${x}" cy="${y - s * 0.18}" r="${s * 0.22}" fill="none" stroke="${fill}" stroke-width="${Math.max(2, s * 0.08)}"/>` +
  `<path d="M${x - s * 0.34},${y + s * 0.4} a${s * 0.34},${s * 0.3} 0 0 1 ${s * 0.68},0" fill="none" stroke="${fill}" stroke-width="${Math.max(2, s * 0.08)}" stroke-linecap="round"/>`;
const arrowL = (x, y, s, fill) =>
  `<path d="M${x + s * 0.3},${y} H${x - s * 0.3} M${x - s * 0.08},${y - s * 0.22} l-${s * 0.22},${s * 0.22} l${s * 0.22},${s * 0.22}" fill="none" stroke="${fill}" stroke-width="${Math.max(2, s * 0.09)}" stroke-linecap="round" stroke-linejoin="round"/>`;

const W = 760, H = 1620;
let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">`;
s += `<defs>
  <linearGradient id="cta" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="${IG.purple}"/>
    <stop offset="0.5" stop-color="${IG.mid}"/>
    <stop offset="1" stop-color="${IG.violet}"/>
  </linearGradient>
  <linearGradient id="headerBg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="${IG.darkBg}"/>
    <stop offset="0.45" stop-color="${IG.midBg}"/>
    <stop offset="1" stop-color="${IG.glowBg}"/>
  </linearGradient>
  <linearGradient id="nav" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="${IG.purple}"/>
    <stop offset="1" stop-color="${IG.violet}"/>
  </linearGradient>
  <linearGradient id="thumb" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="${IG.darkPrimary}"/>
    <stop offset="1" stop-color="${IG.purple}"/>
  </linearGradient>
  <radialGradient id="nebula1" cx="0.8" cy="0.2" r="0.75">
    <stop offset="0" stop-color="${IG.purple}" stop-opacity="0.35"/>
    <stop offset="0.6" stop-color="${IG.purple}" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="nebula2" cx="0.2" cy="0.8" r="0.7">
    <stop offset="0" stop-color="${IG.violet}" stop-opacity="0.28"/>
    <stop offset="0.6" stop-color="${IG.violet}" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="nebula3" cx="0.5" cy="0.5" r="0.6">
    <stop offset="0" stop-color="${IG.darkPrimary}" stop-opacity="0.18"/>
    <stop offset="0.65" stop-color="${IG.darkPrimary}" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="aura" cx="0.7" cy="0.15" r="0.7">
    <stop offset="0" stop-color="${IG.darkPrimary}" stop-opacity="0.45"/>
    <stop offset="1" stop-color="${IG.darkPrimary}" stop-opacity="0"/>
  </radialGradient>
</defs>`;

// ---- cosmic canvas: deep night + the three nebula glows ------------------
s += `<rect width="${W}" height="${H}" fill="${IG.darkBg}"/>`;
s += `<rect width="${W}" height="${H}" fill="url(#nebula1)"/>`;
s += `<rect width="${W}" height="${H}" fill="url(#nebula2)"/>`;
s += `<rect width="${W}" height="${H}" fill="url(#nebula3)"/>`;
// the deterministic star field — the exact LCG of the reference CosmicBackdrop
for (let i = 0; i < 70; i++) {
  const seed = i * 9301 + 49297;
  const x = (seed % 100) / 100 * W;
  const y = ((seed * 7) % 100) / 100 * (H - 220);
  const r = (1 + ((i * 5) % 3)) * 0.55;
  s += `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${r.toFixed(1)}" fill="${i % 4 === 0 ? IG.darkPrimary : IG.star}" fill-opacity="${i % 5 === 0 ? '0.95' : '0.6'}"/>`;
}

// ---- header: gradient-hero with a purple aura ----------------------------
s += `<rect width="${W}" height="150" fill="url(#headerBg)"/>`;
s += `<rect width="${W}" height="150" fill="url(#aura)"/>`;
s += `<circle cx="${W - 56}" cy="76" r="30" fill="none" stroke="${IG.darkSecondary}" stroke-opacity="0.55" stroke-width="2"/>`;
s += `<circle cx="${W - 56}" cy="76" r="26" fill="url(#thumb)"/>`;
s += rtl(W - 104, 86, fa('home_greeting').replace('%s', 'جاوید'), 24, 700, '#ffffff');
s += rtl(W - 104, 116, 'شب بخیر', 13, 400, IG.darkSecondary, 0.85);

let y = 176;
s += rtl(W - 28, y, fa('home_next_table'), 20, 800, '#ffffff');

// ---- hero card: glass, violet rim, glowing cover -------------------------
y += 20;
const cardH = 300;
s += `<rect x="28" y="${y}" width="${W - 56}" height="${cardH}" rx="26" fill="${IG.violet}" fill-opacity="0.14" stroke="${IG.darkPrimary}" stroke-opacity="0.30"/>`;
s += `<path d="M28,${y + 26} a26,26 0 0 1 26,-26 h${W - 108} a26,26 0 0 1 26,26 v106 h-${W - 56} z" fill="url(#thumb)"/>`;
s += `<path d="M28,${y + 26} a26,26 0 0 1 26,-26 h${W - 108} a26,26 0 0 1 26,26 v106 h-${W - 56} z" fill="${IG.darkBg}" fill-opacity="0.18"/>`;
s += cup(W / 2, y + 82, 44, '#ffffff');
s += sparkle(W / 2 + 92, y + 44, 9, IG.sunshine);
let by = y + 132;
s += rtl(W - 46, by + 30, 'شب موسیقی و گفتگو', 24, 800, '#ffffff');
s += cal(W - 64, by + 56, 20, T.soft);
s += rtl(W - 84, by + 62, 'جمعه · ۹ مرداد ۱۴۰۵ · ۱۸:۰۰', 15, 400, T.soft);
s += pin(W - 64, by + 82, 20, T.soft);
s += rtl(W - 84, by + 88, 'کافه دالون، خیابان ولیعصر', 15, 400, T.soft);
const fx = W - 46;
for (let i = 0; i < 4; i++) {
  s += `<circle cx="${fx - 16 - i * 23}" cy="${by + 118}" r="16" fill="url(#thumb)" stroke="${IG.glowBg}" stroke-width="2"/>`;
}
s += `<circle cx="${fx - 16 - 4 * 23}" cy="${by + 118}" r="16" fill="none" stroke="${IG.darkSecondary}" stroke-width="2" stroke-dasharray="3 3"/>`;
s += ctr(fx - 16 - 4 * 23, by + 123, '+۲', 12, 800, IG.darkSecondary);
s += `<rect x="${W - 46 - 96}" y="${by + 140}" width="96" height="24" rx="12" fill="${IG.darkPrimary}" fill-opacity="0.16"/>`;
s += ctr(W - 46 - 48, by + 157, fa('joined_event'), 13, 700, IG.darkSecondary);

// ---- discover: outlined cards with the glowing CTA -----------------------
y += cardH + 34;
s += rtl(W - 28, y, fa('home_discover'), 20, 800, '#ffffff');
s += `<text x="28" y="${y}" font-family="Vazirmatn" font-size="15" font-weight="700" fill="${IG.darkSecondary}">‹ ${esc(fa('view_all'))}</text>`;

y += 18;
const tileW = 218, tileH = 266, gap = 14;
['شب موسیقی و گفتگو', 'باشگاه کتاب', 'میز استارتاپ'].forEach((title, i) => {
  const x = W - 28 - tileW - i * (tileW + gap);
  s += `<rect x="${x}" y="${y}" width="${tileW}" height="${tileH}" rx="22" fill="${IG.violet}" fill-opacity="0.14" stroke="${IG.darkPrimary}" stroke-opacity="0.30"/>`;
  s += `<path d="M${x},${y + 22} a22,22 0 0 1 22,-22 h${tileW - 44} a22,22 0 0 1 22,22 v86 h-${tileW} z" fill="url(#thumb)"/>`;
  s += `<path d="M${x},${y + 22} a22,22 0 0 1 22,-22 h${tileW - 44} a22,22 0 0 1 22,22 v86 h-${tileW} z" fill="${IG.darkBg}" fill-opacity="0.18"/>`;
  s += cup(x + tileW / 2, y + 68, 36, '#ffffff');
  s += rtl(x + tileW - 16, y + 138, title, 17, 800, '#ffffff');
  s += rtl(x + tileW - 16, y + 164, 'جمعه ۹ مرداد · ۱۸:۰۰', 13, 400, T.soft);
  s += rtl(x + tileW - 16, y + 186, 'کافه دالون', 13, 400, T.soft);
  for (let k = 0; k < 3; k++) {
    s += `<circle cx="${x + tileW - 29 - k * 19}" cy="${y + 205}" r="13" fill="url(#thumb)" stroke="${IG.glowBg}" stroke-width="2"/>`;
  }
  // the cosmic-cta: purple ramp, top highlight line, sweeping sheen
  s += `<rect x="${x + 16}" y="${y + 224}" width="${tileW - 32}" height="30" rx="15" fill="url(#cta)"/>`;
  s += `<rect x="${x + 16}" y="${y + 224}" width="${tileW - 32}" height="1" fill="#ffffff" fill-opacity="0.85"/>`;
  s += `<rect x="${x + 34}" y="${y + 227}" width="34" height="24" fill="#ffffff" fill-opacity="0.30" transform="skewX(-18)"/>`;
  s += ctr(x + tileW / 2, y + 245, fa('join_event'), 14, 700, '#ffffff');
});

// ---- quick actions: glass 2x2 --------------------------------------------
y += tileH + 34;
s += rtl(W - 28, y, fa('quick_actions'), 20, 800, '#ffffff');
y += 18;
const qw2 = (W - 56 - 12) / 2, qh = 104;
[[fa('quick_browse'), 'sparkle'], [fa('quick_host'), 'plus'],
 [fa('tab_my_tables'), 'people'], [fa('tab_chats'), 'chat']].forEach(([label, glyph], i) => {
  const colx = i % 2, row = Math.floor(i / 2);
  const x = 28 + (1 - colx) * (qw2 + 12);
  const cy = y + row * (qh + 12);
  s += `<rect x="${x}" y="${cy}" width="${qw2}" height="${qh}" rx="20" fill="${IG.violet}" fill-opacity="0.14" stroke="${IG.darkPrimary}" stroke-opacity="0.30"/>`;
  const ix = x + qw2 - 16, iy = cy + 32;
  if (glyph === 'sparkle') s += sparkle(ix, iy, 11, IG.darkSecondary);
  if (glyph === 'plus') s += `<path d="M${ix},${iy - 9} v18 M${ix - 9},${iy} h18" stroke="${IG.darkSecondary}" stroke-width="3" stroke-linecap="round"/>`;
  if (glyph === 'people') s += people(ix, iy, 24, IG.darkSecondary);
  if (glyph === 'chat') s += chat(ix, iy, 24, IG.darkSecondary);
  s += rtl(x + qw2 - 16, cy + 64, label, 15, 700, '#ffffff');
  s += arrowL(x + qw2 - 16, cy + 88, 18, IG.darkSecondary);
});

// ---- activity summary -----------------------------------------------------
y += qh * 2 + 12 + 34;
s += rtl(W - 28, y, fa('activity_summary'), 20, 800, '#ffffff');
y += 18;
[[fa('dash_upcoming'), '۲', 'cal'], [fa('stat_attended'), '۵', 'people']].forEach(([label, value, glyph], i) => {
  const ry = y + i * 82;
  s += `<rect x="28" y="${ry}" width="${W - 56}" height="70" rx="20" fill="${IG.violet}" fill-opacity="0.14" stroke="${IG.darkPrimary}" stroke-opacity="0.30"/>`;
  if (glyph === 'cal') s += cal(W - 60, ry + 36, 22, IG.darkSecondary);
  if (glyph === 'people') s += people(W - 60, ry + 36, 24, IG.darkSecondary);
  s += rtl(W - 84, ry + 43, label, 16, 700, '#ffffff');
  s += `<text x="52" y="${ry + 47}" font-family="Vazirmatn" font-size="26" font-weight="800" fill="#ffffff">${value}</text>`;
});
y += 82 * 2;

// ---- five-tab bar: purple ramp + amber active indicator -------------------
const navH = 112;
const navY = H - navH;
s += `<rect x="0" y="${navY}" width="${W}" height="${navH}" rx="24" fill="url(#nav)"/>`;
s += `<rect x="0" y="${navY + 40}" width="${W}" height="${navH - 40}" fill="url(#nav)"/>`;
s += `<rect x="0" y="${navY}" width="${W}" height="1" fill="${IG.darkSecondary}" fill-opacity="0.22"/>`;
const slot = W / TABS.length;
const navGlyphs = [home, sparkle, grid, chat, user];
TABS.forEach((tab, i) => {
  const cx = W - (i + 0.5) * slot;
  const on = i === 0;
  s += `<circle cx="${cx}" cy="${navY + 40}" r="17" fill="#ffffff" fill-opacity="${on ? 0.22 : 0}"/>`;
  if (i === 0) s += navGlyphs[0](cx, navY + 40, 22, '#ffffff');
  else if (i === 1) s += sparkle(cx, navY + 40, 10, '#ffffff', 0.75);
  else s += navGlyphs[i](cx, navY + 40, 24, '#ffffff');
  s += ctr(cx, navY + 78, tab.label, 13, on ? 800 : 600, '#ffffff', on ? 1 : 0.75);
  if (on) {
    s += `<rect x="${cx - 11}" y="${navY + 86}" width="22" height="3" rx="1.5" fill="${IG.sunshine}"/>`;
  }
});

s += '</svg>';

// ---- second frame: the auth wall (nebula night + glass card + glow CTA) ----
const W2 = 760, H2 = 1620;
let a = `<svg xmlns="http://www.w3.org/2000/svg" width="${W2}" height="${H2}" viewBox="0 0 ${W2} ${H2}">`;
a += s.match(/<defs>[\s\S]*?<\/defs>/)[0];
a += `<rect width="${W2}" height="${H2}" fill="${IG.darkBg}"/>`;
a += `<rect width="${W2}" height="${H2}" fill="url(#nebula1)"/>`;
a += `<rect width="${W2}" height="${H2}" fill="url(#nebula2)"/>`;
a += `<rect width="${W2}" height="${H2}" fill="url(#nebula3)"/>`;
for (let i = 0; i < 70; i++) {
  const seed = i * 9301 + 49297;
  const x = (seed % 100) / 100 * W2;
  const y = ((seed * 7) % 100) / 100 * (H2 - 220);
  const r = (1 + ((i * 5) % 3)) * 0.55;
  a += `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${r.toFixed(1)}" fill="${i % 4 === 0 ? IG.darkPrimary : IG.star}" fill-opacity="${i % 5 === 0 ? '0.95' : '0.6'}"/>`;
}
// glass auth card
const cw = 560, ch = 520, cx0 = (W2 - cw) / 2, cy0 = 380;
a += `<rect x="${cx0}" y="${cy0}" width="${cw}" height="${ch}" rx="34" fill="${IG.violet}" fill-opacity="0.14" stroke="${IG.darkPrimary}" stroke-opacity="0.35"/>`;
a += `<rect x="${cx0 + 6}" y="${cy0 + 6}" width="${cw - 12}" height="${ch - 12}" rx="28" fill="none" stroke="${IG.darkSecondary}" stroke-opacity="0.18"/>`;
// logo medallion with the amber sparkle
a += `<rect x="${W2 / 2 - 44}" y="${cy0 + 46}" width="88" height="88" rx="26" fill="#ffffff" fill-opacity="0.14" stroke="${IG.darkSecondary}" stroke-opacity="0.4"/>`;
a += sparkle(W2 / 2, cy0 + 90, 26, IG.sunshine);
a += ctr(W2 / 2, cy0 + 182, fa('auth_title'), 24, 800, '#ffffff');
a += ctr(W2 / 2, cy0 + 222, fa('auth_sub'), 15, 400, IG.darkSecondary, 0.88);
// the cosmic-cta sign-in button
const bw = cw - 80;
a += `<rect x="${(W2 - bw) / 2}" y="${cy0 + 262}" width="${bw}" height="54" rx="27" fill="url(#cta)"/>`;
a += `<rect x="${(W2 - bw) / 2}" y="${cy0 + 262}" width="${bw}" height="1.5" fill="#ffffff" fill-opacity="0.9"/>`;
a += `<rect x="${(W2 - bw) / 2 + 30}" y="${cy0 + 266}" width="58" height="46" fill="#ffffff" fill-opacity="0.32" transform="skewX(-18)"/>`;
a += ctr(W2 / 2, cy0 + 296, fa('login_google'), 17, 800, '#ffffff');
// outline secondary
a += `<rect x="${(W2 - bw) / 2}" y="${cy0 + 336}" width="${bw}" height="54" rx="27" fill="${IG.violet}" fill-opacity="0.10" stroke="${IG.darkPrimary}" stroke-opacity="0.55"/>`;
a += ctr(W2 / 2, cy0 + 370, fa('owner_signin'), 16, 700, IG.darkSecondary);
a += '</svg>';

ensureFonts().then(() => {
  const probe = new Resvg(
    `<svg xmlns="http://www.w3.org/2000/svg" width="200" height="60"><text x="10" y="40" font-family="Vazirmatn" font-size="30">سلام</text></svg>`,
    { font: { fontDirs: [FONTS], defaultFontFamily: 'Vazirmatn', loadSystemFonts: false } }
  ).render().asPng();
  if (probe.length < 900) { throw new Error('font did not load — glyphs would be blank'); }

  fs.mkdirSync(OUT, { recursive: true });
  const opts = { font: { fontDirs: [FONTS], defaultFontFamily: 'Vazirmatn', loadSystemFonts: false }, fitTo: { mode: 'width', value: W } };
  const png = new Resvg(s, opts).render().asPng();
  fs.writeFileSync(path.join(OUT, 'home-nebula.png'), png);
  const png2 = new Resvg(a, opts).render().asPng();
  fs.writeFileSync(path.join(OUT, 'auth-nebula.png'), png2);
  console.log('wrote ' + path.join(OUT, 'home-nebula.png'));
  console.log('wrote ' + path.join(OUT, 'auth-nebula.png'));
  console.log('palette read from source:', JSON.stringify(T));
  console.log('tabs read from source:', TABS.map(x => x.label).join(' · '));
}).catch(e => { console.error(e.message); process.exit(1); });
