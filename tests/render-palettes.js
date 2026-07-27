/**
 * Renders one PNG mock-up per candidate palette, reproducing the exact screen
 * the user photographed (header, profile card, 3 stat cards, CTA, wave nav,
 * FAB) so the palettes can be compared like-for-like.
 *
 * No browser is available in this sandbox, so the mock-up is authored as SVG
 * and rasterised with resvg. Persian text is shaped by the bundled Vazirmatn
 * TTF; the star/middot glyphs are missing from that subset so they are drawn
 * as vector shapes instead of characters.
 */
const { Resvg } = require('@resvg/resvg-js');
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', 'design', 'screenshots');
const FONTS = path.join(__dirname, 'fonts');

/**
 * resvg needs real font files. @fontsource ships woff2, so decompress the
 * Arabic + Latin subsets to TTF on first run. Without this the renderer
 * silently drops EVERY glyph and writes a mock-up with no text at all, so the
 * result is verified below rather than trusted.
 */
function ensureFonts() {
  const want = [
    ['vazirmatn-arabic-400-normal.woff2', 'Vazirmatn-Regular.ttf'],
    ['vazirmatn-arabic-700-normal.woff2', 'Vazirmatn-Bold.ttf'],
    ['vazirmatn-latin-400-normal.woff2', 'VazirmatnLatin-Regular.ttf'],
    ['vazirmatn-latin-700-normal.woff2', 'VazirmatnLatin-Bold.ttf']
  ];
  fs.mkdirSync(FONTS, { recursive: true });
  if (want.every(([, out]) => fs.existsSync(path.join(FONTS, out)))) { return Promise.resolve(); }

  const woff2 = require('wawoff2');
  const src = path.join(__dirname, 'node_modules', '@fontsource', 'vazirmatn', 'files');
  return want.reduce((chain, [from, to]) => chain.then(() => {
    const dst = path.join(FONTS, to);
    if (fs.existsSync(dst)) { return null; }
    return woff2.decompress(fs.readFileSync(path.join(src, from)))
      .then(ttf => fs.writeFileSync(dst, Buffer.from(ttf)));
  }), Promise.resolve());
}

const W = 720, H = 1280;

const PALETTES = [
  {
    id: 1, file: '1-azure', name: 'آبی اَزور',
    lo: '#2f74f7', mid: '#1552d8', deep: '#0a2a6b',
    fabA: '#5fbcff', fabB: '#38a3ff',
    soft: ['#e6efff', '#fff0e6', '#e6f6ff'],
    ctaA: '#2f74f7', ctaB: '#1552d8', ctaInk: '#ffffff'
  },
  {
    id: 2, file: '2-emerald', name: 'سبز زمردی',
    lo: '#16b98d', mid: '#0b7a5e', deep: '#053b2d',
    fabA: '#4ce0b6', fabB: '#16b98d',
    soft: ['#e3faf1', '#fff6e0', '#e6f7f3'],
    ctaA: '#16b98d', ctaB: '#0b7a5e', ctaInk: '#ffffff'
  },
  {
    id: 3, file: '3-espresso', name: 'اسپرسو',
    lo: '#a3653f', mid: '#7a4a2e', deep: '#31201a',
    fabA: '#f0a86a', fabB: '#e08b4c',
    soft: ['#f6ece3', '#e6f6f6', '#faf0e4'],
    ctaA: '#a3653f', ctaB: '#7a4a2e', ctaInk: '#ffffff'
  },
  {
    id: 4, file: '4-midnight-amber', name: 'نیلی شب + کهربا',
    lo: '#2c477f', mid: '#1c2f5e', deep: '#0d1730',
    fabA: '#f7bd52', fabB: '#f0a92b',
    soft: ['#e8ecf5', '#fdf1dc', '#e4f4fd'],
    ctaA: '#f0a92b', ctaB: '#d98f14', ctaInk: '#3d2600'
  },
  {
    id: 5, file: '5-coral', name: 'مرجانی غروب',
    lo: '#f26a76', mid: '#c53a52', deep: '#6b1830',
    fabA: '#ffa98a', fabB: '#ff9068',
    soft: ['#fdeaed', '#e6f6f6', '#fff0e8'],
    ctaA: '#f26a76', ctaB: '#c53a52', ctaInk: '#ffffff'
  }
];

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

/** RTL text anchored to the right edge. */
function rtl(x, y, str, size, weight, fill, opacity) {
  return `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${size}" ` +
    `font-weight="${weight}" fill="${fill}"${opacity ? ` fill-opacity="${opacity}"` : ''} ` +
    `direction="rtl" text-anchor="end" xml:space="preserve">${esc(str)}</text>`;
}
function ctr(x, y, str, size, weight, fill, opacity) {
  return `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${size}" ` +
    `font-weight="${weight}" fill="${fill}"${opacity ? ` fill-opacity="${opacity}"` : ''} ` +
    `direction="rtl" text-anchor="middle" xml:space="preserve">${esc(str)}</text>`;
}

