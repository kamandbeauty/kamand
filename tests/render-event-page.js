/**
 * Mock-up of the two changes to Explore: the subject line under the café
 * name, and the event page that now opens before the seat picker. Strings
 * are read from the source so the picture cannot drift from the code.
 */
const { Resvg } = require('@resvg/resvg-js');
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', 'design', 'screenshots');
const FONTS = path.join(__dirname, 'fonts');
const SRC = path.join(__dirname, '..', 'havato');
const I18N = fs.readFileSync(path.join(SRC, 'includes', 'class-havato-i18n.php'), 'utf8');
const SEED = fs.readFileSync(path.join(SRC, 'includes', 'class-havato-seeder.php'), 'utf8');

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

// Pull a real demo subject out of the seeder rather than inventing one.
const subjBlock = SEED.slice(SEED.indexOf('$subjects = array('));
const firstTitle = /'title' => '([^']+)'/.exec(subjBlock)[1];
const firstDesc = /'desc'  => '([^']+)'/.exec(subjBlock)[1];

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const rtl = (x, y, s, sz, w, fill, op) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}"${op ? ` fill-opacity="${op}"` : ''} direction="rtl" text-anchor="end">${esc(s)}</text>`;
const ctr = (x, y, s, sz, w, fill) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}" direction="rtl" text-anchor="middle">${esc(s)}</text>`;

/** Wrap Persian text to a pixel width, roughly, for the mock-up only. */
function wrap(text, perLine) {
  const words = String(text).split(' ');
  const lines = [];
  let line = '';
  words.forEach(w => {
    if ((line + ' ' + w).trim().length > perLine) { lines.push(line.trim()); line = w; }
    else { line = (line + ' ' + w).trim(); }
  });
  if (line) lines.push(line);
  return lines;
}

const W = 720, H = 1600;
const RASP = { base: '#c2185b', deep: '#8e1246', canvas: '#fff5f8' };
const INDIGO = '#4a2fd6';

let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">`;
s += `<defs>
  <linearGradient id="hdr" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="${RASP.base}"/><stop offset="1" stop-color="${RASP.deep}"/>
  </linearGradient>
  <linearGradient id="thumb" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#7b5cff"/><stop offset="1" stop-color="${RASP.base}"/>
  </linearGradient>
</defs>`;
s += `<rect width="${W}" height="${H}" fill="${RASP.canvas}"/>`;

// ---------- LEFT: the card, with the new subject line ----------
s += `<rect x="0" y="0" width="${W}" height="132" fill="url(#hdr)"/>`;
s += rtl(W - 30, 70, 'دورهمی‌های این هفته', 30, 700, '#ffffff');
s += rtl(W - 30, 104, '۱ · کارت کاوش', 16, 400, '#ffffff', 0.75);

let y = 160;
s += `<rect x="24" y="${y}" width="${W - 48}" height="250" rx="24" fill="#ffffff"/>`;
s += `<rect x="${W - 24 - 104}" y="${y + 20}" width="80" height="80" rx="22" fill="url(#thumb)"/>`;
s += rtl(W - 140, y + 48, 'کافه دالون', 25, 700, '#16204a');
// the new line
s += rtl(W - 140, y + 80, fa('event_subject') + ': ' + firstTitle, 19, 700, INDIGO);
s += rtl(W - 140, y + 110, 'جمعه · ۹ مرداد ۱۴۰۵ · ۱۸:۰۰', 17, 400, '#6b74a0');

let bx = W - 140;
const badge = (label, fill, ink) => {
  const bw = Math.max(56, label.length * 12 + 26);
  bx -= bw;
  let out = `<rect x="${bx}" y="${y + 126}" width="${bw}" height="32" rx="16" fill="${fill}"/>`;
  out += ctr(bx + bw / 2, y + 148, label, 15, 700, ink);
  bx -= 8;
  return out;
};
s += badge('باز', '#e3faf1', '#067a55');
s += badge('Board games', '#ffe9f2', '#be2f63');
s += badge('دنج', '#eef1fb', INDIGO);

s += `<rect x="48" y="${y + 176}" width="${W - 96}" height="8" rx="4" fill="#eef1fb"/>`;
s += rtl(W - 48, y + 220, '۱۴ صندلی خالی', 17, 400, '#6b74a0');
s += `<rect x="48" y="${y + 198}" width="180" height="44" rx="14" fill="${RASP.base}"/>`;
s += ctr(138, y + 227, fa('join_event'), 17, 700, '#ffffff');

