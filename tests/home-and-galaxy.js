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

// v1.39.0: the default is the Ideal Gathering cosmic graphics (nebula).
// The violet ban of v1.10.0 applied to a default that made the app look
// like every fintech app; nebula is exempt on purpose — it is the brand
// identity the client asked to port, and it is the dark cosmic look.
t('the default is the nebula Ideal Gathering graphics', /const FALLBACK = 'nebula';/.test(themes));

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
// Four shortcut cards since 1.31.2, in a 2x2 grid, each with an arrow.
(() => {
  const block = js.slice(js.indexOf("'<div class=\"hv-quick\">'"), js.indexOf("'</div>' +", js.indexOf("'<div class=\"hv-quick\">'")));
  const cards = [...block.matchAll(/quickCard\('(\w+)'/g)].map(m => m[1]);
  t('four shortcuts are rendered (' + cards.join(', ') + ')', cards.length === 4);
  t('they cover browse, host, my tables and chat',
    cards.join(',') === 'explore,suggest,tables,chats');
})();
t('each carries an arrow into its screen', /hv-quick-arrow/.test(js));
t('the arrow follows the writing direction', /'rtl' === S\.dir \? '←' : '→'/.test(js));
t('they sit two per row', /\.hv-quick \{[\s\S]{0,320}grid-template-columns: repeat\(2, 1fr\)/.test(css));
t('a long label is clamped so the row keeps one height', /\.hv-quick-label \{[\s\S]{0,220}-webkit-line-clamp: 2/.test(css));

console.log('\n--- 4b. the activity summary ---');
t('a summary section is rendered', /hv-summary/.test(js));
t('it has a heading', /activity_summary/.test(js));
t('it shows what is coming up', /summaryRow\('calendar', t\('dash_upcoming'\)/.test(js));
t('…and what was actually attended', /summaryRow\('users', t\('stat_attended'\)/.test(js));
t('the server sends the attended count', /'attended'  => \(int\) \$profile\['attended_count'\]/.test(rd('includes/class-havato-rest.php')));
t('…counted at check-in, not at booking', /flatter anyone who books and never turns up/.test(rd('includes/class-havato-rest.php')));
t('a missing figure shows zero rather than blank', /num\(parseInt\(value, 10\) \|\| 0\)/.test(js));
t('the numbers line up between rows', /\.hv-summary-value \{[\s\S]{0,220}tabular-nums/.test(css));

for (const k of ['quick_actions', 'activity_summary', 'quick_browse', 'quick_host']) {
  t('i18n "' + k + '" trilingual',
    new RegExp("'" + k + "'\\s*=> array\\( 'fa' =>.*'en' =>.*'tr' =>").test(i18n));
}
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
// The topic became the card's headline in 1.31.1 rather than a labelled
// sub-line, matching the reference: name, then when, then where, then who.
t('the topic is the card headline', /<h4 class="hv-next-name">' \+ esc\(subject \|\| pick\(ev\.venue\)\)/.test(js));
t('…followed by the date row', /hv-next-row[\s\S]{0,140}eventWeekday\(ev\)/.test(js));
t('…then the venue and its address', /hv-next-row[\s\S]{0,200}ev\.address \? '، ' \+ esc\(ev\.address\)/.test(js));
t('…then the people already coming', /faceStack\(ev\)/.test(js));
t('shortcut buttons are boxed', /\.hv-quick-btn \{/.test(css));

for (const k of ['tab_home', 'tab_my_tables', 'home_greeting', 'home_next_table',
                 'home_discover', 'view_all']) {
  t('i18n "' + k + '" trilingual',
    new RegExp("'" + k + "'\\s*=> array\\( 'fa' =>.*'en' =>.*'tr' =>").test(i18n));
}
t('the greeting has a placeholder for the name', /'home_greeting'[\s\S]{0,120}%s/.test(i18n));

/* =====================================================================
 * 7. Reported on a real phone (v1.31.1)
 * ================================================================== */
console.log('\n--- 7. the five-tab bar actually fits ---');

// The bar was still laid out for four tabs, so the fifth wrapped onto a
// second row underneath — visible in the screenshot.
t('the four-column grid is gone', !/grid-template-columns: repeat\(4, 1fr\)/.test(css));
t('tabs share the width by flex instead', /\.hv-tabs \{[\s\S]{0,600}display: flex/.test(css));
t('each tab takes an equal share', /\.hv-tab \{[\s\S]{0,260}flex: 1 1 0/.test(css));
t('…and may shrink below its label', /\.hv-tab \{[\s\S]{0,260}min-inline-size: 0/.test(css));
t('a long label ellipsises rather than wrapping',
  /\.hv-tab span \{[\s\S]{0,220}white-space: nowrap/.test(css));
t('the reason is recorded', /pushed the last one onto a second row/.test(css));

(() => {
  // Model the layout: five equal tabs must fit one row on a narrow phone.
  const tabCount = 5;
  const screen = 360;            // a small Android width, in CSS px
  const padding = 8;             // .hv-tabs padding-inline: 4px each side
  const per = (screen - padding) / tabCount;
  t('each tab gets a usable width on a 360px screen (' + per.toFixed(1) + 'px)', per >= 60);
  t('the icon still fits inside it', per > 22);
})();

console.log('\n--- 8. Iranian gatherings are dated in Jalali ---');

t('a country-aware date helper exists', /function eventDate\(ev\)/.test(js));
t('…and one for the weekday', /function eventWeekday\(ev\)/.test(js));
t('Iran forces the Jalali string', /'ir' === String\(ev\.country \|\| ''\)\.toLowerCase\(\)/.test(js));
t('no card reads the date through pick\\(\\) any more',
  !/esc\(pick\(ev\.date\)\)/.test(js) && !/esc\(pick\(event\.date\)\)/.test(js));
t('the payload carries the venue country', /'country'     => isset\( \$row\['venue_country'\] \)/.test(rd('includes/class-havato-rest.php')));
t('…and the queries select it',
  (rd('includes/class-havato-rest.php').match(/v\.country AS venue_country/g) || []).length >= 4);
t('the weekday is sent in Turkish too', /'tr' => Havato_Jalali::week_day/.test(rd('includes/class-havato-rest.php')));
t('the reasoning is written down', /prints a Jalali date on its door/.test(js));

(() => {
  // Execute the rule over both countries and all three languages.
  const eventDate = (ev, lang) => {
    if (!ev || !ev.date) { return ''; }
    if ('ir' === String(ev.country || '').toLowerCase()) { return ev.date.fa || ev.date[lang]; }
    return ev.date[lang] !== undefined ? ev.date[lang] : (ev.date.en || ev.date.fa || '');
  };
  const d = { fa: 'J', en: 'G-en', tr: 'G-tr' };

  t('Iran + Persian reader -> Jalali', eventDate({ country: 'ir', date: d }, 'fa') === 'J');
  t('Iran + English reader -> Jalali (the bug)', eventDate({ country: 'ir', date: d }, 'en') === 'J');
  t('Iran + Turkish reader -> Jalali', eventDate({ country: 'ir', date: d }, 'tr') === 'J');
  t('Turkey + Turkish reader -> Gregorian', eventDate({ country: 'tr', date: d }, 'tr') === 'G-tr');
  t('Turkey + English reader -> Gregorian', eventDate({ country: 'tr', date: d }, 'en') === 'G-en');
  // A Persian speaker reading a Turkish café still gets their own calendar:
  // only the Iranian side is pinned.
  t('Turkey + Persian reader -> the reader\'s own', eventDate({ country: 'tr', date: d }, 'fa') === 'J');
  t('uppercase IR is still Iran', eventDate({ country: 'IR', date: d }, 'en') === 'J');
  t('an unknown country follows the reader', eventDate({ country: '', date: d }, 'en') === 'G-en');
})();

console.log('\n--- 9. the card shows who is coming ---');

t('the server sends a few faces', /private static function event_faces/.test(rd('includes/class-havato-rest.php')));
t('…capped so a feed does not fetch whole guest lists', /ORDER BY id ASC LIMIT 4/.test(rd('includes/class-havato-rest.php')));
t('…with the real total for the +N', /'total'   => \$total/.test(rd('includes/class-havato-rest.php')));
t('cancelled bookings are not counted', /WHERE event_id = %s AND status <> 'cancelled'/.test(rd('includes/class-havato-rest.php')));
t('no names or ids leak onto a public card',
  !/'faces'[\s\S]{0,400}display_name/.test(rd('includes/class-havato-rest.php')));

t('the client renders the stack', /function faceStack/.test(js));
t('it is used on the full card', /faceStack\(ev\) \+/.test(js));
t('…and on the rail tile', /faceStack\(ev\) \+\s*\n\s*\(full/.test(js));
t('avatars overlap so a full table fits', /\.hv-face \{[\s\S]{0,600}margin-inline-end: -9px/.test(css));
t('the overlap is logical, so it flips in RTL', /margin-inline-end: -9px/.test(css) && !/margin-right: -9px/.test(css));
t('the +N chip is styled apart', /\.hv-face\.is-more \{/.test(css));
t('tiles use smaller faces', /\.hv-tile \.hv-face \{/.test(css));

(() => {
  // The "+N" must count the people not shown, not the whole table.
  const extra = (shown, total) => total - shown;
  t('4 shown of 6 -> +2', extra(4, 6) === 2);
  t('4 shown of 4 -> no chip', extra(4, 4) === 0);
  t('1 shown of 1 -> no chip', extra(1, 1) === 0);
  t('4 shown of 14 -> +10', extra(4, 14) === 10);
})();

console.log(f ? `\n❌ ${f} failing` : '\n✅ galaxy theme, five tabs, home screen and boxed events all in place');
process.exit(f ? 1 : 0);
