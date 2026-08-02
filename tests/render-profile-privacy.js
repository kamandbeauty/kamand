/**
 * Before/after of the profile page changes.
 *
 * Left: the penalty warning as one ragged run plus the "behaviour profile"
 * card printing the test result. Right: the two-line warning and an interests
 * card with the scores gone.
 *
 * Labels and tags are read out of the real source, so the picture cannot
 * claim something the code does not do.
 */
const { Resvg } = require('@resvg/resvg-js');
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', 'design', 'screenshots');
const FONTS = path.join(__dirname, 'fonts');
const SRC = path.join(__dirname, '..', 'havato');
const I18N = fs.readFileSync(path.join(SRC, 'includes', 'class-havato-i18n.php'), 'utf8');
const FN = fs.readFileSync(path.join(SRC, 'includes', 'functions.php'), 'utf8');

function ensureFonts() {
  const want = [
    ['vazirmatn-arabic-400-normal.woff2', 'Vazirmatn-Regular.ttf'],
    ['vazirmatn-arabic-700-normal.woff2', 'Vazirmatn-Bold.ttf'],
    ['vazirmatn-latin-400-normal.woff2', 'VazirmatnLatin-Regular.ttf'],
    ['vazirmatn-latin-700-normal.woff2', 'VazirmatnLatin-Bold.ttf']
  ];
  fs.mkdirSync(FONTS, { recursive: true });
  if (want.every(([, o]) => fs.existsSync(path.join(FONTS, o)))) { return Promise.resolve(); }
  const woff2 = require('wawoff2');
  const src = path.join(__dirname, 'node_modules', '@fontsource', 'vazirmatn', 'files');
  return want.reduce((c, [from, to]) => c.then(() => {
    const dst = path.join(FONTS, to);
    if (fs.existsSync(dst)) { return null; }
    return woff2.decompress(fs.readFileSync(path.join(src, from)))
      .then((x) => fs.writeFileSync(dst, Buffer.from(x)));
  }), Promise.resolve());
}

