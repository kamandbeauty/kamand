/**
 * Renders a mock-up of the new "Appearance & theme" admin page, using the
 * SAME palette values parsed out of class-havato-themes.php, so the picture
 * cannot drift from the code it documents.
 */
const { Resvg } = require('@resvg/resvg-js');
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', 'design', 'screenshots');
const FONTS = path.join(__dirname, 'fonts');
const PHP = fs.readFileSync(path.join(__dirname, '..', 'havato', 'includes', 'class-havato-themes.php'), 'utf8');

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

/* ---- read the real catalogue ---- */
const block = PHP.slice(PHP.indexOf('public static function catalogue()'), PHP.indexOf('apply_filters'));
const THEMES = [];
const re = /'([a-z0-9_]+)'\s*=>\s*array\(\s*\n\s*'label'\s*=>\s*array\(\s*'fa'\s*=>\s*'([^']+)'[\s\S]*?\),([\s\S]*?)\n\t\t\t\),/g;
let m;
while ((m = re.exec(block))) {
  const body = m[3];
  const g = k => { const x = new RegExp("'" + k + "'\\s*=>\\s*'(#[0-9a-fA-F]{6})'").exec(body); return x && x[1]; };
  THEMES.push({
    id: m[1], fa: m[2],
    light: g('light'), base: g('base'), deep: g('deep'),
    accent: g('accent'), accent2: g('accent_2'), canvas: g('canvas')
  });
}
if (THEMES.length !== 5) { console.error('expected 5 themes, parsed ' + THEMES.length); process.exit(1); }

const rgb = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const toHex = a => '#' + a.map(c => Math.max(0, Math.min(255, Math.round(c))).toString(16).padStart(2, '0')).join('');
const mix = (a, b, w) => { const x = rgb(a), y = rgb(b); return toHex([0, 1, 2].map(i => x[i] + (y[i] - x[i]) * w)); };
const lum = h => { const l = rgb(h).map(c => { c /= 255; return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }); return .2126 * l[0] + .7152 * l[1] + .0722 * l[2]; };
const cr = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + .05) / (Math.min(x, y) + .05); };

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const rtl = (x, y, s, sz, w, fill) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}" direction="rtl" text-anchor="end">${esc(s)}</text>`;
const ltr = (x, y, s, sz, w, fill) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}">${esc(s)}</text>`;

const W = 1240, PAD = 28;
const COLS = 3, GAP = 20;
const CARD_W = Math.floor((W - PAD * 2 - GAP * (COLS - 1)) / COLS);
const CARD_H = 396;
const rows = Math.ceil(THEMES.length / COLS);
const GRID_TOP = 214;
const H = GRID_TOP + rows * (CARD_H + GAP) + 190;

