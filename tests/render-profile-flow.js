/**
 * Mock-ups of the two reworked screens: the details editor (which now carries
 * the country/city pickers that were previously empty) and one step of the
 * longer personality test. Strings are pulled from class-havato-i18n.php so
 * the picture cannot drift from the shipped copy.
 */
const { Resvg } = require('@resvg/resvg-js');
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', 'design', 'screenshots');
const FONTS = path.join(__dirname, 'fonts');
const I18N = fs.readFileSync(path.join(__dirname, '..', 'havato', 'includes', 'class-havato-i18n.php'), 'utf8');

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

/** Persian string for an i18n key, straight out of the PHP. */
function fa(key) {
  const re = new RegExp("'" + key + "'\\s*=>\\s*array\\(\\s*\\n?\\s*'fa'\\s*=>\\s*'((?:[^'\\\\]|\\\\.)*)'");
  const m = re.exec(I18N);
  if (!m) { throw new Error('i18n key not found: ' + key); }
  return m[1].replace(/\\'/g, "'");
}

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const rtl = (x, y, s, sz, w, fill, op) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}"${op ? ` fill-opacity="${op}"` : ''} direction="rtl" text-anchor="end">${esc(s)}</text>`;
const ctr = (x, y, s, sz, w, fill, op) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}"${op ? ` fill-opacity="${op}"` : ''} direction="rtl" text-anchor="middle">${esc(s)}</text>`;

// Azure theme (the shipped default).
const T = { light: '#2f74f7', base: '#1552d8', deep: '#0a2a6b', accent: '#38a3ff', canvas: '#eef1fb' };
const W = 720, H = 1280;

function shell(inner, title) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <defs>
    <linearGradient id="hdr" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${T.light}"/><stop offset=".48" stop-color="${T.base}"/><stop offset="1" stop-color="${T.deep}"/></linearGradient>
    <linearGradient id="btn" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="${T.light}"/><stop offset="1" stop-color="${T.base}"/></linearGradient>
  </defs>
  <rect width="${W}" height="${H}" fill="${T.canvas}"/>
  <path d="M0 0 H${W} V196 Q${W} 226 ${W - 30} 226 H30 Q0 226 0 196 Z" fill="url(#hdr)"/>
  ${ctr(W / 2, 42, '۱۲:۳۸', 20, 500, '#ffffff', '0.9')}
  ${rtl(W - 34, 118, 'هواتو', 19, 400, '#ffffff', '0.85')}
  ${rtl(W - 34, 156, title, 31, 700, '#ffffff')}
  ${inner}
