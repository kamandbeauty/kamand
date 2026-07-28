/**
 * Mock-up of the new administrator event controls: the card with
 * details / edit / cancel, and the single-event screen underneath.
 * Labels are read from the string map so the picture cannot drift.
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
const rtl = (x, y, s, sz, w, fill) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}" direction="rtl" text-anchor="end">${esc(s)}</text>`;
const ctr = (x, y, s, sz, w, fill) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}" direction="rtl" text-anchor="middle">${esc(s)}</text>`;

const W = 1080, H = 860;
const INK = '#16204a', MUT = '#6b74a0', LINE = '#e6eaf5', BLUE = '#1552d8';

let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">`;
s += `<rect width="${W}" height="${H}" fill="#f0f0f1"/>`;

// ---------- card 1: an event in the list, with the new action row ----------
let y = 30;
s += `<rect x="30" y="${y}" width="${W - 60}" height="250" rx="14" fill="#ffffff" stroke="${LINE}"/>`;
s += rtl(W - 60, y + 52, 'شب موسیقی و گفتگو', 26, 700, INK);
s += rtl(W - 60, y + 84, 'کافه ناروان · تهران · ۷ مرداد ۱۴۰۵ — ۱۸:۰۰', 17, 400, MUT);

// status badges
let bx = W - 60;
const badge = (label, fill, ink) => {
  const bw = Math.max(70, label.length * 12 + 30);
  bx -= bw;
  let o = `<rect x="${bx}" y="${y + 100}" width="${bw}" height="32" rx="16" fill="${fill}"/>`;
  o += ctr(bx + bw / 2, y + 122, label, 15, 700, ink);
  bx -= 8;
  return o;
};
s += badge(fa('status_open'), '#e3faf1', '#067a55');
s += badge('۵ / ۱۴', '#e6efff', BLUE);
s += badge('#۱ (۴) + #۲ (۴) + #۳ (۶)', '#eef1f6', '#4b5563');

// the new action row, separated by a rule exactly as the CSS does
s += `<line x1="60" y1="${y + 154}" x2="${W - 60}" y2="${y + 154}" stroke="${LINE}"/>`;
let ax = W - 60;
const btn = (label, fill, ink, stroke) => {
  const bw = Math.max(120, label.length * 13 + 40);
  ax -= bw;
  let o = `<rect x="${ax}" y="${y + 172}" width="${bw}" height="44" rx="10" fill="${fill}"${stroke ? ` stroke="${stroke}"` : ''}/>`;
  o += ctr(ax + bw / 2, y + 200, label, 17, 700, ink);
  ax -= 10;
  return o;
};
s += btn(fa('event_details'), '#ffffff', BLUE, '#c7d6f5');
s += btn(fa('event_edit'), '#ffffff', BLUE, '#c7d6f5');
s += btn(fa('event_cancel'), '#fee2e2', '#b91c1c', null);

// ---------- card 2: the single-event screen ----------
y += 280;
s += `<rect x="30" y="${y}" width="${W - 60}" height="${H - y - 30}" rx="14" fill="#ffffff" stroke="${LINE}"/>`;
s += rtl(W - 60, y + 48, fa('event_details'), 24, 700, BLUE);

const rows = [
  [fa('venue_name'), 'کافه ناروان'],
  [fa('venue_address'), 'تهران، خیابان ولیعصر'],
  [fa('col_date'), '۷ مرداد ۱۴۰۵'],
  [fa('event_time'), '۱۸:۰۰'],
  [fa('col_status'), fa('status_open')],
  [fa('seats_occupancy'), '۵ / ۱۴'],
  [fa('venue_phone'), '۰۲۱-۸۸۷۷۶۶۵۵'],
];
let ry = y + 90;
rows.forEach(([k, v], i) => {
  if (i % 2 === 0) {
    s += `<rect x="60" y="${ry - 22}" width="${W - 120}" height="34" rx="8" fill="#f8faff"/>`;
  }
  s += rtl(W - 76, ry, k, 17, 700, INK);
  s += rtl(W - 340, ry, v, 17, 400, MUT);
  ry += 36;
});

// guest list header
ry += 12;
s += rtl(W - 60, ry, fa('members_at_table'), 20, 700, INK);
ry += 34;
[['javid', '۲', '✓'], ['نیلوفر', '۱', '—']].forEach(([n, seats, seen]) => {
  s += `<rect x="60" y="${ry - 22}" width="${W - 120}" height="36" rx="8" fill="#f8faff"/>`;
  s += rtl(W - 76, ry, n + '  ★ ۴٫۸', 17, 400, INK);
  s += rtl(W - 400, ry, seats + ' ' + fa('seats_reserved'), 16, 400, MUT);
  s += rtl(W - 700, ry, seen, 17, 700, seen === '✓' ? '#067a55' : MUT);
  ry += 40;
});

s += '</svg>';

ensureFonts().then(() => {
  // A missing font makes resvg silently drop every glyph — prove one renders.
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
  const file = path.join(OUT, 'admin-event-controls.png');
  fs.writeFileSync(file, png);
  console.log('wrote ' + file);
}).catch(e => { console.error(e.message); process.exit(1); });