let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
<rect width="${W}" height="${H}" fill="#f0f0f1"/>`;

// wp-admin sidebar
s += `<rect x="0" y="0" width="26" height="${H}" fill="#1d2327"/>`;

// page header card
s += `<rect x="${PAD}" y="24" width="${W - PAD * 2}" height="96" rx="16" fill="#ffffff"/>`;
s += `<rect x="${PAD + 20}" y="46" width="52" height="52" rx="15" fill="#1552d8"/>`;
s += ltr(PAD + 39, 80, 'H', 26, 700, '#ffffff');
s += rtl(W - PAD - 22, 70, 'ظاهر و تم', 25, 700, '#1d2327');
s += rtl(W - PAD - 22, 98, 'تم فعال', 15, 400, '#646970');

// intro note
s += `<rect x="${PAD}" y="134" width="${W - PAD * 2}" height="60" rx="14" fill="#ffffff"/>`;
s += `<rect x="${PAD}" y="134" width="5" height="60" rx="3" fill="#1552d8"/>`;
s += rtl(W - PAD - 20, 172, 'یک تم را انتخاب کنید تا رنگ‌بندی کل اپلیکیشن تغییر کند. تغییر آنی است و روی داده‌ها اثری ندارد.', 16, 400, '#3c434a');

THEMES.forEach((t, i) => {
  const col = i % COLS, row = Math.floor(i / COLS);
  const x = PAD + col * (CARD_W + GAP);
  const y = GRID_TOP + row * (CARD_H + GAP);
  const live = t.id === 'azure';                    // azure shown as active
  const gid = 'g' + i;

  s += `<defs>
    <linearGradient id="${gid}h" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${t.light}"/><stop offset=".48" stop-color="${t.base}"/><stop offset="1" stop-color="${t.deep}"/></linearGradient>
    <linearGradient id="${gid}c" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="${t.light}"/><stop offset="1" stop-color="${t.base}"/></linearGradient>
    <linearGradient id="${gid}n" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${t.base}"/><stop offset="1" stop-color="${t.deep}"/></linearGradient>
    <linearGradient id="${gid}f" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${mix(t.accent, '#ffffff', .2)}"/><stop offset="1" stop-color="${t.accent}"/></linearGradient>
  </defs>`;

  s += `<rect x="${x}" y="${y}" width="${CARD_W}" height="${CARD_H}" rx="18" fill="#ffffff"
          stroke="${live ? '#12b981' : '#e0e2e7'}" stroke-width="${live ? 3 : 2}"/>`;

  // ---- miniature preview ----
  const px = x + 14, pw = CARD_W - 28;
  let py = y + 14;
  s += `<rect x="${px}" y="${py}" width="${pw}" height="182" rx="12" fill="${t.canvas}"/>`;
  s += `<rect x="${px + 12}" y="${py + 12}" width="${pw - 24}" height="46" rx="11" fill="url(#${gid}h)"/>`;
  s += `<rect x="${px + 12}" y="${py + 66}" width="${pw - 24}" height="30" rx="9" fill="url(#${gid}h)"/>`;
  const sw3 = (pw - 24 - 12) / 3;
  for (let k = 0; k < 3; k++)
    s += `<rect x="${px + 12 + k * (sw3 + 6)}" y="${py + 102}" width="${sw3}" height="26" rx="8" fill="#ffffff" stroke="#e6e8ee"/>`;
  s += `<rect x="${px + 12}" y="${py + 134}" width="${pw - 24}" height="20" rx="7" fill="url(#${gid}c)"/>`;
  s += `<rect x="${px + 12}" y="${py + 160}" width="${pw - 24}" height="14" rx="7" fill="url(#${gid}n)"/>`;
  s += `<circle cx="${px + pw / 2}" cy="${py + 160}" r="12" fill="url(#${gid}f)" stroke="#ffffff" stroke-width="3"/>`;

  // ---- meta ----
  let my = y + 224;
  const right = x + CARD_W - 16;
  s += rtl(right, my, t.fa, 19, 700, '#1d2327');
  if (live) {
    s += `<rect x="${x + 16}" y="${my - 17}" width="76" height="23" rx="11" fill="#e3faf1"/>`;
    s += `<text x="${x + 54}" y="${my - 1}" font-family="Vazirmatn" font-size="13" font-weight="700" fill="#067a55" text-anchor="middle">در حال استفاده</text>`;
  }

  // swatches
  my += 26;
  const sws = [t.light, t.base, t.deep, t.accent, t.accent2, t.canvas];
  sws.forEach((hex, k) => {
    s += `<rect x="${right - 26 - k * 30}" y="${my}" width="26" height="26" rx="7" fill="${hex}" stroke="#dfe1e6"/>`;
  });

  // contrast
  my += 52;
  const ratio = cr('#ffffff', t.base).toFixed(2);
  s += rtl(right, my, 'کنتراست متن سفید', 14, 400, '#646970');
  s += ltr(x + 16, my, ratio + ':1  AA', 14, 700, '#067a55');

  // button
  my += 20;
  const bw = CARD_W - 32;
  s += `<rect x="${x + 16}" y="${my}" width="${bw}" height="40" rx="11" fill="${live ? '#eef1f7' : '#1552d8'}"/>`;
  s += `<text x="${x + 16 + bw / 2}" y="${my + 26}" font-family="Vazirmatn" font-size="15" font-weight="700"
          fill="${live ? '#8c8f94' : '#ffffff'}" text-anchor="middle">${live ? 'در حال استفاده' : 'اعمال این تم'}</text>`;
});

// ---- custom theme card ----
const cy = GRID_TOP + rows * (CARD_H + GAP);
s += `<rect x="${PAD}" y="${cy}" width="${W - PAD * 2}" height="150" rx="16" fill="#ffffff" stroke="#e0e2e7" stroke-width="2"/>`;
s += rtl(W - PAD - 22, cy + 40, 'تم دلخواه', 20, 700, '#1d2327');
s += rtl(W - PAD - 22, cy + 68, 'فقط رنگ اصلی را انتخاب کنید؛ بقیه‌ی سایه‌ها خودکار ساخته می‌شوند.', 15, 400, '#646970');
s += rtl(W - PAD - 22, cy + 104, 'رنگ اصلی', 14, 400, '#3c434a');
s += `<rect x="${W - PAD - 190}" y="${cy + 88}" width="86" height="34" rx="9" fill="#1552d8" stroke="#c9ccd1"/>`;
s += rtl(W - PAD - 300, cy + 104, 'رنگ دکمه شناور', 14, 400, '#3c434a');
s += `<rect x="${W - PAD - 490}" y="${cy + 88}" width="86" height="34" rx="9" fill="#38a3ff" stroke="#c9ccd1"/>`;
s += `<rect x="${PAD + 22}" y="${cy + 88}" width="132" height="38" rx="11" fill="#1552d8"/>`;
s += `<text x="${PAD + 88}" y="${cy + 113}" font-family="Vazirmatn" font-size="15" font-weight="700" fill="#ffffff" text-anchor="middle">اعمال این تم</text>`;

s += `</svg>`;

ensureFonts().then(() => {
  fs.mkdirSync(OUT, { recursive: true });
  const png = new Resvg(s, {
    font: { fontDirs: [FONTS], defaultFontFamily: 'Vazirmatn', loadSystemFonts: false },
    fitTo: { mode: 'width', value: W }
  }).render().asPng();
  if (png.length < 20000) { console.error('render looks empty'); process.exit(1); }
  const f = path.join(OUT, 'admin-theme-page.png');
  fs.writeFileSync(f, png);
  console.log('✓ admin-theme-page.png', (png.length / 1024).toFixed(0) + 'K',
    '— themes read from source:', THEMES.map(t => t.id).join(', '));
}).catch(e => { console.error(e); process.exit(1); });
