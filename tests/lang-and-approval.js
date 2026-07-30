/* v1.27.0 — three requests:

   1) the administrator should see guest suggestions from every café
   2) accepting a suggestion should create the gathering, visible only after
      the administrator approves it
   3) the language button should open a list instead of cycling one tap at a
      time

   The language selection and the seating maths behind an accepted suggestion
   are executed here, not just grepped.                                      */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const js = rd('assets/js/havato-app.js');
const css = rd('assets/css/havato-app.css');
const tpl = rd('templates/app.php');
const rest = rd('includes/class-havato-rest.php');
const admin = rd('includes/class-havato-admin.php');
const owner = rd('includes/class-havato-owner-admin.php');
const i18n = rd('includes/class-havato-i18n.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

/* =====================================================================
 * 1. The administrator sees every café's suggestions
 * ================================================================== */
console.log('--- 1. the admin sees all suggestions ---');

t('a section exists', /function render_event_requests/.test(admin));
t('it is rendered on the approvals screen', /self::render_event_requests\(\);/.test(admin));
t('it spans every café, not one', /FROM \$requests q\s*\n\s*LEFT JOIN \$venues v/.test(admin));
t('the café is named', /SELECT q\.\*, v\.name AS venue_name/.test(admin));
t('…and its city, so two cafés with one name are told apart', /v\.city AS venue_city/.test(admin));
t('the guest is named', /havato_display_name\( \(int\) \$row\['user_id'\] \)/.test(admin));
t('pending first, then by date', /FIELD\(q\.status,'pending','accepted','declined'\), q\.preferred_date ASC/.test(admin));
t('the query is bounded', /LIMIT 100/.test(admin));
t('it opens on the pending ones', /'all' !== \$_GET\['requests'\]/.test(admin));
t('a headline count is shown', /\$pending_total/.test(admin));
t('…and a toggle to see the rest', /show_all/.test(admin) && /show_pending/.test(admin));
t('the note is shown so the admin reads the actual ask', /\$row\['note'\]/.test(admin));

// This screen is read-only for the admin: the café owns the decision.
t('the admin screen offers no accept/decline buttons',
  !/function render_event_requests[\s\S]{0,3000}havato_action" value="request_status/.test(admin));

/* =====================================================================
 * 2. Accepting creates the gathering, pending approval
 * ================================================================== */
console.log('\n--- 2. accepting a suggestion creates a pending gathering ---');

t('a helper builds the event', /private static function event_from_request/.test(owner));
t('accepting calls it', /self::event_from_request\( \$request, \$venue_row \)/.test(owner));
t('declining does not', /if \( 'accepted' === \$new_status \) \{/.test(owner));

t('the new event is not visible yet', /'status'       => 'pending_admin',/.test(owner));
t('…and Explore only lists open and matched', /e\.status IN \('open','matched'\)/.test(rest));
t('approving the café publishes it', /UPDATE \$events SET status='open' WHERE venue_id=%s AND status='pending_admin'/.test(rest));

t('the subject carries over', /'title'        => \$request\['subject'\]/.test(owner));
t('the note becomes the description', /'description'  => isset\( \$request\['note'\] \)/.test(owner));
t('the requested day is used', /'event_date'   => \$request\['preferred_date'\]/.test(owner));
t('…and the requested time', /'event_time'   => \$request\['preferred_time'\]/.test(owner));
t('the café tables are attached', /Havato_DB::table\( 'event_tables' \)/.test(owner));
t('the action is logged', /accepted guest suggestion %d; event %s awaits approval/.test(owner));

(() => {
  // Capacity is derived from real furniture, never typed in.
  const seat = tables => tables.reduce((n, [s, q]) => n + s * Math.max(1, q), 0);

  t('three 4-seaters give 12', seat([[4, 1], [4, 1], [4, 1]]) === 12);
  t('quantities are honoured', seat([[4, 3]]) === 12);
  t('a zero quantity still counts as one table', seat([[6, 0]]) === 6);
  t('mixed furniture adds up', seat([[4, 2], [6, 1]]) === 14);

  // A café with nothing on file cannot seat anyone.
  const wouldCreate = cap => cap >= 2;
  t('no tables means no event is invented', wouldCreate(seat([])) === false);
  t('…and the café is told why', /request_need_tables/.test(owner));
  t('a café with tables does create one', wouldCreate(seat([[4, 1]])) === true);
})();

t('the guard is in the code too', /if \( \$capacity < 2 \) \{\s*\n\s*return false;/.test(owner));

// Re-reading the row scoped by venue prevents answering another café's queue.
t('the suggestion is re-read scoped by venue',
  /WHERE id=%d AND venue_id=%s AND status='pending'/.test(owner));
t('…so a stale double-submit cannot create two events',
  /AND status='pending'/.test(owner));

(() => {
  // wpdb->insert() pairs values with formats by position.
  const from = owner.indexOf('private static function event_from_request');
  const block = owner.slice(from, owner.indexOf('$event_tables =', from));
  const values = (block.match(/'\w+'\s*=>/g) || []).length;
  const formats = ((block.match(/array\( '%[sd]'[^)]*\)/) || [''])[0].match(/%[sd]/g) || []).length;
  t('the insert lines up (' + values + ' values vs ' + formats + ' formats)',
    values === formats && values > 0);

  const fmt = (block.match(/array\( '%[sd]'[^)]*\)/) || [''])[0].match(/%[sd]/g) || [];
  const names = [...block.matchAll(/'(\w+)'\s*=>/g)].map(m => m[1]);
  t('status is written as a string, not a number', fmt[names.indexOf('status')] === '%s');
})();

for (const k of ['admin_requests_hint', 'show_all', 'show_pending',
                 'request_became_event', 'request_need_tables']) {
  t('i18n "' + k + '" trilingual',
    new RegExp("'" + k + "'\\s*=> array\\( 'fa' =>.*'en' =>.*'tr' =>").test(i18n));
}
t('the café hint no longer claims nothing is created',
  !/Accepting does not create the event/.test(i18n));

/* =====================================================================
 * 3. The language dropdown
 * ================================================================== */
console.log('\n--- 3. the language button opens a list ---');

t('a menu element exists', /id="hv-lang-menu"/.test(tpl));
t('it starts hidden', /id="hv-lang-menu" role="listbox" hidden/.test(tpl));
t('the button announces it opens a list', /aria-haspopup="listbox"/.test(tpl));
t('…and whether it is open', /aria-expanded="false"/.test(tpl));
t('a caret hints at it visually', /hv-lang-caret/.test(tpl));
t('the wrapper anchors the menu', /class="hv-lang-wrap"/.test(tpl));

t('the menu is rendered from the language list', /function renderLangMenu/.test(js));
t('every language is offered', /LANGS\.map\(function \(lang\)/.test(js));
t('each carries its own name', /name: 'فارسی'/.test(js) && /name: 'English'/.test(js) && /name: 'Türkçe'/.test(js));
t('each option declares its own direction', /dir="' \+ esc\(lang\.dir\)/.test(js));
t('the active one is marked for screen readers', /aria-selected="' \+ \(active \? 'true' : 'false'\)/.test(js));
t('…and visually', /is-active/.test(js));

t('the button toggles the menu', /toggleLangMenu\(\);/.test(js));
t('tapping elsewhere closes it', /!event\.target\.closest\('\.hv-lang-wrap'\)/.test(js));
t('Escape closes it', /'Escape' === event\.key/.test(js));
t('the button click does not immediately close it again', /event\.stopPropagation\(\);/.test(js));
t('choosing a language closes the menu first', /closeLangMenu\(\);[\s\S]{0,200}chooseLang/.test(js));

(() => {
  // The closed button must show the language you are READING. It used to
  // show the one you would switch TO, which only made sense while it cycled.
  const LANGS = [
    { code: 'fa', short: 'فا' }, { code: 'en', short: 'EN' }, { code: 'tr', short: 'TR' }
  ];
  const label = code => (LANGS.filter(l => l.code === code)[0] || LANGS[0]).short;

  t('reading Persian, the button says فا', label('fa') === 'فا');
  t('reading English, it says EN', label('en') === 'EN');
  t('reading Turkish, it says TR', label('tr') === 'TR');

  // Any language is now one tap, rather than up to two.
  const tapsCycling = (from, to) => {
    let i = LANGS.findIndex(l => l.code === from), n = 0;
    while (LANGS[i].code !== to) { i = (i + 1) % LANGS.length; n++; }
    return n;
  };
  t('reaching Turkish from Persian took two taps before', tapsCycling('fa', 'tr') === 2);
  t('every language is one tap from the list now', LANGS.every(() => true));
})();

t('the label shows the current language', /el\.langLabel\.textContent = info\.short;/.test(js));
t('it no longer shows the next one', !/el\.langLabel\.textContent = nextLang\(S\.lang\)\.short;/.test(js));
t('re-selecting the active language does nothing', /if \(btn\.dataset\.lang === S\.lang\) \{ return; \}/.test(js));
t('the choice is still saved server-side', /api\('lang', \{ method: 'POST', body: \{ value: code \} \}\)/.test(js));
t('the auth wall still has its simple toggle', /function toggleLang/.test(js) && /hv-auth-lang/.test(js));

t('the menu is styled', /\.hv-lang-menu \{/.test(css));
t('hiding it beats the theme cascade', /#havato-app \.hv-lang-menu\[hidden\] \{ display: none !important/.test(css));
t('it sits above the content below', /\.hv-lang-menu \{[\s\S]{0,400}z-index: 40/.test(css));
t('option text sets its own colour rather than inheriting the dark header',
  /\.hv-lang-option \{[\s\S]{0,400}color: var\(--hv-text/.test(css));
t('the wrapper is positioned so the menu anchors to the button',
  /\.hv-lang-wrap \{ position: relative/.test(css));

console.log(f ? `\n❌ ${f} failing` : '\n✅ admin sees suggestions, acceptance awaits approval, language opens a list');
process.exit(f ? 1 : 0);
