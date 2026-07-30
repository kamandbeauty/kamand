/**
 * Mock-up of the language dropdown in the header. The three languages and
 * their native names are read out of the app source, so the picture cannot
 * claim an option the code does not offer.
 */
const { Resvg } = require('@resvg/resvg-js');
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', 'design', 'screenshots');
const FONTS = path.join(__dirname, 'fonts');
const SRC = path.join(__dirname, '..', 'havato');
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

// Read the real language list.
const block = JS.slice(JS.indexOf('var LANGS = ['), JS.indexOf('];', JS.indexOf('var LANGS = [')));
const LANGS = [...block.matchAll(/code: '(\w+)'[^}]*short: '([^']+)'[^}]*name: '([^']+)'/g)]
  .map(m => ({ code: m[1], short: m[2], name: m[3] }));
if (LANGS.length !== 3) { console.error('could not read the language list'); process.exit(1); }

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const rtl = (x, y, s, sz, w, fill, op) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}"${op ? ` fill-opacity="${op}"` : ''} direction="rtl" text-anchor="end">${esc(s)}</text>`;
const ltr = (x, y, s, sz, w, fill) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}">${esc(s)}</text>`;
const ctr = (x, y, s, sz, w, fill) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}" direction="rtl" text-anchor="middle">${esc(s)}</text>`;

const W = 720, H = 480;
const RASP = { base: '#c2185b', deep: '#8e1246', canvas: '#fff5f8' };
const INDIGO = '#4a2fd6';

let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">`;
s += `<defs><linearGradient id="hdr" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="${RASP.base}"/><stop offset="1" stop-color="${RASP.deep}"/>
</linearGradient>
<linearGradient id="av" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="#ffd9a8"/><stop offset="1" stop-color="#e8a765"/>
</linearGradient></defs>`;
s += `<rect width="${W}" height="${H}" fill="${RASP.canvas}"/>`;

// header
s += `<rect x="0" y="0" width="${W}" height="150" fill="url(#hdr)"/>`;
s += `<circle cx="${W - 56}" cy="72" r="30" fill="url(#av)"/>`;
s += rtl(W - 100, 66, 'هواتو', 15, 400, '#ffffff', 0.8);
s += rtl(W - 100, 94, 'دورهمی‌های این هفته', 25, 700, '#ffffff');

// language button on top, open
const bx = 20, bw = 68;
s += `<rect x="${bx}" y="46" width="${bw}" height="46" rx="14" fill="#ffffff" fill-opacity="0.3" stroke="#ffffff" stroke-opacity="0.5"/>`;
s += ctr(bx + 30, 76, LANGS[0].short, 16, 700, '#ffffff');
s += ltr(bx + 48, 78, '▾', 12, 700, '#ffffff');

// the per-tab action, now BENEATH the language button
s += `<rect x="${bx}" y="98" width="46" height="46" rx="14" fill="#ffffff" fill-opacity="0.18" stroke="#ffffff" stroke-opacity="0.42"/>`;
s += `<path d="M32,112 h22 l-8.5,10 v7 l-5,2.5 v-9.5 z" fill="#ffffff"/>`;

// the dropdown, anchored under the language button
const mx = bx + 76, my = 98, mw = 176, rowH = 46;
const mh = LANGS.length * rowH + 12;
s += `<rect x="${mx}" y="${my}" width="${mw}" height="${mh}" rx="14" fill="#ffffff"/>`;

LANGS.forEach((lang, i) => {
  const ry = my + 6 + i * rowH;
  const active = i === 0;
  if (active) {
    s += `<rect x="${mx + 6}" y="${ry}" width="${mw - 12}" height="${rowH - 4}" rx="10" fill="#f1f4fd"/>`;
  }
  // Each option renders in its own direction, as the code sets dir per row.
  if (lang.code === 'fa') {
    s += rtl(mx + mw - 20, ry + 28, lang.name, 17, 700, active ? INDIGO : '#16204a');
  } else {
    s += ltr(mx + 20, ry + 28, lang.name, 17, 700, active ? INDIGO : '#16204a');
  }
  if (active) {
    s += ltr(mx + 16, ry + 28, '✓', 15, 700, INDIGO);
  }
});

s += ctr(W / 2, mh + my + 60, 'هر زبان با یک ضربه — نه چرخیدن بین زبان‌ها', 17, 700, '#6b74a0');

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
  const file = path.join(OUT, 'lang-menu.png');
  fs.writeFileSync(file, png);
  console.log('wrote ' + file + ' (' + LANGS.map(l => l.name).join(', ') + ')');
}).catch(e => { console.error(e.message); process.exit(1); });