</svg>`;
}

/* ---------------- screen 1: details editor ---------------- */
function detailsScreen() {
  let s = '';
  const x = 34, w = W - 68;
  let y = 262;

  s += `<rect x="${x}" y="${y}" width="${w}" height="${H - y - 40}" rx="30" fill="#ffffff"/>`;
  let iy = y + 58;
  s += rtl(x + w - 26, iy, fa('details_title'), 27, 700, '#16204a');
  iy += 38;
  s += rtl(x + w - 26, iy, fa('details_hint').slice(0, 46) + '…', 16, 400, '#6b74a0');

  // name
  iy += 46;
  s += rtl(x + w - 26, iy, fa('q_name'), 17, 700, '#16204a');
  iy += 16;
  s += `<rect x="${x + 26}" y="${iy}" width="${w - 52}" height="54" rx="15" fill="#f7f9ff" stroke="#dfe6f7" stroke-width="2"/>`;
  s += rtl(x + w - 44, iy + 35, 'javid Film', 19, 400, '#16204a');

  // age
  iy += 76;
  s += rtl(x + w - 26, iy, fa('q_age'), 17, 700, '#16204a');
  iy += 16;
  s += `<rect x="${x + 26}" y="${iy}" width="${w - 52}" height="54" rx="15" fill="#f7f9ff" stroke="#dfe6f7" stroke-width="2"/>`;
  s += rtl(x + w - 44, iy + 35, '۲۹', 19, 400, '#16204a');
  s += `<path d="M ${x + 50} ${iy + 24} l 10 10 l 10 -10" fill="none" stroke="#6b74a0" stroke-width="2.5" stroke-linecap="round"/>`;

  // gender
  iy += 80;
  s += rtl(x + w - 26, iy, fa('q_gender'), 17, 700, '#16204a');
  iy += 16;
  const gw = (w - 52 - 20) / 3;
  [[fa('gender_male'), true], [fa('gender_female'), false], [fa('gender_other'), false]].forEach((g, i) => {
    const gx = x + 26 + i * (gw + 10);
    s += `<rect x="${gx}" y="${iy}" width="${gw}" height="52" rx="14" fill="${g[1] ? 'url(#btn)' : '#f7f9ff'}" stroke="${g[1] ? 'none' : '#dfe6f7'}" stroke-width="2"/>`;
    s += ctr(gx + gw / 2, iy + 34, g[0], 16, 700, g[1] ? '#ffffff' : '#16204a');
  });

  // country  <- the pickers that used to be missing entirely
  iy += 78;
  s += rtl(x + w - 26, iy, fa('q_country'), 17, 700, '#16204a');
  iy += 16;
  const cw = (w - 52 - 10) / 2;
  [['ایران', true], ['ترکیه', false]].forEach((c, i) => {
    const cx = x + 26 + i * (cw + 10);
    s += `<rect x="${cx}" y="${iy}" width="${cw}" height="52" rx="14" fill="${c[1] ? 'url(#btn)' : '#f7f9ff'}" stroke="${c[1] ? 'none' : '#dfe6f7'}" stroke-width="2"/>`;
    s += ctr(cx + cw / 2, iy + 34, c[0], 17, 700, c[1] ? '#ffffff' : '#16204a');
  });

  // city
  iy += 76;
  s += rtl(x + w - 26, iy, fa('q_city_select'), 17, 700, '#16204a');
  iy += 16;
  [['تهران', true], ['اصفهان', false]].forEach((c, i) => {
    const cx = x + 26 + i * (cw + 10);
    s += `<rect x="${cx}" y="${iy}" width="${cw}" height="52" rx="14" fill="${c[1] ? 'url(#btn)' : '#f7f9ff'}" stroke="${c[1] ? 'none' : '#dfe6f7'}" stroke-width="2"/>`;
    s += ctr(cx + cw / 2, iy + 34, c[0], 17, 700, c[1] ? '#ffffff' : '#16204a');
  });

  // save
  iy += 86;
  s += `<rect x="${x + 26}" y="${iy}" width="${w - 52}" height="58" rx="16" fill="url(#btn)"/>`;
  s += ctr(W / 2, iy + 38, fa('save'), 20, 700, '#ffffff');

  return shell(s, fa('details_title'));
}

/* ---------------- screen 2: personality test ---------------- */
function testScreen() {
  let s = '';
  const x = 34, w = W - 68;
  const y = 300;

  s += `<rect x="${x}" y="${y}" width="${w}" height="560" rx="30" fill="#ffffff"/>`;
  let iy = y + 56;
  s += ctr(W / 2, iy, fa('test_intro_title'), 26, 700, '#16204a');

  // 9 progress dots, 3 done
  iy += 34;
  const n = 9, dw = 26, gap = 8;
  const total = n * dw + (n - 1) * gap;
  for (let i = 0; i < n; i++) {
    s += `<rect x="${W / 2 - total / 2 + i * (dw + gap)}" y="${iy}" width="${dw}" height="7" rx="4"
            fill="${i <= 2 ? T.base : '#dfe6f7'}"/>`;
  }

  // question
  iy += 62;
  s += ctr(W / 2, iy, fa('q_openness'), 22, 700, '#16204a');

  // slider
  iy += 62;
  s += rtl(x + w - 40, iy, fa('openness_high'), 16, 400, '#6b74a0');
  s += `<text x="${x + 40}" y="${iy}" font-family="Vazirmatn" font-size="16" fill="#6b74a0">${esc(fa('openness_low'))}</text>`;
  s += ctr(W / 2, iy + 2, '۷', 26, 800, T.base);

  iy += 34;
  s += `<rect x="${x + 40}" y="${iy}" width="${w - 80}" height="10" rx="5" fill="#e4eaf8"/>`;
  s += `<rect x="${x + 40}" y="${iy}" width="${(w - 80) * 0.7}" height="10" rx="5" fill="url(#btn)"/>`;
  s += `<circle cx="${x + 40 + (w - 80) * 0.7}" cy="${iy + 5}" r="17" fill="#ffffff" stroke="${T.base}" stroke-width="4"/>`;

  // buttons
  iy += 74;
  const bw = (w - 52 - 12) / 3;
  s += `<rect x="${x + 26}" y="${iy}" width="${bw}" height="56" rx="15" fill="#eef1f7"/>`;
  s += ctr(x + 26 + bw / 2, iy + 37, fa('prev'), 18, 700, '#475569');
  s += `<rect x="${x + 26 + bw + 12}" y="${iy}" width="${bw * 2}" height="56" rx="15" fill="url(#btn)"/>`;
  s += ctr(x + 26 + bw + 12 + bw, iy + 37, fa('next'), 19, 700, '#ffffff');

  // trait preview card
  const cy = y + 590;
  s += `<rect x="${x}" y="${cy}" width="${w}" height="300" rx="30" fill="#ffffff"/>`;
  s += rtl(x + w - 26, cy + 50, fa('behaviour_id'), 22, 700, '#16204a');
  const bars = [
    [fa('trait_openness'), 7], [fa('trait_humor'), 8], [fa('trait_energy'), 5],
    [fa('trait_planning'), 4], [fa('trait_empathy'), 9]
  ];
  bars.forEach((b, i) => {
    const by = cy + 84 + i * 40;
    s += rtl(x + w - 26, by + 14, b[0], 16, 700, '#16204a');
    const bx = x + 40, bwid = w - 200;
    s += `<rect x="${bx}" y="${by + 5}" width="${bwid}" height="9" rx="5" fill="#e4eaf8"/>`;
    s += `<rect x="${bx + bwid * (1 - b[1] / 10)}" y="${by + 5}" width="${bwid * (b[1] / 10)}" height="9" rx="5" fill="url(#btn)"/>`;
    s += `<text x="${bx - 8}" y="${by + 15}" font-family="Vazirmatn" font-size="15" font-weight="800" fill="#6b74a0" text-anchor="end">${esc(String(b[1]))}</text>`;
  });

  return shell(s, fa('test_intro_title'));
}

ensureFonts().then(() => {
  fs.mkdirSync(OUT, { recursive: true });
  const jobs = [['profile-details-editor.png', detailsScreen()], ['personality-test.png', testScreen()]];
  for (const [name, svg] of jobs) {
    const png = new Resvg(svg, {
      font: { fontDirs: [FONTS], defaultFontFamily: 'Vazirmatn', loadSystemFonts: false },
      fitTo: { mode: 'width', value: W }
    }).render().asPng();
    if (png.length < 15000) { console.error('render looks empty: ' + name); process.exit(1); }
    fs.writeFileSync(path.join(OUT, name), png);
    console.log('✓', name, (png.length / 1024).toFixed(0) + 'K');
  }
}).catch(e => { console.error(e.message || e); process.exit(1); });