// arrow down
y += 268;
s += ctr(W / 2, y + 30, '↓', 34, 700, RASP.base);
s += ctr(W / 2, y + 58, 'با زدن این دکمه، صفحه‌ی رویداد باز می‌شود', 16, 400, '#6b74a0');

// ---------- the event page ----------
y += 82;
const cardX = 24, cardW = W - 48;
s += `<rect x="${cardX}" y="${y}" width="${cardW}" height="${H - y - 24}" rx="26" fill="#ffffff"/>`;

// hero
s += `<rect x="${cardX}" y="${y}" width="${cardW}" height="130" rx="26" fill="url(#thumb)"/>`;
s += `<rect x="${cardX}" y="${y + 100}" width="${cardW}" height="30" fill="url(#thumb)"/>`;

let iy = y + 172;
s += rtl(W - 48, iy, 'کافه دالون', 27, 700, '#16204a');
iy += 32;
s += rtl(W - 48, iy, fa('event_subject') + ': ' + firstTitle, 19, 700, INDIGO);

// when + countdown
iy += 24;
s += `<rect x="48" y="${iy}" width="${cardW - 48}" height="84" rx="16" fill="#f1f4fd"/>`;
s += rtl(W - 66, iy + 32, 'جمعه · ۹ مرداد ۱۴۰۵ · ۱۸:۰۰', 18, 700, '#16204a');
s += rtl(W - 66, iy + 62, fa('starts_in') + ': ۲ ' + fa('unit_day') + ' ۳ ' + fa('unit_hour') + ' ۱۲ ' + fa('unit_minute'), 18, 800, INDIGO);

iy += 112;
s += rtl(W - 48, iy, '۱۴ ' + fa('seats_left') + ' · ' + fa('free'), 17, 400, '#6b74a0');

// about
iy += 40;
s += rtl(W - 48, iy, fa('event_about'), 19, 800, '#0a2a6b');
iy += 10;
wrap(firstDesc, 46).slice(0, 3).forEach(line => {
  iy += 28;
  s += rtl(W - 48, iy, line, 16, 400, '#16204a');
});

// venue: name, typed address, and a directions button
iy += 40;
s += rtl(W - 48, iy, fa('about_venue'), 19, 800, '#0a2a6b');
iy += 14;
const vbH = 132;
s += `<rect x="48" y="${iy}" width="${cardW - 48}" height="${vbH}" rx="16" fill="#f1f4fd"/>`;
s += rtl(W - 66, iy + 32, '📍  کافه دالون', 17, 800, '#16204a');
s += rtl(W - 66, iy + 58, 'تهران، خیابان ولیعصر، نبش کوچه', 15, 400, '#6b74a0');
s += rtl(W - 66, iy + 80, 'نیلوفر، پلاک ۱۲', 15, 400, '#6b74a0');
s += `<rect x="66" y="${iy + 92}" width="${cardW - 84}" height="30" rx="15" fill="${INDIGO}"/>`;
s += ctr(W / 2, iy + 113, fa('directions'), 15, 800, '#ffffff');
iy += vbH - 14;

// menu
iy += 42;
s += rtl(W - 48, iy, fa('venue_menu'), 19, 800, '#0a2a6b');
iy += 16;
[['اسپرسو', '۴۵٬۰۰۰ تومان'], ['لاته', '۶۵٬۰۰۰ تومان'], ['چیزکیک', '۹۵٬۰۰۰ تومان']].forEach(([name, price]) => {
  iy += 52;
  s += `<rect x="48" y="${iy - 34}" width="${cardW - 48}" height="44" rx="12" fill="#f8faff"/>`;
  s += `<rect x="${W - 108}" y="${iy - 28}" width="32" height="32" rx="10" fill="#eef1fb"/>`;
  s += rtl(W - 120, iy - 6, name, 17, 700, '#16204a');
  const p = `<text x="66" y="${iy - 6}" font-family="Vazirmatn" font-size="16" font-weight="700" fill="${INDIGO}" direction="rtl">${esc(price)}</text>`;
  s += p;
});

// reserve
iy += 46;
s += `<rect x="48" y="${iy}" width="${cardW - 48}" height="56" rx="16" fill="${RASP.base}"/>`;
s += ctr(W / 2, iy + 36, fa('join_event'), 19, 800, '#ffffff');

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
  const file = path.join(OUT, 'event-page.png');
  fs.writeFileSync(file, png);
  console.log('wrote ' + file + ' (subject "' + firstTitle + '" read from the seeder)');
}).catch(e => { console.error(e.message); process.exit(1); });
