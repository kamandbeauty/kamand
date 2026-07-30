/* v1.29.0 — three fixes from a phone screenshot:

   1) the language dropdown rendered white text on a white panel
   2) the language and action buttons sat side by side, squeezing the title
   3) gatherings that had started — or were within five hours — were still
      listed and bookable

   The cascade that caused (1) and the cutoff arithmetic behind (3) are both
   modelled and executed here, not just matched against source text.        */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const css = rd('assets/css/havato-app.css');
const tpl = rd('templates/app.php');
const rest = rd('includes/class-havato-rest.php');
const fn = rd('includes/functions.php');
const i18n = rd('includes/class-havato-i18n.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

/* =====================================================================
 * 1. The dropdown is readable
 * ================================================================== */
console.log('--- 1. white-on-white in the language menu ---');

(() => {
  // The dark-surface guard forces #fff on every descendant of .hv-header
  // that is not explicitly excluded. It is id-scoped, so it outranks a
  // plain class rule — which is exactly why the menu went invisible.
  const guardSelector = /#havato-app \.hv-header :not\(([^{]+)\)/.exec(css);
  t('the guard still exists', !!guardSelector);

  const exclusions = (guardSelector ? guardSelector[0] : '');
  t('the language menu is excluded from it', /:not\(\.hv-lang-menu\)/.test(exclusions));
  t('…and so are its children', /:not\(\.hv-lang-menu \*\)/.test(exclusions));

  // Model the specificity contest that produced the bug.
  const specificity = sel => ({
    id: (sel.match(/#/g) || []).length,
    cls: (sel.match(/\./g) || []).length
  });
  const guard = specificity('#havato-app .hv-header :not(...)');
  const plain = specificity('.hv-lang-option');
  const pinned = specificity('#havato-app .hv-lang-option');

  t('a plain class rule loses to the guard (the original bug)',
    guard.id > plain.id);
  t('…so the colour is pinned at the same weight instead',
    pinned.id === guard.id && /#havato-app \.hv-lang-option,/.test(css));
})();

t('the panel background is pinned too', /#havato-app \.hv-lang-menu \{ background: #fff; \}/.test(css));
t('option text is dark, not inherited', /#havato-app \.hv-lang-option,[\s\S]{0,120}color: var\(--hv-text/.test(css));
t('the active row keeps its own colour', /#havato-app \.hv-lang-option\.is-active,[\s\S]{0,200}color: var\(--hv-indigo\)/.test(css));
t('the reason is written down for the next person', /white on white/.test(css));

/* =====================================================================
 * 2. The two header buttons are stacked
 * ================================================================== */
console.log('\n--- 2. the action button sits under the language button ---');

t('a tools column wraps them', /class="hv-header-tools"/.test(tpl));
t('it stacks vertically', /\.hv-header-tools \{[\s\S]{0,200}flex-direction: column/.test(css));

(() => {
  // Order matters: language on top, action beneath.
  const block = tpl.slice(tpl.indexOf('hv-header-tools'), tpl.indexOf('</div>', tpl.indexOf('hv-header-action')));
  t('language comes first', block.indexOf('hv-lang-wrap') < block.indexOf('hv-header-action'));
  t('the action is second', block.indexOf('hv-header-action') > -1);
})();

t('the header aligns to the top so the stack does not push the title down',
  /\.hv-header-inner \{[\s\S]{0,240}align-items: flex-start/.test(css));
t('the avatar and title stay optically level', /\.hv-header-titles \{ margin-block-start: 2px; \}/.test(css));
t('the dropdown still anchors to its own button', /\.hv-lang-wrap \{ position: relative/.test(css));

/* =====================================================================
 * 3. Started and near-start gatherings are gone
 * ================================================================== */
console.log('\n--- 3. the five-hour booking cutoff ---');

t('a cutoff helper exists', /function havato_booking_cutoff_hours/.test(fn));
t('it defaults to five hours', /apply_filters\( 'havato_booking_cutoff_hours', 5 \)/.test(fn));
t('…and is filterable', /apply_filters\( 'havato_booking_cutoff_hours'/.test(fn));
t('it cannot go negative', /return max\( 0, \$hours \);/.test(fn));
t('the cutoff is a datetime, not just a date', /function havato_booking_cutoff\(\)/.test(fn));
t('it is built from the site clock', /strtotime\( havato_now\(\) \)/.test(fn));

t('Explore compares date AND time', /CONCAT\(e\.event_date, ' ', e\.event_time\) >= %s/.test(rest));
t('…against the cutoff', /havato_booking_cutoff\(\)/.test(rest));
t('the old date-only filter is gone from Explore',
  !/e\.status IN \('open','matched'\) AND v\.verified = 1 AND e\.event_date >= CURDATE\(\)/.test(rest));
t('the query is still prepared, not interpolated', /\$wpdb->prepare\(\s*\n\s*"e\.status IN/.test(rest));

// Hiding a card is presentation. The endpoint has to refuse too.
t('join_event applies the same cutoff', /if \( \$starts < havato_booking_cutoff\(\) \)/.test(rest));
t('…with its own message', /'havato_too_late'/.test(rest));
t('that message is trilingual', /'event_too_soon'\s*=> array\( 'fa' =>.*'en' =>.*'tr' =>/.test(i18n));

(() => {
  // Execute the comparison the SQL performs.
  const pad = n => String(n).padStart(2, '0');
  const fmt = d => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ` +
    `${pad(d.getHours())}:${pad(d.getMinutes())}:00`;

  const NOW = new Date('2026-07-30T20:41:00');
  const cutoff = fmt(new Date(NOW.getTime() + 5 * 3600e3));
  const at = (days, h, m = 0) => {
    const d = new Date(NOW); d.setDate(d.getDate() + days); d.setHours(h, m, 0, 0); return d;
  };
  const shown = d => fmt(d) >= cutoff;

  t('yesterday is hidden', shown(at(-1, 18)) === false);
  t('earlier today is hidden (the bug: date-only kept it)', shown(at(0, 18)) === false);
  t('starting in 19 minutes is hidden', shown(at(0, 21)) === false);
  t('starting in just over 2 hours is hidden', shown(at(0, 23)) === false);
  t('exactly 5 hours away is shown', shown(at(1, 1, 41)) === true);
  t('6 hours away is shown', shown(at(1, 3)) === true);
  t('tomorrow evening is shown', shown(at(1, 18)) === true);
  t('next week is shown', shown(at(7, 19, 30)) === true);

  // A midnight event must not be judged by its date alone.
  t('a 00:30 event tomorrow is judged on its time, not its date',
    shown(at(1, 0, 30)) === false);
})();

// The guest's own bookings are a different question from what is joinable.
t('the dashboard still shows a seat you already hold today',
  /AND e\.event_date >= CURDATE\(\)[\s\S]{0,120}ORDER BY e\.event_date ASC/.test(rest));
t('…and the reason is recorded', /a seat the guest already holds/.test(rest));

console.log(f ? `\n❌ ${f} failing` : '\n✅ dropdown readable, buttons stacked, stale gatherings hidden');
process.exit(f ? 1 : 0);
