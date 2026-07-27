/**
 * Mock-up of the reworked Explore card (title + theme + free badge + the
 * renamed reserve button) and the new seat picker, in the Emerald theme the
 * user is currently running. Strings and colours are read from the source so
 * the picture cannot drift from the code.
 */
const { Resvg } = require('@resvg/resvg-js');
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', 'design', 'screenshots');
const FONTS = path.join(__dirname, 'fonts');
const I18N = fs.readFileSync(path.join(__dirname, '..', 'havato', 'includes', 'class-havato-i18n.php'), 'utf8');
const THEMES = fs.readFileSync(path.join(__dirname, '..', 'havato', 'includes', 'class-havato-themes.php'), 'utf8');

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

/** Pull the emerald palette straight out of the theme registry. */
function palette(id) {
  const i = THEMES.indexOf("'" + id + "' => array(");
  const body = THEMES.slice(i, i + 1400);
  const g = k => (new RegExp("'" + k + "'\\s*=>\\s*'(#[0-9a-fA-F]{6})'").exec(body) || [])[1];
  return { light: g('light'), base: g('base'), deep: g('deep'), accent: g('accent'), canvas: g('canvas') };
}
const T = palette('emerald');
if (!T.base) { console.error('could not read the emerald palette'); process.exit(1); }

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const rtl = (x, y, s, sz, w, fill, op) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}"${op ? ` fill-opacity="${op}"` : ''} direction="rtl" text-anchor="end">${esc(s)}</text>`;
const ltr = (x, y, s, sz, w, fill) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}">${esc(s)}</text>`;
const ctr = (x, y, s, sz, w, fill) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}" direction="rtl" text-anchor="middle">${esc(s)}</text>`;

const W = 720, H = 1280;

/** One Explore card. */
function card(y, opts) {
  const x = 30, w = W - 60, h = 268;
  let s = `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="26" fill="#ffffff"/>`;

  // thumb
  s += `<rect x="${x + w - 104}" y="${y + 22}" width="80" height="80" rx="22" fill="url(#th)"/>`;
  s += `<circle cx="${x + w - 64}" cy="${y + 56}" r="13" fill="#ffffff" fill-opacity="0.9"/>`;
  s += `<rect x="${x + w - 78}" y="${y + 70}" width="28" height="7" rx="3.5" fill="#ffffff" fill-opacity="0.9"/>`;

  s += rtl(x + w - 120, y + 50, opts.venue, 24, 700, '#12312a');
  // NEW: the gathering's own title
  s += rtl(x + w - 120, y + 80, opts.title, 19, 700, T.base);
  s += rtl(x + w - 120, y + 108, opts.when, 17, 400, '#5f8078');

  // badges: status + NEW theme + atmosphere
  let bx = x + w - 120;
  const badge = (label, fill, ink) => {
    const bw = Math.max(58, label.length * 13 + 26);
    bx -= bw;
    let out = `<rect x="${bx}" y="${y + 124}" width="${bw}" height="34" rx="17" fill="${fill}"/>`;
    out += ctr(bx + bw / 2, y + 147, label, 16, 700, ink);
    bx -= 8;
    return out;
  };
  s += badge(opts.status, '#e3faf1', '#067a55');
  s += badge(opts.theme, '#ffe9f2', '#be2f63');
  s += badge(opts.tier, '#e6f7f3', T.base);

  // seat bar
  s += `<rect x="${x + 24}" y="${y + 174}" width="${w - 48}" height="8" rx="4" fill="#e4eee9"/>`;
  s += `<rect x="${x + w - 24 - (w - 48) * opts.pct}" y="${y + 174}" width="${(w - 48) * opts.pct}" height="8" rx="4" fill="url(#bar)"/>`;

  // foot
  s += rtl(x + w - 24, y + 218, opts.seats, 18, 400, '#5f8078');
  s += rtl(x + w - 24, y + 246, fa('free'), 18, 800, '#0b7a5e');

  // the renamed button, white text + dark halo
  const bw2 = 250, bh = 56, bx2 = x + 24, by = y + 196;
  s += `<rect x="${bx2}" y="${by}" width="${bw2}" height="${bh}" rx="16" fill="url(#btn)"/>`;
  s += `<text x="${bx2 + bw2 / 2}" y="${by + 37}" font-family="Vazirmatn" font-size="21" font-weight="700"
          fill="#ffffff" text-anchor="middle" direction="rtl"
          style="paint-order:stroke" stroke="rgba(10,14,48,0.55)" stroke-width="2.4">${esc(fa('join_event'))}</text>`;
  return s;
}

