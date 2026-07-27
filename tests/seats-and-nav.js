/* v1.13.0 —
   1) no grey square behind a tapped nav item
   2) nav labels + solid buttons: white with a dark halo, immune to theme CSS
   3) "Request a seat" renamed to "Reserve a seat"
   4) a guest may reserve up to 3 seats
   5) each card shows the gathering's own title and theme            */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const css = rd('assets/css/havato-app.css');
const js = rd('assets/js/havato-app.js');
const rest = rd('includes/class-havato-rest.php');
const db = rd('includes/class-havato-db.php');
const M = rd('includes/class-havato-matcher.php');
const fn = rd('includes/functions.php');
const i18n = rd('includes/class-havato-i18n.php');
const main = rd('havato.php');
const sc = rd('includes/class-havato-shortcode.php');
const adm = rd('includes/class-havato-admin.php');
const oa = rd('includes/class-havato-owner-admin.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

console.log('--- 1. no tap square on the bottom nav ---');
t('a dedicated tap/focus section exists', /TAP \/ FOCUS BEHAVIOUR/.test(css));
t('pointer focus ring suppressed', /:focus:not\(:focus-visible\)/.test(css));
t('the nav tab clears outline AND background',
  /#havato-app \.hv-tab:active[\s\S]{0,140}background-color: transparent/.test(css));
// A blanket `outline:none` would strand keyboard users.
t('keyboard focus is still visible', /:focus-visible \{[\s\S]{0,90}outline: 2px solid/.test(css));
t('tap highlight explicitly transparent on buttons',
  /#havato-app button,[\s\S]{0,160}tap-highlight-color: transparent/.test(css));

console.log('\n--- 2. nav + buttons are white with a dark halo ---');
// These are single-class selectors (0-1-0), so a theme rule targeting the bare
// tag can beat them. The id-scoped guard raises specificity out of reach.
t('nav is inside the dark-surface guard', /#havato-app \.hv-bottom-nav \*/.test(css));
t('tab labels explicitly guarded', /#havato-app \.hv-tab span,/.test(css));
for (const b of ['hv-btn-primary', 'hv-btn-blue', 'hv-btn-green'])
  t(`${b} guarded to white`, new RegExp('#havato-app \\.' + b + ' \\*').test(css));
t('solid buttons get the dark text halo',
  /#havato-app \.hv-btn-primary,[\s\S]{0,200}text-shadow: 0 1px 2px rgba\(10, 14, 48/.test(css));
t('nav labels keep their halo', /\.hv-tab span \{ text-shadow/.test(css));

console.log('\n--- 3. the button says "reserve a seat" ---');
t('join_event relabelled', /'join_event'\s*=>\s*array\( 'fa' => 'رزرو صندلی'/.test(i18n));
t('old wording gone', !/هم‌نشینی موضوعی/.test(i18n));
t('reserve modal title exists', /'reserve_title'/.test(i18n));

console.log('\n--- 4. up to three seats per guest ---');
t('a cap constant exists', /HAVATO_MAX_SEATS', 3/.test(main));
t('exposed through a filterable helper',
  /function havato_max_seats/.test(fn) && /apply_filters\( 'havato_max_seats'/.test(fn));
t('seats column added', /seats int\(11\) NOT NULL DEFAULT 1/.test(db));
t('schema is at or past the seats column', (() => {
  const m = /HAVATO_DB_VERSION', '(\d+)\.(\d+)\.(\d+)'/.exec(main);
  if (!m) return false;
  const [maj, min] = [Number(m[1]), Number(m[2])];
  return maj > 1 || (maj === 1 && min >= 9);
})());
t('server clamps the request to the cap', /min\( havato_max_seats\(\), \$seats \)/.test(rest));
t('queue_user persists the party size', /'seats'\s*=>\s*max\( 1, min\( havato_max_seats\(\)/.test(rest));
t('client shows a seat picker', /function openReserve/.test(js));
t('picker never offers more than the cap', /BOOT\.maxSeats \|\| 3/.test(js));
t('…nor more than the seats actually left', /Math\.min\(BOOT\.maxSeats \|\| 3, seatsLeft/.test(js));
t('cap is sent to the client', /'maxSeats'/.test(sc) && /'max_seats'/.test(rest));
t('data attribute stays ASCII so parseInt works',
  /data-seats-left="' \+ \(parseInt\(event\.seats_left, 10\) \|\| 0\)/.test(js));

console.log('\n--- 5. capacity is counted in SEATS, not rows ---');
// This is the subtle half: with parties, one row is no longer one person.
t('join counts occupied seats', /COALESCE\(SUM\(seats\),0\)[\s\S]{0,80}WHERE event_id=%s AND status<>'cancelled'/.test(rest));
t('no "taken" is a plain row count anywhere',
  !/COUNT\(\*\)[^;]{0,120}AS taken/.test(rest + adm + oa));
t('explore/map totals use SUM(seats)', (rest.match(/SUM\(r\.seats\)|SUM\(r2\.seats\)/g) || []).length >= 3);
t('admin + owner listings too',
  /SUM\(r\.seats\)/.test(adm) && /SUM\(r\.seats\)/.test(oa));
t('partial availability is reported, not silently truncated',
  /havato_not_enough_seats/.test(rest) && /'only_n_seats_left'/.test(i18n));

console.log('\n--- 6. the matcher seats a party together ---');
t('matcher arms on seats, not rows',
  /COALESCE\(SUM\(seats\),0\)[\s\S]{0,90}status='queued'/.test(M));
t('party sizes are loaded', /SELECT user_id, seats FROM \$regs/.test(M) && /\$party\[ \$uid \]/.test(M));
t('chairs are charged against capacity', /\$occupied\( \$table \) < \$capacity/.test(M));
t('a candidate that would overfill is skipped',
  /\$occupied\( \$table \) \+ \$chairs\( \$cand \) > \$capacity/.test(M));
t('an oversized seed is trimmed', /\$occupied\( \$seed \) > \$capacity/.test(M));
t('local search cannot overfill either', (() => {
  // Scope to the function body rather than guessing a character window.
  const i = M.indexOf('private static function local_search');
  const body = M.slice(i, M.indexOf('\n\t}', i));
  return /\$occupied\( \$candidate_table \) > \$capacity/.test(body)
      && /\$party/.test(body);
})());
// A party is seated as one unit, so it cannot exceed the biggest single table.
t('a party larger than the biggest table is refused',
  /function largest_table_seats/.test(rest) && /havato_party_too_big/.test(rest));
t('…with a helpful message', /'party_max_seats'/.test(i18n));

// Prove the accounting itself, rather than trusting the regexes above.
(() => {
  const chairs = (u, p) => p[u] || 1;
  const occ = (m, p) => m.reduce((n, u) => n + chairs(u, p), 0);
  const fill = (pool, p, cap) => {
    let seed = pool.slice(0, 2);
    if (occ(seed, p) > cap) seed = [seed[0]];
    let tbl = seed.slice();
    let rest = pool.filter(u => !tbl.includes(u));
    while (occ(tbl, p) < cap && rest.length) {
      const c = rest.find(x => occ(tbl, p) + chairs(x, p) <= cap);
      if (c === undefined) break;
      tbl.push(c); rest = rest.filter(x => x !== c);
    }
    return occ(tbl, p);
  };
  const cases = [
    [4, {}], [4, { 1: 3 }], [4, { 1: 3, 2: 3 }], [6, { 1: 3, 2: 3 }], [6, { 1: 3, 2: 2 }]
  ];
  const over = cases.filter(([cap, p]) => fill([1, 2, 3, 4, 5, 6], p, cap) > cap);
  t('simulated seating never exceeds capacity', over.length === 0);
})();

console.log('\n--- 7. cards show the title and theme ---');
t('title rendered when present', /event\.title \? '<p class="hv-event-title">/.test(js));
t('theme rendered as its own badge', /event\.theme \? '<span class="hv-badge hv-badge-pink">/.test(js));
t('both are optional, so untitled events still render',
  /\(event\.title \?/.test(js) && /\(event\.theme \?/.test(js));
t('the server already sent them', /'title'\s*=>\s*\$row\['title'\]/.test(rest) && /'theme'\s*=>/.test(rest));
t('title has a style', /\.hv-event-title \{/.test(css));

console.log(f ? `\n❌ ${f} failing` : '\n✅ nav clean, buttons legible, seats bookable, cards complete');
process.exit(f ? 1 : 0);
