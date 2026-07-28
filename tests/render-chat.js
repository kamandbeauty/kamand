/**
 * Mock-up of the reworked table chat: sender avatar + name beside each
 * message, a single (not doubled) message list, the sticker tray, and the
 * system line in one language only. Strings come from the source so the
 * picture cannot drift from the code.
 */
const { Resvg } = require('@resvg/resvg-js');
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', 'design', 'screenshots');
const FONTS = path.join(__dirname, 'fonts');
const SRC = path.join(__dirname, '..', 'havato');
const I18N = fs.readFileSync(path.join(SRC, 'includes', 'class-havato-i18n.php'), 'utf8');
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

// Read the real sticker set out of the app rather than retyping it.
const stickerBlock = JS.slice(JS.indexOf('var STICKERS = ['), JS.indexOf('];', JS.indexOf('var STICKERS = [')));
const STICKERS = (stickerBlock.match(/'([^']+)'/g) || []).map(s => s.slice(1, -1));
if (STICKERS.length < 12) { console.error('could not read the sticker set'); process.exit(1); }

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const rtl = (x, y, s, sz, w, fill, op) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}"${op ? ` fill-opacity="${op}"` : ''} direction="rtl" text-anchor="end">${esc(s)}</text>`;
const ctr = (x, y, s, sz, w, fill) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}" direction="rtl" text-anchor="middle">${esc(s)}</text>`;

const W = 720, H = 1280;
const RASP = { base: '#c2185b', deep: '#8e1246', canvas: '#fff5f8' };

let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">`;
s += `<defs>
  <linearGradient id="hdr" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="${RASP.base}"/><stop offset="1" stop-color="${RASP.deep}"/>
  </linearGradient>
  <linearGradient id="mine" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#7b5cff"/><stop offset="1" stop-color="#4a2fd6"/>
  </linearGradient>
  <linearGradient id="av" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#ffd9a8"/><stop offset="1" stop-color="#e8a765"/>
  </linearGradient>
</defs>`;
s += `<rect width="${W}" height="${H}" fill="${RASP.canvas}"/>`;

// header
s += `<rect x="0" y="0" width="${W}" height="200" rx="34" fill="url(#hdr)"/>`;
s += `<rect x="0" y="120" width="${W}" height="80" fill="url(#hdr)"/>`;
s += rtl(W - 110, 96, fa('chat_groups'), 34, 700, '#ffffff');
s += `<circle cx="${W - 56}" cy="84" r="34" fill="url(#av)"/>`;

let y = 250;

// ---- system line: ONE language only ----
const sysText = fa('chat_table_ready') + ' کافه ناروان — ' + fa('table_number_label').replace('%d', '۳');
s += `<rect x="90" y="${y}" width="${W - 180}" height="64" rx="18" fill="#efe7ff"/>`;
s += ctr(W / 2, y + 40, sysText, 19, 400, '#4a2fd6');
y += 96;

// ---- incoming messages: avatar + name ----
function incoming(name, text, time) {
  const h = 92;
  // avatar sits outside the bubble, on the reading edge (RTL: right)
  s += `<circle cx="${W - 74}" cy="${y + h - 22}" r="24" fill="url(#av)"/>`;
  s += `<circle cx="${W - 74}" cy="${y + h - 30}" r="8" fill="#ffffff" fill-opacity="0.85"/>`;
  s += `<rect x="${W - 52 - 380}" y="${y}" width="380" height="${h}" rx="18" fill="#ffffff"/>`;
  s += rtl(W - 70 - 22, y + 30, name, 17, 700, RASP.base);
  s += rtl(W - 70 - 22, y + 58, text, 20, 400, '#16204a');
  s += rtl(W - 70 - 22, y + 80, time, 15, 400, '#8b93b5');
  y += h + 14;
}
incoming('javid', 'سلام، من رسیدم', '۱۲:۴۷');
incoming('نیلوفر', 'منم نزدیکم 😊', '۱۲:۴۸');

// ---- my own message: no avatar, no repeated name ----
function mine(text, time) {
  const h = 74;
  s += `<rect x="52" y="${y}" width="300" height="${h}" rx="18" fill="url(#mine)"/>`;
  s += rtl(330, y + 40, text, 20, 400, '#ffffff');
  s += rtl(330, y + 63, time, 15, 400, '#ffffff');
  y += h + 14;
}
mine('سلام! تا ۵ دقیقه دیگه اونجام', '۱۲:۴۹');
mine('☕', '۱۲:۴۹');

// ---- sticker tray, 6 per row exactly as the CSS grid does ----
y += 10;
const trayRows = 2;
const trayH = trayRows * 62 + 20;
s += `<rect x="30" y="${y}" width="${W - 60}" height="${trayH}" rx="20" fill="#ffffff"/>`;
const cell = (W - 60 - 20) / 6;
for (let i = 0; i < trayRows * 6; i++) {
  const r = Math.floor(i / 6), c = i % 6;
  const cx = 30 + 10 + cell * (5 - c) + cell / 2;   // RTL: fill right-to-left
  const cy = y + 14 + r * 62 + 40;
  s += `<text x="${cx}" y="${cy}" font-family="Vazirmatn" font-size="34" text-anchor="middle">${esc(STICKERS[i])}</text>`;
}
y += trayH + 16;

// ---- composer with the sticker toggle ----
s += `<rect x="150" y="${y}" width="${W - 150 - 106}" height="66" rx="18" fill="#ffffff" stroke="#e3d3dc"/>`;
s += rtl(W - 130, y + 42, fa('chat_placeholder'), 19, 400, '#9aa0bd');
s += `<rect x="${W - 96}" y="${y}" width="66" height="66" rx="20" fill="url(#mine)"/>`;
s += ctr(W - 63, y + 44, '➤', 26, 700, '#ffffff');
// the new sticker button
s += `<circle cx="118" cy="${y + 33}" r="28" fill="${RASP.base}"/>`;
s += ctr(118, y + 43, '☺', 28, 700, '#ffffff');
s += rtl(88, y + 110, fa('stickers'), 17, 700, RASP.base);

s += '</svg>';

ensureFonts().then(() => {
  // A missing font makes resvg silently drop every glyph, so prove one renders.
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
  const file = path.join(OUT, 'chat-reworked.png');
  fs.writeFileSync(file, png);
  console.log('wrote ' + file + ' (' + STICKERS.length + ' stickers read from source)');
}).catch(e => { console.error(e.message); process.exit(1); });