function exploreScreen() {
  let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <defs>
    <linearGradient id="hdr" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${T.light}"/><stop offset=".48" stop-color="${T.base}"/><stop offset="1" stop-color="${T.deep}"/></linearGradient>
    <linearGradient id="btn" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="${T.light}"/><stop offset="1" stop-color="${T.base}"/></linearGradient>
    <linearGradient id="bar" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="${T.light}"/><stop offset="1" stop-color="${T.base}"/></linearGradient>
    <linearGradient id="th" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${T.light}"/><stop offset="1" stop-color="${T.deep}"/></linearGradient>
    <linearGradient id="nav" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${T.base}"/><stop offset="1" stop-color="${T.deep}"/></linearGradient>
    <linearGradient id="fab" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#4ce0b6"/><stop offset="1" stop-color="${T.accent}"/></linearGradient>
  </defs>
  <rect width="${W}" height="${H}" fill="${T.canvas}"/>
  <path d="M0 0 H${W} V196 Q${W} 226 ${W - 30} 226 H30 Q0 226 0 196 Z" fill="url(#hdr)"/>
  ${ctr(W / 2, 42, '۲:۴۶', 20, 500, '#ffffff')}
  ${rtl(W - 34, 118, 'هواتو', 19, 400, '#ffffff')}
  ${rtl(W - 34, 156, 'دورهمی‌های این هفته', 30, 700, '#ffffff')}`;

  s += card(258, {
    venue: 'کافه ناروان', title: 'شب موسیقی و گفتگو',
    when: 'چهارشنبه ۷ مرداد ۱۴۰۵ · ۱۸:۰۰',
    status: 'باز', theme: 'موسیقی', tier: 'دنج',
    seats: '۱۴ صندلی خالی', pct: 0.1
  });
  s += card(546, {
    venue: 'کافه مسو قالی', title: 'میز کتاب‌خوان‌ها',
    when: 'پنج‌شنبه ۸ مرداد ۱۴۰۵ · ۱۸:۰۰',
    status: 'باز', theme: 'کتاب', tier: 'لاکچری',
    seats: '۱۱ صندلی خالی', pct: 0.3
  });
  s += card(834, {
    venue: 'کافه لفته', title: 'عصرانه استارتاپی',
    when: 'پنج‌شنبه ۸ مرداد ۱۴۰۵ · ۱۸:۰۰',
    status: 'باز', theme: 'استارتاپ', tier: 'معمولی',
    seats: '۹ صندلی خالی', pct: 0.45
  });

  // bottom nav, white labels with a halo and no tap square
  const navTop = H - 132, fabCx = W / 2, fabCy = navTop + 4, fabR = 46, notch = fabR + 12;
  s += `<path d="M0 ${navTop} H${fabCx - notch - 26}
      Q${fabCx - notch - 4} ${navTop} ${fabCx - notch + 2} ${navTop + 16}
      A ${notch} ${notch} 0 0 0 ${fabCx + notch - 2} ${navTop + 16}
      Q${fabCx + notch + 4} ${navTop} ${fabCx + notch + 26} ${navTop}
      H${W} V${H} H0 Z" fill="url(#nav)"/>`;
  const labels = ['پروفایل من', 'گفتگوها', 'نقشه', 'کاوش'];
  const slot = W / 4;
  labels.forEach((L, i) => {
    const cx = slot * i + slot / 2;
    s += `<circle cx="${cx}" cy="${navTop + 46}" r="11" fill="none" stroke="#ffffff" stroke-width="2.4"/>`;
    s += `<text x="${cx}" y="${navTop + 92}" font-family="Vazirmatn" font-size="18" font-weight="700"
            fill="#ffffff" text-anchor="middle" direction="rtl"
            style="paint-order:stroke" stroke="rgba(10,14,48,0.5)" stroke-width="2">${esc(L)}</text>`;
  });
  s += `<rect x="${slot * 3.5 - 22}" y="${navTop + 104}" width="44" height="5" rx="3" fill="#ffffff"/>`;
  s += `<circle cx="${fabCx}" cy="${fabCy}" r="${fabR + 7}" fill="${T.canvas}"/>`;
  s += `<circle cx="${fabCx}" cy="${fabCy}" r="${fabR}" fill="url(#fab)"/>`;
  s += `<path d="M ${fabCx - 17} ${fabCy} h 34 M ${fabCx} ${fabCy - 17} v 34" stroke="#ffffff" stroke-width="5.5" stroke-linecap="round"/>`;

  return s + '</svg>';
}

function reserveScreen() {
  const x = 40, w = W - 80;
  let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <defs>
    <linearGradient id="btn" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="${T.light}"/><stop offset="1" stop-color="${T.base}"/></linearGradient>
  </defs>
  <rect width="${W}" height="${H}" fill="rgba(10,20,16,0.55)"/>`;

  const top = 470;
  s += `<path d="M${x} ${top + 34} Q${x} ${top} ${x + 34} ${top} H${x + w - 34} Q${x + w} ${top} ${x + w} ${top + 34} V${H} H${x} Z" fill="#ffffff"/>`;
  s += `<rect x="${W / 2 - 22}" y="${top + 18}" width="44" height="5" rx="3" fill="#c9dcd4"/>`;

  let y = top + 78;
  s += rtl(x + w - 28, y, fa('reserve_title'), 26, 700, '#12312a');
  y += 52;
  s += rtl(x + w - 28, y, fa('how_many_seats'), 20, 700, '#12312a');

  y += 26;
  const cw = (w - 56 - 24) / 3;
  const opts = [fa('seat_one'), fa('seat_n').replace('%s', '۲'), fa('seat_n').replace('%s', '۳')];
  opts.forEach((label, i) => {
    const cx = x + 28 + i * (cw + 12);
    const on = i === 1;
    s += `<rect x="${cx}" y="${y}" width="${cw}" height="62" rx="16" fill="${on ? 'url(#btn)' : '#f2f8f6'}" stroke="${on ? 'none' : '#dbe8e3'}" stroke-width="2"/>`;
    s += `<text x="${cx + cw / 2}" y="${y + 40}" font-family="Vazirmatn" font-size="19" font-weight="700"
            fill="${on ? '#ffffff' : '#12312a'}" text-anchor="middle" direction="rtl"${on ? ' style="paint-order:stroke" stroke="rgba(10,14,48,0.5)" stroke-width="2"' : ''}>${esc(label)}</text>`;
  });

  y += 100;
  s += rtl(x + w - 28, y, fa('seats_hint').replace('%s', '۳'), 17, 400, '#5f8078');

  y += 44;
  s += `<rect x="${x + 28}" y="${y}" width="${w - 56}" height="62" rx="17" fill="url(#btn)"/>`;
  s += `<text x="${W / 2}" y="${y + 41}" font-family="Vazirmatn" font-size="21" font-weight="700"
          fill="#ffffff" text-anchor="middle" direction="rtl"
          style="paint-order:stroke" stroke="rgba(10,14,48,0.55)" stroke-width="2.4">${esc(fa('confirm_reserve'))}</text>`;

  return s + '</svg>';
}

ensureFonts().then(() => {
  fs.mkdirSync(OUT, { recursive: true });
  for (const [name, svg] of [['explore-cards.png', exploreScreen()], ['reserve-seats.png', reserveScreen()]]) {
    const png = new Resvg(svg, {
      font: { fontDirs: [FONTS], defaultFontFamily: 'Vazirmatn', loadSystemFonts: false },
      fitTo: { mode: 'width', value: W }
    }).render().asPng();
    if (png.length < 15000) { console.error('render looks empty: ' + name); process.exit(1); }
    fs.writeFileSync(path.join(OUT, name), png);
    console.log('✓', name, (png.length / 1024).toFixed(0) + 'K');
  }
}).catch(e => { console.error(e.message || e); process.exit(1); });