/** Five-pointed star as a path (the font subset has no ★). */
function star(cx, cy, r, fill) {
  let d = '';
  for (let i = 0; i < 10; i++) {
    const rad = i % 2 ? r * 0.42 : r;
    const a = (Math.PI / 5) * i - Math.PI / 2;
    d += (i ? 'L' : 'M') + (cx + rad * Math.cos(a)).toFixed(2) + ' ' + (cy + rad * Math.sin(a)).toFixed(2) + ' ';
  }
  return `<path d="${d}Z" fill="${fill}"/>`;
}

/** Simple avatar glyph: head + shoulders inside a circle. */
function avatar(cx, cy, r, ring) {
  return `
  <circle cx="${cx}" cy="${cy}" r="${r}" fill="#ffffff" fill-opacity="0.22"
          stroke="#ffffff" stroke-opacity="${ring}" stroke-width="${Math.max(2, r * 0.07)}"/>
  <circle cx="${cx}" cy="${cy - r * 0.22}" r="${r * 0.31}" fill="#ffffff" fill-opacity="0.92"/>
  <path d="M ${cx - r * 0.52} ${cy + r * 0.62}
           a ${r * 0.52} ${r * 0.46} 0 0 1 ${r * 1.04} 0 Z"
        fill="#ffffff" fill-opacity="0.92"/>`;
}

function statIcon(x, y, size, bg, glyph) {
  const c = x + size / 2, m = y + size / 2;
  let inner = '';
  if (glyph === 'wallet') {
    inner = `<rect x="${c - size * 0.22}" y="${m - size * 0.16}" width="${size * 0.44}" height="${size * 0.32}" rx="${size * 0.07}" fill="#5b7cff"/>
             <circle cx="${c + size * 0.13}" cy="${m}" r="${size * 0.055}" fill="#ffffff"/>`;
  } else if (glyph === 'star') {
    inner = star(c, m, size * 0.24, '#f5a524');
  } else {
    inner = `<circle cx="${c - size * 0.11}" cy="${m - size * 0.06}" r="${size * 0.11}" fill="#5b7cff"/>
             <circle cx="${c + size * 0.13}" cy="${m - size * 0.03}" r="${size * 0.085}" fill="#8aa6ff"/>
             <path d="M ${c - size * 0.26} ${m + size * 0.21} a ${size * 0.16} ${size * 0.13} 0 0 1 ${size * 0.30} 0 Z" fill="#5b7cff"/>`;
  }
  return `<rect x="${x}" y="${y}" width="${size}" height="${size}" rx="${size * 0.3}" fill="${bg}"/>${inner}`;
}

/** Bottom nav glyphs, monochrome white. */
function navIcon(kind, cx, cy, s) {
  const w = 2.4;
  const st = `fill="none" stroke="#ffffff" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"`;
  if (kind === 'profile') {
    return `<circle cx="${cx}" cy="${cy - s * 0.22}" r="${s * 0.26}" ${st}/>
            <path d="M ${cx - s * 0.44} ${cy + s * 0.52} a ${s * 0.44} ${s * 0.38} 0 0 1 ${s * 0.88} 0" ${st}/>`;
  }
  if (kind === 'chat') {
    return `<path d="M ${cx - s * 0.5} ${cy - s * 0.38} h ${s} a ${s * 0.16} ${s * 0.16} 0 0 1 ${s * 0.16} ${s * 0.16}
             v ${s * 0.5} a ${s * 0.16} ${s * 0.16} 0 0 1 -${s * 0.16} ${s * 0.16} h -${s * 0.62}
             l -${s * 0.3} ${s * 0.3} v -${s * 0.3} a ${s * 0.16} ${s * 0.16} 0 0 1 -${s * 0.08} -${s * 0.16}
             v -${s * 0.5} a ${s * 0.16} ${s * 0.16} 0 0 1 ${s * 0.16} -${s * 0.16} Z" ${st}/>`;
  }
  if (kind === 'map') {
    return `<path d="M ${cx} ${cy + s * 0.52} c ${s * 0.42} -${s * 0.5} ${s * 0.42} -${s * 0.78} 0 -${s * 1.0}
             c -${s * 0.42} ${s * 0.22} -${s * 0.42} ${s * 0.5} 0 ${s * 1.0} Z" ${st}/>
            <circle cx="${cx}" cy="${cy - s * 0.18}" r="${s * 0.15}" ${st}/>`;
  }
  return `<circle cx="${cx}" cy="${cy}" r="${s * 0.46}" ${st}/>
          <path d="M ${cx + s * 0.2} ${cy - s * 0.2} l -${s * 0.12} ${s * 0.34} l -${s * 0.34} ${s * 0.12}
           l ${s * 0.12} -${s * 0.34} Z" ${st}/>`;
}

