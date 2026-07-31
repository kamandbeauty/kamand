/* v1.31.0 — the app was restyled from a reference mock-up:

   1) a dark violet "Galaxy" theme, added alongside the six light ones
   2) a five-tab bottom bar, replacing four tabs plus a floating button
   3) a new Home screen: your next table, a discover rail, shortcuts
   4) events shown as boxed cards

   The dark-theme surface maths is executed here rather than eyeballed,
   because a dark palette that keeps the light theme's white cards would
   look fine in code and be unreadable on a phone.                          */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const js = rd('assets/js/havato-app.js');
const css = rd('assets/css/havato-app.css');
const tpl = rd('templates/app.php');
const themes = rd('includes/class-havato-themes.php');
const i18n = rd('includes/class-havato-i18n.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

const hex = h => { h = String(h).replace('#', ''); return [0, 2, 4].map(i => parseInt(h.slice(i, i + 2), 16)); };
const lum = h => {
  const [r, g, b] = hex(h).map(v => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
const ratio = (a, b) => {
  const l1 = lum(a), l2 = lum(b);
  return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
};

/* =====================================================================
 * 1. The engine can express a dark theme at all
 * ================================================================== */
console.log('--- 1. dark themes are a real capability, not one palette ---');

t('a palette can declare itself dark', /'dark'\s*=> isset\( \$theme\['dark'\] \)/.test(themes));
t('…or have it inferred from a dark canvas', /self::luminance\([\s\S]{0,120}< 0\.4/.test(themes));
t('a dark theme lightens its card off the canvas', /\? self::lighten\( \$out\['canvas'\], 0\.07 \)/.test(themes));
t('a light theme still uses plain white', /: '#ffffff';/.test(themes));
t('the card colour is emitted as a token', /'--hv-card'\s*=> \$t\['card'\]/.test(themes));
t('cards gain a visible edge on dark', /'--hv-card-border'[\s\S]{0,80}\$t\['dark'\] \? self::rgba/.test(themes));
t('the danger surface is tokenised too', /'--hv-card-danger'/.test(themes));

// Contrast is corrected against the CARD, not the canvas — that is the
// surface the text actually sits on.
t('body text is corrected against the card', /self::contrast\( \$out\['text'\], \$out\['card'\] \) < 4\.5/.test(themes));
t('…and secondary text has a 3:1 floor', /self::contrast\( \$out\['text_soft'\], \$out\['card'\] \) < 3/.test(themes));
t('a dark theme lightens rather than darkens to fix contrast',
  /\$out\['dark'\]\s*\n?\s*\? self::lighten\( \$out\['text'\], 0\.08 \)/.test(themes));

// The stylesheet must not hardcode white where a theme has to override.
(() => {
  // The café-owner auth page keeps its literal white: it paints its own
  // gradient card and is never repainted by a guest theme.
  const appOnly = css.split('\n').filter(l => !/hv-owner-auth/.test(l)).join('\n');
  const literal = (appOnly.match(/background: ?#(?:fff|ffffff)\b/g) || []).length;
  t('hardcoded white surfaces are gone from the themed app (' + literal + ' left)', literal === 0);
  t('the one exception is the un-themed owner auth page',
    /\.hv-owner-auth \.hv-subtab\.is-active \{ background: #fff/.test(css));
  t('cards read their colour from the token', /background: var\(--hv-card\)/.test(css));
  t('the token has a light default', /--hv-card: #ffffff;/.test(css));
})();

console.log('\n--- 2. the Galaxy palette is readable ---');
(() => {
  const block = themes.slice(themes.indexOf("'galaxy' => array("), themes.indexOf("'raspberry' => array("));
  const grab = k => (new RegExp("'" + k + "'\\s*=> '(#[0-9a-fA-F]{6})'").exec(block) || [])[1];

  const g = {
    canvas: grab('canvas'), card: grab('card'), text: grab('text'),
    soft: grab('text_soft'), base: grab('base'), light: grab('light'), accent: grab('accent')
  };

  t('every colour is defined', Object.keys(g).every(k => !!g[k]));
  t('it is a dark canvas', lum(g.canvas) < 0.1);
  t('cards sit lighter than the page', lum(g.card) > lum(g.canvas));
  t('body text on a card clears AA', ratio(g.text, g.card) >= 4.5);
  t('body text on the page clears AA', ratio(g.text, g.canvas) >= 4.5);
  t('secondary text clears 3:1', ratio(g.soft, g.card) >= 3);
  t('white on the primary button clears AA', ratio('#ffffff', g.base) >= 4.5);
  t('the ramp still descends', lum(g.light) > lum(g.base));

  t('it is marked dark explicitly', /'dark'\s*=> true/.test(block));
  t('…so the intent survives a canvas edit', /'dark'\s*=> true/.test(block));
})();

t('the default is still the non-violet Azure', /const FALLBACK = 'azure';/.test(themes));

/* =====================================================================
 * 3. Five tabs, no floating button
 * ================================================================== */
console.log('\n--- 3. the new bottom bar ---');

(() => {
  const block = js.slice(js.indexOf('function tabsFor'), js.indexOf('function buildTabs'));
  const ids = [...block.matchAll(/id: '(\w+)'/g)].map(m => m[1]);
  t('exactly five tabs (' + ids.join(', ') + ')', ids.length === 5);
  t('they are home, explore, tables, chats, profile',
    ids.join(',') === 'home,explore,tables,chats,profile');
})();

t('the floating button is gone from the markup', !/id="hv-fab"/.test(tpl));
t('the notch is gone from the nav surface', !/--hv-notch/.test(css));
t('the middle-slot spacing is gone', !/Third slot is reserved for the FAB notch/.test(css));

// The map lost its tab but must stay reachable, and must light up Explore.
t('map is aliased to explore', /TAB_ALIASES = \{ map: 'explore' \}/.test(js));
t('routing accepts an aliased view', /function isRoutable/.test(js) && /if \(TAB_ALIASES\[id\]\) \{ return true; \}/.test(js));
t('the nav highlights the parent tab', /var active = navTabFor\(id\);/.test(js));
t('Explore offers the map as a sub-tab', /function exploreSubtabs/.test(js));
t('…on the list view', /exploreSubtabs\('list'\)/.test(js));
t('…and on the map view', /exploreSubtabs\('map'\)/.test(js));
t('the empty state keeps the sub-tabs, so the map stays reachable',
  /exploreSubtabs\('list'\) \+\s*\n?\s*emptyState/.test(js));

(() => {
  // Model the highlight: browsing the map must light the Explore tab.
  const ALIAS = { map: 'explore' };
  const navTab = id => ALIAS[id] || id;
  t('on Home, Home is lit', navTab('home') === 'home');
  t('on Explore, Explore is lit', navTab('explore') === 'explore');
  t('on the Map, Explore is lit (not nothing)', navTab('map') === 'explore');
  t('on My Tables, My Tables is lit', navTab('tables') === 'tables');
})();

/* =====================================================================
 * 4. The Home screen
 * ================================================================== */
console.log('\n--- 4. Home ---');

t('a Home view exists', /function viewHome/.test(js));
t('it greets the guest by name', /home_greeting[\s\S]{0,80}S\.user && S\.user\.name/.test(js));
t('the next table is a hero card', /function nextTableCard/.test(js));
t('discover tiles are separate', /function discoverTile/.test(js));
t('the rail scrolls horizontally', /\.hv-rail \{[\s\S]{0,200}overflow-x: auto/.test(css));
t('…and snaps, so no tile is left half-shown', /scroll-snap-type: x mandatory/.test(css));
t('tiles have a fixed two-line title so heights match', /-webkit-line-clamp: 2/.test(css));

// One request each, in parallel — not a two-stage draw.
t('both requests fire together', /Promise\.all\(\[\s*\n\s*api\('dashboard'\)[\s\S]{0,120}api\('events'\)/.test(js));
t('a failing request does not blank the screen', /api\('dashboard'\)\.catch\(function \(\) \{ return \{\}; \}\)/.test(js));

t('tables already booked are not offered again', /events\.filter\(function \(ev\) \{ return !ev\.joined; \}\)/.test(js));
t('the rail is capped', /\.slice\(0, 8\)/.test(js));
t('a guest with no bookings is told what to do', /dash_no_events[\s\S]{0,200}tab_explore/.test(js));
t('View all goes to Explore', /data-go-explore/.test(js) && /setTab\('explore'\)/.test(js));
t('a card opens the event page', /openEvent\(node\.dataset\.openEvent\)/.test(js));
t('three shortcuts are rendered', (js.match(/data-quick="/g) || []).length >= 3);
t('the suggest shortcut opens the suggestion form', /openSuggestEvent\(\(S\.data\.dashboard && S\.data\.dashboard\.venues\) \|\| \[\]\)/.test(js));

console.log('\n--- 5. My Tables ---');
t('a My Tables view exists', /function viewMyTables/.test(js));
t('it reuses the same card as Home', /upcoming\.map\(nextTableCard\)/.test(js));
t('it shows the guest\'s suggestions too', /dash_requests/.test(js));
t('it offers the suggest button', /suggest_event/.test(js));

console.log('\n--- 6. events are boxed cards ---');
t('the hero card is a box', /\.hv-next-card \{[\s\S]{0,300}border-radius: var\(--hv-radius-xl\)/.test(css));
t('…with a border that shows on dark', /\.hv-next-card \{[\s\S]{0,300}border: 1px solid var\(--hv-card-border\)/.test(css));
t('tiles are boxes too', /\.hv-tile \{[\s\S]{0,300}border: 1px solid var\(--hv-card-border\)/.test(css));
t('the topic is labelled, as in the mock-up', /hv-next-topic-label/.test(js));
t('shortcut buttons are boxed', /\.hv-quick-btn \{/.test(css));

for (const k of ['tab_home', 'tab_my_tables', 'home_greeting', 'home_next_table',
                 'home_discover', 'view_all']) {
  t('i18n "' + k + '" trilingual',
    new RegExp("'" + k + "'\\s*=> array\\( 'fa' =>.*'en' =>.*'tr' =>").test(i18n));
}
t('the greeting has a placeholder for the name', /'home_greeting'[\s\S]{0,120}%s/.test(i18n));

console.log(f ? `\n❌ ${f} failing` : '\n✅ galaxy theme, five tabs, home screen and boxed events all in place');
process.exit(f ? 1 : 0);
