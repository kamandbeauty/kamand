/**
 * Mock-up of the reworked chrome: the per-tab action now sits in the header,
 * the round button in the bottom bar opens the guest's dashboard, and the
 * dashboard itself carries the guest's details, a suggest button, their
 * bookings and a directions link. Strings come from the source.
 */
const { Resvg } = require('@resvg/resvg-js');
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', 'design', 'screenshots');
const FONTS = path.join(__dirname, 'fonts');
const SRC = path.join(__dirname, '..', 'havato');
const I18N = fs.readFileSync(path.join(SRC, 'includes', 'class-havato-i18n.php'), 'utf8');

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

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const rtl = (x, y, s, sz, w, fill, op) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}"${op ? ` fill-opacity="${op}"` : ''} direction="rtl" text-anchor="end">${esc(s)}</text>`;
const ctr = (x, y, s, sz, w, fill) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}" direction="rtl" text-anchor="middle">${esc(s)}</text>`;

const W = 720, H = 1330;
const RASP = { base: '#c2185b', deep: '#8e1246', canvas: '#fff5f8' };
const INDIGO = '#4a2fd6';

let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">`;
s += `<defs>
  <linearGradient id="hdr" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="${RASP.base}"/><stop offset="1" stop-color="${RASP.deep}"/>
  </linearGradient>
  <linearGradient id="fab" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#6bb3ff"/><stop offset="1" stop-color="${INDIGO}"/>
  </linearGradient>
  <linearGradient id="av" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#ffd9a8"/><stop offset="1" stop-color="#e8a765"/>
  </linearGradient>
</defs>`;
s += `<rect width="${W}" height="${H}" fill="${RASP.canvas}"/>`;

// ---------- header, now carrying the per-tab action ----------
s += `<rect x="0" y="0" width="${W}" height="150" fill="url(#hdr)"/>`;
s += `<circle cx="${W - 56}" cy="72" r="30" fill="url(#av)"/>`;
s += rtl(W - 100, 66, 'هواتو', 15, 400, '#ffffff', 0.8);
s += rtl(W - 100, 94, 'دورهمی‌های این هفته', 25, 700, '#ffffff');

// the moved action button + language button
s += `<rect x="96" y="50" width="46" height="46" rx="14" fill="#ffffff" fill-opacity="0.18" stroke="#ffffff" stroke-opacity="0.42"/>`;
s += `<path d="M108,64 h22 l-8.5,10 v7 l-5,2.5 v-9.5 z" fill="#ffffff"/>`;
s += `<rect x="24" y="50" width="60" height="46" rx="14" fill="#ffffff" fill-opacity="0.18" stroke="#ffffff" stroke-opacity="0.42"/>`;
s += ctr(54, 80, 'EN', 16, 700, '#ffffff');
s += ctr(119, 122, 'فیلتر ← اینجا', 13, 700, '#ffffff');

// ---------- dashboard card ----------
let y = 182;
const cx = 24, cw = W - 48;
s += `<rect x="${cx}" y="${y}" width="${cw}" height="${H - y - 150}" rx="26" fill="#ffffff"/>`;

let iy = y + 60;
s += `<circle cx="${W - 74}" cy="${iy - 8}" r="28" fill="url(#av)"/>`;
s += rtl(W - 118, iy - 12, 'جاوید', 25, 700, '#16204a');
s += rtl(W - 118, iy + 14, '★ ۵٫۰', 17, 400, '#6b74a0');

// stats
iy += 48;
const sw = (cw - 48 - 16) / 3;
[[ '۲', fa('dash_upcoming') ], [ '۵٫۰', fa('rating_score') ], [ '۱', fa('dash_requests') ]]
  .forEach(([n, label], i) => {
    const bx = 48 + (2 - i) * (sw + 8);
    s += `<rect x="${bx}" y="${iy}" width="${sw}" height="76" rx="14" fill="#f1f4fd"/>`;
    s += ctr(bx + sw / 2, iy + 36, n, 26, 800, INDIGO);
    s += ctr(bx + sw / 2, iy + 60, label, 12, 400, '#6b74a0');
  });

// suggest button
iy += 100;
s += `<rect x="48" y="${iy}" width="${cw - 48}" height="54" rx="16" fill="${RASP.base}"/>`;
s += ctr(W / 2, iy + 35, fa('suggest_event'), 19, 800, '#ffffff');

// upcoming
iy += 88;
s += rtl(W - 48, iy, fa('dash_upcoming'), 19, 800, '#0a2a6b');

[['کافه دالون', 'شب موسیقی و گفتگو', 'جمعه · ۹ مرداد · ۱۸:۰۰'],
 ['کافه بالکن سفید', 'باشگاه کتاب', 'شنبه · ۱۰ مرداد · ۱۹:۳۰']].forEach(([venue, subj, when]) => {
  iy += 22;
  s += `<rect x="48" y="${iy}" width="${cw - 48}" height="104" rx="16" fill="#ffffff" stroke="#eef1fb"/>`;
  s += rtl(W - 68, iy + 30, venue, 19, 800, '#16204a');
  s += rtl(W - 68, iy + 56, fa('event_subject') + ': ' + subj, 15, 700, INDIGO);
  s += rtl(W - 68, iy + 80, when, 14, 400, '#6b74a0');
  // directions button
  s += `<rect x="66" y="${iy + 32}" width="112" height="40" rx="12" fill="#f1f4fd"/>`;
  s += ctr(122, iy + 58, fa('directions'), 15, 700, INDIGO);
  iy += 112;
});

// ---------- bottom nav with the dashboard button ----------
const navY = H - 116;
s += `<rect x="0" y="${navY}" width="${W}" height="116" fill="url(#hdr)"/>`;
s += `<circle cx="${W / 2}" cy="${navY}" r="42" fill="${RASP.canvas}"/>`;
s += `<circle cx="${W / 2}" cy="${navY}" r="36" fill="url(#fab)" stroke="#ffffff" stroke-width="4"/>`;
// dashboard glyph: two filled, two outlined squares
s += `<rect x="${W / 2 - 15}" y="${navY - 15}" width="13" height="13" rx="4" fill="#ffffff"/>`;
s += `<rect x="${W / 2 + 2}" y="${navY - 15}" width="13" height="13" rx="4" fill="none" stroke="#ffffff" stroke-width="2.2"/>`;
s += `<rect x="${W / 2 - 15}" y="${navY + 2}" width="13" height="13" rx="4" fill="none" stroke="#ffffff" stroke-width="2.2"/>`;
s += `<rect x="${W / 2 + 2}" y="${navY + 2}" width="13" height="13" rx="4" fill="#ffffff"/>`;
s += ctr(W / 2, navY + 62, fa('dashboard_title'), 14, 800, '#ffffff');

['کاوش', 'نقشه', 'گفتگوها', 'پروفایل من'].forEach((label, i) => {
  const px = [W - 92, W - 250, 250, 92][i];
  s += ctr(px, navY + 62, label, 14, 700, '#ffffff');
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
  const file = path.join(OUT, 'dashboard.png');
  fs.writeFileSync(file, png);
  console.log('wrote ' + file);
}).catch(e => { console.error(e.message); process.exit(1); });
