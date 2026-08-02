/**
 * Before/after of the English bottom bar and body type.
 *
 * Everything is read out of the real source: the tab list from the JS, the
 * labels from the string map, the sizes from the CSS token and the component
 * rules. The "before" column re-derives what the OLD stylesheet produced —
 * `#havato-app button { font: inherit }` beat `.hv-tab`, so the labels
 * rendered at body size, and the host theme uppercased them.
 */
const { Resvg } = require('@resvg/resvg-js');
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', 'design', 'screenshots');
const FONTS = path.join(__dirname, 'fonts');
const SRC = path.join(__dirname, '..', 'havato');
const I18N = fs.readFileSync(path.join(SRC, 'includes', 'class-havato-i18n.php'), 'utf8');
const JS = fs.readFileSync(path.join(SRC, 'assets', 'js', 'havato-app.js'), 'utf8');
const CSS = fs.readFileSync(path.join(SRC, 'assets', 'css', 'havato-app.css'), 'utf8')
  .replace(/\/\*[\s\S]*?\*\//g, '');

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
      .then((t) => fs.writeFileSync(dst, Buffer.from(t)));
  }), Promise.resolve());
}

/* ---- read the truth out of the source ---- */
function en(key) {
  const re = new RegExp("'" + key + "'\\s*=>\\s*array\\([^)]*?'en'\\s*=>\\s*'((?:[^'\\\\]|\\\\.)*)'");
  const m = re.exec(I18N);
  if (!m) { throw new Error('missing i18n key: ' + key); }
  return m[1].replace(/\\'/g, "'");
}

const tabBlock = JS.slice(JS.indexOf('function tabsFor'), JS.indexOf('function buildTabs'));
const TABS = [...tabBlock.matchAll(/id: '(\w+)', label: '(\w+)'/g)].map((m) => ({
  id: m[1], key: m[2], label: en(m[2])
}));
if (TABS.length !== 5) { throw new Error('expected 5 tabs, read ' + TABS.length); }

// The old bar used the possessive keys; keep them for the "before" column.
const OLD_LABELS = ['Home', 'Explore', en('tab_my_tables'), 'Chats', en('tab_profile')];

// Sizes, read from the stylesheet.
const tokEn = +(/hv-dir-ltr\s*\{[\s\S]*?--hv-fs:\s*([\d.]+)px/.exec(CSS) || [])[1];
const tabIcon = +(/\.hv-tab svg \{[^}]*inline-size:\s*(\d+)px/s.exec(CSS) || [])[1];
const tabMult = +(/\n\.hv-tab\s*\{[^}]*font-size:\s*calc\(([\d.]+)/s.exec(CSS) || [])[1];
const btnMult = +(/\n\.hv-btn\s*\{[^}]*font-size:\s*calc\(([\d.]+)/s.exec(CSS) || [])[1];
if (!tokEn || !tabMult || !btnMult) { throw new Error('could not read sizes from CSS'); }

const NEW_TAB = tokEn * tabMult;
const NEW_BTN = tokEn * btnMult;
// Before: the shorthand forced body size onto every button.
const OLD_BODY = 16;
const OLD_TAB = OLD_BODY;
const OLD_BTN = OLD_BODY;

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const ctr = (x, y, s, sz, w, fill, extra) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" ` +
  `fill="${fill}" text-anchor="middle"${extra || ''}>${esc(s)}</text>`;
const ltr = (x, y, s, sz, w, fill) =>
  `<text x="${x}" y="${y}" font-family="Vazirmatn" font-size="${sz}" font-weight="${w}" fill="${fill}">${esc(s)}</text>`;

/* ---- draw ---- */
const COL = 430;      // one phone column
const GAP = 40;
const W = COL * 2 + GAP * 3;
const H = 760;
const PH = 375;       // simulated device width

let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">`;
s += `<defs>
  <linearGradient id="nav" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#232AD1"/><stop offset="0.55" stop-color="#1B1FBF"/>
    <stop offset="1" stop-color="#141A6E"/>
  </linearGradient>
  <linearGradient id="btn" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#2B2FE0"/><stop offset="1" stop-color="#1B1FBF"/>
  </linearGradient>
</defs>`;
s += `<rect width="${W}" height="${H}" fill="#eef1fb"/>`;

s += ctr(W / 2, 46, 'English build — bottom bar and buttons at 375px', 21, 800, '#16204a');

function panel(x, title, tint, labels, tabFs, btnFs, caps, note, iconPx) {
  let g = '';
  const top = 82;
  const ph = H - top - 40;

  g += `<rect x="${x}" y="${top}" width="${COL}" height="${ph}" rx="26" fill="#ffffff" stroke="${tint}" stroke-width="2"/>`;
  g += ctr(x + COL / 2, top + 34, title, 17, 800, tint);

  // scale the simulated 375px phone into the panel
  const S = (COL - 48) / PH;
  const px = x + 24;
  let py = top + 58;

  const say = (v) => (caps ? String(v).toUpperCase() : String(v));

  // ---- a card with a primary button, to show button type ----
  g += `<rect x="${px}" y="${py}" width="${PH * S}" height="${96 * S}" rx="${18 * S}" fill="#f7f8fd" stroke="#e3e7f5"/>`;
  g += ltr(px + 14 * S, py + 26 * S, 'Your next table', 13, 800, '#16204a');
  g += ltr(px + 14 * S, py + 46 * S, 'No seats booked yet.', 11.5, 400, '#6b74a0');
  {
    const bw = 150 * S, bh = 34 * S;
    const bx = px + (PH * S - bw) / 2, by = py + 56 * S;
    g += `<rect x="${bx}" y="${by}" width="${bw}" height="${bh}" rx="${12 * S}" fill="url(#btn)"/>`;
    g += ctr(bx + bw / 2, by + bh / 2 + btnFs * S * 0.36, say(en('tab_explore')), btnFs * S, 700, '#ffffff');
  }
  py += 116 * S;

  // ---- a tile with a Reserve button, the widest label in the app ----
  g += `<rect x="${px}" y="${py}" width="${PH * S}" height="${64 * S}" rx="${18 * S}" fill="#f7f8fd" stroke="#e3e7f5"/>`;
  {
    const bw = 200 * S, bh = 34 * S;
    const bx = px + 14 * S, by = py + 15 * S;
    g += `<rect x="${bx}" y="${by}" width="${bw}" height="${bh}" rx="${12 * S}" fill="url(#btn)"/>`;
    const label = say(en('join_event'));
    // Show the overflow honestly: clip to the button.
    const cid = 'clip' + Math.round(x) + Math.round(py);
    g += `<clipPath id="${cid}"><rect x="${bx}" y="${by}" width="${bw}" height="${bh}" rx="${12 * S}"/></clipPath>`;
    g += `<g clip-path="url(#${cid})">` +
      ctr(bx + bw / 2, by + bh / 2 + btnFs * S * 0.36, label, btnFs * S, 700, '#ffffff') + `</g>`;
    const need = label.length * btnFs * S * 0.5;
    if (need > bw - 8) {
      g += ctr(bx + bw / 2, by + bh + 15, `needs ${Math.round(need)}px in a ${Math.round(bw)}px button`, 11, 700, '#b91c1c');
    }
  }
  py += 96 * S;

  // ---- the five-tab bar ----
  const navH = 62 * S;
  const navY = top + ph - navH - 76;
  g += `<rect x="${px}" y="${navY}" width="${PH * S}" height="${navH}" rx="${14 * S}" fill="url(#nav)"/>`;

  const colW = (PH * S) / 5;
  labels.forEach((lab, i) => {
    const cx = px + colW * (i + 0.5);
    // icon
    const ic = iconPx * S;
    g += `<rect x="${cx - ic / 2}" y="${navY + 9 * S}" width="${ic}" height="${ic}" rx="${ic * 0.28}" ` +
      `fill="none" stroke="#ffffff" stroke-width="${1.9 * S}" stroke-opacity="0.95"/>`;

    const text = say(lab);
    const need = text.length * tabFs * S * 0.5;
    const room = colW - 4;
    // Clip each label to its own column, exactly as the real bar does.
    const cid = 'tc' + Math.round(x) + i;
    g += `<clipPath id="${cid}"><rect x="${cx - room / 2}" y="${navY}" width="${room}" height="${navH}"/></clipPath>`;
    const shown = need > room
      ? text.slice(0, Math.max(1, Math.floor(room / (tabFs * S * 0.5)) - 1)) + '…'
      : text;
    g += `<g clip-path="url(#${cid})">` +
      ctr(cx, navY + 9 * S + ic + 13 * S, shown, tabFs * S, need > room ? 700 : 600, '#ffffff') + `</g>`;

    if (need > room) {
      g += `<rect x="${cx - room / 2}" y="${navY}" width="${room}" height="${navH}" fill="#ff3b30" fill-opacity="0.16"/>`;
    }
  });

  const overflow = labels.filter((l) => say(l).length * tabFs * S * 0.5 > colW - 4).length;
  g += ctr(x + COL / 2, navY + navH + 30,
    overflow ? `${overflow} of 5 labels truncated` : 'all 5 labels fit',
    14, 800, overflow ? '#b91c1c' : '#067a55');
  g += ctr(x + COL / 2, navY + navH + 52, note, 12, 600, '#6b74a0');

  return g;
}

s += panel(GAP, 'BEFORE (v1.34)', '#b91c1c', OLD_LABELS, OLD_TAB, OLD_BTN, true,
  `label ${OLD_TAB}px inherited · icon 20px (1.25em) · uppercased by theme`, 20);
s += panel(GAP * 2 + COL, 'AFTER (v1.35.1)', '#067a55', TABS.map((t) => t.label), NEW_TAB, NEW_BTN, false,
  `label ${NEW_TAB.toFixed(1)}px · icon ${tabIcon}px · case as authored`, tabIcon);

s += '</svg>';

/* ---- render ---- */
ensureFonts().then(() => {
  const probe = new Resvg(
    `<svg xmlns="http://www.w3.org/2000/svg" width="200" height="60"><text x="10" y="40" font-family="Vazirmatn" font-size="30">Havato</text></svg>`,
    { font: { fontDirs: [FONTS], defaultFontFamily: 'Vazirmatn', loadSystemFonts: false } }
  ).render().asPng();
  if (probe.length < 900) { throw new Error('font did not load — glyphs would be blank'); }

  fs.mkdirSync(OUT, { recursive: true });
  const png = new Resvg(s, {
    font: { fontDirs: [FONTS], defaultFontFamily: 'Vazirmatn', loadSystemFonts: false },
    fitTo: { mode: 'width', value: W }
  }).render().asPng();
  const dst = path.join(OUT, 'latin-nav-before-after.png');
  fs.writeFileSync(dst, png);
  console.log('wrote ' + dst + '  (' + png.length + ' bytes)');
  console.log(`tab label: ${OLD_TAB}px -> ${NEW_TAB.toFixed(2)}px`);
  console.log(`tab icon : 20px (1.25em, accidental) -> ${tabIcon}px (fixed)`);
  console.log(`btn label: ${OLD_BTN}px -> ${NEW_BTN.toFixed(2)}px`);
}).catch((e) => { console.error(e); process.exit(1); });
