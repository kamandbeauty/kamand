/**
 * Mock-up of the reworked app: the Galaxy dark theme, the five-tab bar and
 * the new Home screen. Every colour is read out of the theme registry and
 * every label out of the string map, so the picture cannot claim something
 * the code does not do.
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

// Read the Galaxy palette out of the registry.
const gBlock = THEMES.slice(THEMES.indexOf("'galaxy' => array("), THEMES.indexOf("'raspberry' => array("));
const col = k => {
  const m = new RegExp("'" + k + "'\\s*=> '(#[0-9a-fA-F]{6})'").exec(gBlock);
  if (!m) throw new Error('missing galaxy colour: ' + k);
  return m[1];
};
const T = {
  canvas: col('canvas'), card: col('card'), text: col('text'), soft: col('text_soft'),
  base: col('base'), light: col('light'), deep: col('deep'), accent: col('accent')
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

const W = 760, H = 1450;
let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">`;
s += `<defs>
  <linearGradient id="thumb" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="${T.light}"/><stop offset="1" stop-color="${T.base}"/>
  </linearGradient>
  <linearGradient id="nav" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="${T.base}"/><stop offset="1" stop-color="${T.deep}"/>
  </linearGradient>
  <radialGradient id="glow" cx="0.7" cy="0.1" r="0.7">
    <stop offset="0" stop-color="${T.base}" stop-opacity="0.5"/>
    <stop offset="1" stop-color="${T.canvas}" stop-opacity="0"/>
  </radialGradient>
</defs>`;

// dark canvas with a soft nebula
s += `<rect width="${W}" height="${H}" fill="${T.canvas}"/>`;
s += `<rect width="${W}" height="${H}" fill="url(#glow)"/>`;
// a scattering of stars, deterministic so the image is reproducible
let seed = 7;
const rnd = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
for (let i = 0; i < 90; i++) {
  const x = rnd() * W, y = rnd() * (H - 200), r = rnd() * 1.4 + 0.4;
  s += `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${r.toFixed(1)}" fill="#ffffff" fill-opacity="${(rnd() * 0.6 + 0.15).toFixed(2)}"/>`;
}

// ---- header ----
s += `<circle cx="${W - 56}" cy="70" r="30" fill="none" stroke="${T.accent}" stroke-width="2"/>`;
s += `<circle cx="${W - 56}" cy="70" r="26" fill="url(#thumb)"/>`;
s += rtl(W - 104, 80, fa('home_greeting').replace('%s', 'جاوید'), 24, 700, T.text);

let y = 140;
s += rtl(W - 28, y, fa('home_next_table'), 20, 800, T.text);

// ---- hero card ----
y += 20;
const cardH = 168;
s += `<rect x="28" y="${y}" width="${W - 56}" height="${cardH}" rx="26" fill="${T.card}" stroke="${T.light}" stroke-opacity="0.28"/>`;
s += `<rect x="${W - 28 - 116}" y="${y + 22}" width="94" height="94" rx="20" fill="url(#thumb)"/>`;
s += ctr(W - 28 - 69, y + 78, '☕', 40, 400, '#ffffff');
s += rtl(W - 160, y + 46, 'کافه دالون', 24, 800, T.text);
s += rtl(W - 160, y + 76, 'جمعه ۹ مرداد · ۱۸:۰۰', 16, 400, T.soft);
s += rtl(W - 160, y + 104, fa('event_subject'), 12, 400, T.soft);
s += rtl(W - 160, y + 128, 'شب موسیقی و گفتگو', 19, 800, T.accent);
s += `<rect x="${W - 160 - 96}" y="${y + 138}" width="96" height="24" rx="12" fill="#12b981" fill-opacity="0.22"/>`;
s += ctr(W - 160 - 48, y + 155, fa('joined_event'), 13, 700, '#5ee7b5');

// ---- discover ----
y += cardH + 34;
s += rtl(W - 28, y, fa('home_discover'), 20, 800, T.text);
s += `<text x="28" y="${y}" font-family="Vazirmatn" font-size="15" font-weight="700" fill="${T.accent}">‹ ${esc(fa('view_all'))}</text>`;

y += 18;
const tileW = 218, tileH = 240, gap = 14;
['شب موسیقی و گفتگو', 'باشگاه کتاب', 'میز استارتاپ'].forEach((title, i) => {
  const x = W - 28 - tileW - i * (tileW + gap);
  s += `<rect x="${x}" y="${y}" width="${tileW}" height="${tileH}" rx="22" fill="${T.card}" stroke="${T.light}" stroke-opacity="0.28"/>`;
  s += `<path d="M${x},${y + 22} a22,22 0 0 1 22,-22 h${tileW - 44} a22,22 0 0 1 22,22 v86 h-${tileW} z" fill="url(#thumb)"/>`;
  s += ctr(x + tileW / 2, y + 68, '☕', 34, 400, '#ffffff');
  s += rtl(x + tileW - 16, y + 138, title, 17, 800, T.text);
  s += rtl(x + tileW - 16, y + 164, 'جمعه ۹ مرداد · ۱۸:۰۰', 13, 400, T.soft);
  s += rtl(x + tileW - 16, y + 186, 'کافه دالون', 13, 400, T.soft);
  s += `<rect x="${x + 16}" y="${y + 198}" width="${tileW - 32}" height="30" rx="15" fill="${T.base}"/>`;
  s += ctr(x + tileW / 2, y + 219, fa('join_event'), 14, 700, '#ffffff');
});

// ---- shortcuts ----
y += tileH + 30;
const qw = (W - 56 - 20) / 3;
[[fa('suggest_event'), '＋'], [fa('tab_my_tables'), '▤'], [fa('tab_chats'), '💬']].forEach(([label, glyph], i) => {
  const x = 28 + (2 - i) * (qw + 10);
  s += `<rect x="${x}" y="${y}" width="${qw}" height="82" rx="20" fill="${T.card}" stroke="${T.light}" stroke-opacity="0.28"/>`;
  s += ctr(x + qw / 2, y + 38, glyph, 22, 700, T.accent);
  s += ctr(x + qw / 2, y + 64, label, 13, 700, T.text);
});

// ---- five-tab bar ----
const navH = 112;
const navY = H - navH;
s += `<rect x="0" y="${navY}" width="${W}" height="${navH}" rx="24" fill="url(#nav)"/>`;
s += `<rect x="0" y="${navY + 40}" width="${W}" height="${navH - 40}" fill="url(#nav)"/>`;
const slot = W / TABS.length;
TABS.forEach((tab, i) => {
  // RTL: first tab on the right
  const cx = W - (i + 0.5) * slot;
  const on = i === 0;
  s += `<circle cx="${cx}" cy="${navY + 40}" r="17" fill="#ffffff" fill-opacity="${on ? 0.22 : 0}"/>`;
  s += ctr(cx, navY + 47, ['⌂', '✧', '▤', '💬', '☺'][i], 20, 700, '#ffffff', on ? 1 : 0.75);
  s += ctr(cx, navY + 78, tab.label, 13, on ? 800 : 600, '#ffffff', on ? 1 : 0.75);
});

s += '</svg>';

ensureFonts().then(() => {
  const probe = new Resvg(
    `<svg xmlns="http://www.w3.org/2000/svg" width="200" height="60"><text x="10" y="40" font-family="Vazirmatn" font-size="30">سلام</text></svg>`,
    { font: { fontDirs: [FONTS], defaultFontFamily: 'Vazirmatn', loadSystemFonts: false } }
  ).render().asPng();
  if (probe.length < 900) { throw new Error('font did not load — glyphs would be blank'); }

  fs.mkdirSync(OUT, { recursive: true });
  const png = new Resvg(s, {
    font: { fontDirs: [FONTS], defaultFontFamily: 'Vazirmatn', loadSystemFonts: false },
    fitTo: { mode: 'width', value: W }
  }).render().asPng();
  const file = path.join(OUT, 'home-galaxy.png');
  fs.writeFileSync(file, png);
  console.log('wrote ' + file);
  console.log('palette read from source:', JSON.stringify(T));
  console.log('tabs read from source:', TABS.map(x => x.label).join(' · '));
}).catch(e => { console.error(e.message); process.exit(1); });