function build(p) {
  const g = (id, a, b, x2 = '1', y2 = '1') =>
    `<linearGradient id="${id}" x1="0" y1="0" x2="${x2}" y2="${y2}">
       <stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient>`;

  const R = W - 40;            // right gutter
  const navH = 132;
  const navTop = H - navH;

  // ---- header ----
  const headH = 300;
  let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <defs>
    ${g('hdr', p.lo, p.deep)}
    ${g('card', p.lo, p.deep)}
    ${g('cta', p.ctaA, p.ctaB)}
    ${g('nav', p.mid, p.deep)}
    ${g('fab', p.fabA, p.fabB)}
    <clipPath id="head"><path d="M0 0 H${W} V${headH - 34} Q${W} ${headH} ${W - 34} ${headH}
      H34 Q0 ${headH} 0 ${headH - 34} Z"/></clipPath>
    <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.18"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
    </radialGradient>
  </defs>

  <rect width="${W}" height="${H}" fill="#eef1fb"/>

  <g clip-path="url(#head)">
    <rect width="${W}" height="${headH}" fill="url(#hdr)"/>
    <ellipse cx="${W * 0.86}" cy="${headH * 0.16}" rx="${W * 0.42}" ry="${headH * 0.62}" fill="url(#glow)"/>
  </g>`;

  // status bar
  s += ctr(W / 2, 40, '۱۲:۳۸', 21, 500, '#ffffff', '0.92');

  // header row
  s += avatar(W - 74, 128, 40, 0.6);
  s += rtl(W - 134, 112, 'هواتو', 20, 400, '#ffffff', '0.85');
  s += rtl(W - 134, 150, 'پروفایل من', 33, 700, '#ffffff');
  // EN pill
  s += `<rect x="40" y="100" width="82" height="56" rx="18" fill="#ffffff" fill-opacity="0.16"
          stroke="#ffffff" stroke-opacity="0.42" stroke-width="2"/>`;
  s += ctr(81, 137, 'EN', 22, 700, '#ffffff');

  // ---- profile card (the one circled in red) ----
  const cardY = headH + 34, cardH = 132;
  s += `<rect x="40" y="${cardY}" width="${R - 40}" height="${cardH}" rx="30" fill="url(#card)"/>`;
  s += avatar(W - 118, cardY + cardH / 2, 46, 0.55);
  s += rtl(W - 196, cardY + 58, 'javid Film', 27, 700, '#ffffff');
  // "★ ۵٫۰ · ۰ دورهمی حاضر شده"
  const metaY = cardY + 94;
  s += rtl(W - 196, metaY, '۵٫۰', 20, 400, '#ffffff', '0.88');
  s += star(W - 248, metaY - 7, 11, '#ffffff');
  s += rtl(W - 278, metaY, '۰ دورهمی حاضر شده', 20, 400, '#ffffff', '0.88');
  s += `<circle cx="${W - 268}" cy="${metaY - 7}" r="3" fill="#ffffff" fill-opacity="0.8"/>`;

  // ---- 3 stat cards ----
  const sy = cardY + cardH + 22, sh = 176, gap = 16;
  const sw = (R - 40 - gap * 2) / 3;
  const stats = [
    { v: 'رایگان', l: 'مجموع پرداخت‌ها', g: 'wallet' },
    { v: '۵',      l: 'امتیاز رفتاری',    g: 'star' },
    { v: '۰',      l: 'تاریخچه دورهمی‌ها', g: 'users' }
  ];
  stats.forEach((st, i) => {
    const x = 40 + i * (sw + gap);
    s += `<rect x="${x}" y="${sy}" width="${sw}" height="${sh}" rx="26" fill="#ffffff"/>`;
    s += statIcon(x + sw / 2 - 28, sy + 26, 56, p.soft[i], st.g);
    s += ctr(x + sw / 2, sy + 126, st.v, 24, 700, '#16204a');
    s += ctr(x + sw / 2, sy + 156, st.l, 16, 400, '#6b74a0');
  });

  // ---- CTA ----
  const cy2 = sy + sh + 26, ch = 118;
  s += `<rect x="40" y="${cy2}" width="${R - 40}" height="${ch}" rx="28" fill="#ffffff"/>`;
  s += `<rect x="64" y="${cy2 + 22}" width="${R - 88}" height="${ch - 44}" rx="20" fill="url(#cta)"/>`;
  s += ctr(W / 2 + 22, cy2 + ch / 2 + 10, 'شروع تست ۳۰ ثانیه‌ای', 25, 700, p.ctaInk);
  // brain glyph
  s += `<circle cx="${W / 2 - 128}" cy="${cy2 + ch / 2 - 2}" r="15" fill="${p.ctaInk}" fill-opacity="0.9"/>
        <circle cx="${W / 2 - 150}" cy="${cy2 + ch / 2 - 2}" r="12" fill="${p.ctaInk}" fill-opacity="0.55"/>`;

  // ---- gallery card ----
  const gy = cy2 + ch + 26;
  s += `<rect x="40" y="${gy}" width="${R - 40}" height="${navTop - gy - 26}" rx="28" fill="#ffffff"/>`;
  s += rtl(R - 24, gy + 54, 'گالری عکس', 25, 700, '#16204a');
  s += `<rect x="72" y="${gy + 82}" width="${R - 104}" height="${navTop - gy - 138}" rx="20"
          fill="none" stroke="#c9d2ea" stroke-width="3" stroke-dasharray="12 10"/>`;
  s += ctr(W / 2, gy + 82 + (navTop - gy - 138) / 2 + 9, '+ آپلود عکس', 22, 400, '#8b95bd');

  // ---- bottom nav (wave + notch) ----
  const fabR = 46, fabCx = W / 2, fabCy = navTop + 4;
  const notchR = fabR + 12;
  s += `<path d="M0 ${navTop}
      H${fabCx - notchR - 26}
      Q${fabCx - notchR - 4} ${navTop} ${fabCx - notchR + 2} ${navTop + 16}
      A ${notchR} ${notchR} 0 0 0 ${fabCx + notchR - 2} ${navTop + 16}
      Q${fabCx + notchR + 4} ${navTop} ${fabCx + notchR + 26} ${navTop}
      H${W} V${H} H0 Z" fill="url(#nav)"/>`;

  const labels = [
    { k: 'profile', tx: 'پروفایل من' },
    { k: 'chat',    tx: 'گفتگوها' },
    { k: 'map',     tx: 'نقشه' },
    { k: 'explore', tx: 'کاوش' }
  ];
  const slot = W / 4;
  labels.forEach((L, i) => {
    const cx = slot * i + slot / 2;
    s += navIcon(L.k, cx, navTop + 46, 20);
    s += ctr(cx, navTop + 92, L.tx, 18, 700, '#ffffff');
  });
  // active underline
  s += `<rect x="${slot * 0.5 - 22}" y="${navTop + 104}" width="44" height="5" rx="3" fill="#ffffff"/>`;

  // FAB
  s += `<circle cx="${fabCx}" cy="${fabCy}" r="${fabR + 7}" fill="#eef1fb"/>`;
  s += `<circle cx="${fabCx}" cy="${fabCy}" r="${fabR}" fill="url(#fab)"/>`;
  s += `<path d="M ${fabCx - 17} ${fabCy} h 34 M ${fabCx} ${fabCy - 17} v 34"
          stroke="#ffffff" stroke-width="5.5" stroke-linecap="round"/>`;

  s += `</svg>`;
  return s;
}

ensureFonts().then(() => {
  fs.mkdirSync(OUT, { recursive: true });

  // Probe: render one known word and make sure ink actually lands. A missing
  // font makes resvg emit a blank glyph run instead of throwing.
  const probe = new Resvg(
    `<svg xmlns="http://www.w3.org/2000/svg" width="300" height="80">
       <rect width="300" height="80" fill="#000"/>
       <text x="150" y="52" font-family="Vazirmatn" font-size="34" fill="#fff"
             text-anchor="middle" direction="rtl">هواتو Havato</text></svg>`,
    { font: { fontDirs: [FONTS], defaultFontFamily: 'Vazirmatn', loadSystemFonts: false } }
  ).render();
  const px = probe.asPng();
  probe.free && probe.free();
  // A blank render compresses to almost nothing; real text is far larger.
  if (px.length < 1200) {
    console.error('❌ fonts did not load — the mock-ups would have no text.');
    process.exit(1);
  }

  for (const p of PALETTES) {
    const svg = build(p);
    const png = new Resvg(svg, {
      font: { fontDirs: [FONTS], defaultFontFamily: 'Vazirmatn', loadSystemFonts: false },
      fitTo: { mode: 'width', value: W }
    }).render().asPng();
    const f = path.join(OUT, `${p.file}.png`);
    fs.writeFileSync(f, png);
    console.log('✓', path.basename(f), (png.length / 1024).toFixed(0) + 'K', '—', p.name);
  }
  console.log('\nall five rendered into design/screenshots/');
}).catch(err => { console.error(err); process.exit(1); });