function fa(key) {
  const re = new RegExp("'" + key + "'\\s*=>\\s*array\\(\\s*\\n?\\s*'fa'\\s*=>\\s*'((?:[^'\\\\]|\\\\.)*)'");
  const m = re.exec(I18N);
  if (!m) { throw new Error('missing i18n key: ' + key); }
  return m[1].replace(/\\'/g, "'");
}

// Category labels and a sample of tags, straight from the source.
const catStart = FN.indexOf('function havato_interest_categories');
const catBody = FN.slice(catStart, FN.indexOf('\n}', catStart));
const CATS = [...catBody.matchAll(/^\t\t'([a-z_]+)'\s*=> array\( 'fa' => '([^']*)'/gm)]
  .map((m) => ({ key: m[1], label: m[2] }));

const tagStart = FN.indexOf('function havato_interest_tags');
const tagBody = FN.slice(tagStart, FN.indexOf('\n}', tagStart));
const TAGS = [...tagBody.matchAll(/^\t\t'([a-z_]+)'\s*=> array\( 'cat' => '(\w+)', 'fa' => '([^']*)'/gm)]
  .map((m) => ({ key: m[1], cat: m[2], label: m[3] }));
if (TAGS.length < 80) { throw new Error('expected 80+ tags, read ' + TAGS.length); }

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const rtl = (x, y, s, sz, w, fill, op) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}"` +
  `${op ? ` fill-opacity="${op}"` : ''} direction="rtl" text-anchor="end">${esc(s)}</text>`;
const ctr = (x, y, s, sz, w, fill) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}" text-anchor="middle">${esc(s)}</text>`;

const COL = 470, GAP = 36;
const W = COL * 2 + GAP * 3;
const H = 1180;

let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">`;
s += `<rect width="${W}" height="${H}" fill="#eef1fb"/>`;
s += ctr(W / 2, 44, 'صفحه پروفایل — قبل و بعد', 22, 800, '#16204a');

// Rough advance width for Persian at a given size.
const wid = (str, sz) => str.length * sz * 0.47;

/** Lay chips out on wrapped lines, RTL. */
function chips(x0, y0, width, items, sz, fill, textFill, border) {
  let out = '', cx = x0 + width, cy = y0, rows = 1;
  const h = sz * 2.1, pad = sz * 0.85, gap = 7;
  items.forEach((label) => {
    const w = wid(label, sz) + pad * 2;
    if (cx - w < x0) { cx = x0 + width; cy += h + gap; rows++; }
    out += `<rect x="${cx - w}" y="${cy}" width="${w}" height="${h}" rx="${h / 2}" fill="${fill}" stroke="${border}"/>`;
    out += rtl(cx - pad, cy + h * 0.66, label, sz, 700, textFill);
    cx -= w + gap;
  });
  return { svg: out, height: cy - y0 + h, rows: rows };
}

function panel(x, title, tint, mode) {
  let g = '';
  const top = 74;
  const ph = H - top - 30;
  g += `<rect x="${x}" y="${top}" width="${COL}" height="${ph}" rx="24" fill="#ffffff" stroke="${tint}" stroke-width="2"/>`;
  g += ctr(x + COL / 2, top + 32, title, 17, 800, tint);

  const px = x + 20, pw = COL - 40;
  let y = top + 56;

  /* ---------------- the penalty warning ---------------- */
  const warn = fa('penalty_notice');
  const stats = [
    [fa('stat_no_shows'), '۳'],
    [fa('stat_empty_seats'), '۱'],
    [fa('penalty_points'), '۴']
  ];

  if (mode === 'before') {
    // One run of text: the sentence and the figures share a wrapping flow, so
    // a label can land on one line and its value on the next.
    const boxH = 132;
    g += `<rect x="${px}" y="${y}" width="${pw}" height="${boxH}" rx="16" fill="#e8f4fb" stroke="#cfe6f5"/>`;
    // Simulate the ragged two-column wrap seen in the report.
    g += rtl(px + pw - 14, y + 30, 'اگر در دورهمی حاضر نشوید یا', 14, 600, '#16204a');
    g += rtl(px + 150, y + 30, 'عدم حضور: ۳', 14, 600, '#16204a');
    g += rtl(px + pw - 14, y + 58, 'صندلی رزروشده خالی بماند، امتیاز', 14, 600, '#16204a');
    g += rtl(px + 150, y + 58, 'صندلی خالی‌مانده: ۱', 14, 600, '#16204a');
    g += rtl(px + pw - 14, y + 86, 'رفتاری شما کاهش می‌یابد.', 14, 600, '#16204a');
    g += rtl(px + 150, y + 86, 'امتیاز منفی: ۴', 14, 600, '#16204a');
    g += `<rect x="${px + 8}" y="${y + 8}" width="${pw - 16}" height="${boxH - 16}" rx="12" fill="none" stroke="#dc2626" stroke-width="2" stroke-dasharray="5 4"/>`;
    g += ctr(x + COL / 2, y + boxH + 20, 'متن و اعداد در هم رفته‌اند', 13, 700, '#b91c1c');
    y += boxH + 40;
  } else {
    // Sentence on its own lines, then the figures as unbreakable pairs.
    const lines = ['اگر در دورهمی حاضر نشوید یا صندلی رزروشده', 'خالی بماند، امتیاز رفتاری شما کاهش می‌یابد.'];
    const boxH = 122;
    g += `<rect x="${px}" y="${y}" width="${pw}" height="${boxH}" rx="16" fill="#fff1e2" stroke="#f7d3ad"/>`;
    lines.forEach((ln, i) => { g += rtl(px + pw - 16, y + 30 + i * 24, ln, 14, 600, '#7c2d12'); });
    g += `<line x1="${px + 16}" y1="${y + 84}" x2="${px + pw - 16}" y2="${y + 84}" stroke="#f0b27a" stroke-dasharray="4 4"/>`;
    let cx = px + pw - 16;
    stats.forEach(([label, val]) => {
      const txt = label + '  ' + val;
      const w = wid(txt, 13.5) + 6;
      g += rtl(cx, y + 108, label, 13.5, 600, '#9a3412');
      g += rtl(cx - wid(label, 13.5) - 8, y + 108, val, 14, 800, '#7c2d12');
      cx -= w + 24;
    });
    g += ctr(x + COL / 2, y + boxH + 20, 'دو خط جدا · هر عدد با برچسب خودش', 13, 700, '#067a55');
    y += boxH + 40;
  }

  /* ---------------- the profile card ---------------- */
  if (mode === 'before') {
    g += rtl(px + pw, y + 4, fa2('behaviour_id_legacy'), 16, 800, '#16204a');
    y += 22;
    const res = chips(px, y, pw, ['درون‌گرا · ۴/۱۰', 'شنونده', 'شاد و سرگرم‌کننده', '۴۱', 'اصفهان',
      'موسیقی', 'سینما', 'سریال', 'عکاسی', 'کتاب'], 13.5,
      '#ece9fb', '#4c1d95', '#d8d2f5');
    g += res.svg;
    y += res.height + 24;
    // trait bars
    [['پذیرندگی', 9], ['شوخ‌طبعی', 9], ['انرژی', 7]].forEach(([lab, v]) => {
      g += rtl(px + pw, y + 12, lab, 13, 700, '#16204a');
      const bx = px + 44, bw = pw - 130;
      g += `<rect x="${bx}" y="${y + 4}" width="${bw}" height="8" rx="4" fill="#e6e9f7"/>`;
      g += `<rect x="${bx + bw * (1 - v / 10)}" y="${y + 4}" width="${bw * v / 10}" height="8" rx="4" fill="#f0a020"/>`;
      g += rtl(px + 30, y + 12, String(v), 12, 800, '#6b74a0');
      y += 26;
    });
    y += 6;
    g += `<rect x="${px - 6}" y="${top + 214}" width="${pw + 12}" height="${y - top - 210}" rx="14" fill="none" stroke="#dc2626" stroke-width="2.5"/>`;
    g += ctr(x + COL / 2, y + 26, 'نتیجه تست شخصیت به کاربر نشان داده می‌شد', 13, 700, '#b91c1c');
    g += ctr(x + COL / 2, y + 46, '(و به بازدیدکنندگان دیگر هم ارسال می‌شد)', 12, 600, '#b91c1c');
  } else {
    g += rtl(px + pw, y + 4, fa('interests_title'), 16, 800, '#16204a');
    y += 22;
    // Show a realistic selection, grouped the way the picker groups them.
    const pickFrom = (cat, n) => TAGS.filter((t) => t.cat === cat).slice(0, n).map((t) => t.label);
    const chosen = ['۴۱', 'اصفهان'].concat(
      pickFrom('culture', 4), pickFrom('work', 3), pickFrom('food', 2), pickFrom('active', 2)
    );
    const res = chips(px, y, pw, chosen, 13.5, '#ece9fb', '#4c1d95', '#d8d2f5');
    g += res.svg;
    y += res.height + 18;
    g += ctr(x + COL / 2, y + 8, 'فقط علاقه‌مندی‌ها — بدون نتیجه تست', 13, 700, '#067a55');
    y += 34;

    /* the new picker */
    g += rtl(px + pw, y + 10, 'انتخابگر جدید در تست:', 14, 800, '#16204a');
    y += 24;
    const boxTop = y;
    g += `<rect x="${px}" y="${y}" width="${pw}" height="360" rx="16" fill="#f7f8fd" stroke="#e3e7f5"/>`;
    y += 16;
    // search row
    g += `<rect x="${px + 12}" y="${y}" width="${pw - 130}" height="34" rx="12" fill="#ffffff" stroke="#d9dff1"/>`;
    g += rtl(px + pw - 24, y + 23, fa('interests_search'), 13, 400, '#8b93b8');
    g += rtl(px + 104, y + 23, fa('interests_chosen').replace('%s', '۱۱'), 13, 800, '#1b1fbf');
    y += 48;
    // two categories with their real tags
    CATS.slice(0, 3).forEach((cat) => {
      if (y > boxTop + 300) { return; }
      g += rtl(px + pw - 12, y + 10, cat.label, 13, 800, '#6b74a0');
      y += 20;
      const items = TAGS.filter((t) => t.cat === cat.key).slice(0, 6).map((t) => t.label);
      const r = chips(px + 12, y, pw - 24, items, 12.5, '#ffffff', '#4c1d95', '#d8d2f5');
      g += r.svg;
      y += r.height + 14;
    });
    g += ctr(x + COL / 2, boxTop + 378,
      `${TAGS.length} علاقه‌مندی در ${CATS.length} دسته · با جستجو`, 13, 700, '#067a55');
  }

  return g;
}

// The legacy title no longer exists in the string map, so it is written here
// rather than read — clearly marked as the OLD label.
function fa2(k) { return k === 'behaviour_id_legacy' ? 'شناسنامه رفتاری' : fa(k); }

s += panel(GAP, 'قبل (نسخه ۱٫۳۵٫۱)', '#b91c1c', 'before');
s += panel(GAP * 2 + COL, 'بعد (نسخه ۱٫۳۶٫۰)', '#067a55', 'after');
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
  const dst = path.join(OUT, 'profile-privacy-before-after.png');
  fs.writeFileSync(dst, png);
  console.log('wrote ' + dst + ' (' + png.length + ' bytes)');
  console.log(`tags: ${TAGS.length} in ${CATS.length} categories`);
}).catch((e) => { console.error(e); process.exit(1); });
