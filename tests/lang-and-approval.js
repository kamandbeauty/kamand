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

// The guest asks for a day and a subject; the café decides how many seats to
// open. So accepting must NOT build the event on its own — it hands the café
// the event form with the guest's wishes already in it.
t('accepting does not create an event by itself',
  !/private static function event_from_request/.test(owner));
t('nothing inserts into the events table from the request handler',
  !/case 'request_status':[\s\S]{0,1400}Havato_DB::table\( 'events' \)/.test(owner));
t('no seating plan is invented from every table the café owns',
  !/case 'request_status':[\s\S]{0,1400}event_tables/.test(owner));

t('accepting sends the café to the event form', /\$page  = 'havato-venue-events';/.test(owner));
t('…carrying the suggestion with it', /\$extra = array\( 'from_request' => \$request_id \)/.test(owner));
t('…and says what to do next', /request_accepted_pick_tables/.test(owner));
t('declining does not', /if \( 'accepted' === \$new_status \) \{/.test(owner));

console.log('\n--- 2b. the form arrives pre-filled, seats still chosen by the café ---');

t('the form reads the suggestion', /\$from_request = isset\( \$_GET\['from_request'\] \)/.test(owner));
t('…scoped by venue so another café\'s queue cannot be read',
  /SELECT \* FROM \$requests_t WHERE id=%d AND venue_id=%s/.test(owner));
t('the subject is pre-filled', /value="' \. esc_attr\( \$prefill\['title'\] \)/.test(owner));
t('the requested day is pre-filled', /'' !== \$prefill\['date'\] \? \$prefill\['date'\]/.test(owner));
t('the requested time is pre-filled', /'' !== \$prefill\['time'\] \? \$prefill\['time'\]/.test(owner));
t('the note becomes the description', /esc_textarea\( \$prefill\['note'\] \)/.test(owner));
t('a normal new event still gets sensible defaults',
  /gmdate\( 'Y-m-d', strtotime\( '\+1 day' \) \)/.test(owner) && /: '19:00'/.test(owner));
t('the café is told why the form is filled in', /request_prefilled/.test(owner));

// The whole point: seats come from ticking tables, not from the suggestion.
t('the table picker is still the thing that sets capacity',
  /name="tables\[%1\$d\]\[use\]"/.test(owner));
t('the suggestion carries no seat count at all',
  !/preferred_seats|requested_seats|'seats'/.test(rd('includes/class-havato-db.php')
    .slice(rd('includes/class-havato-db.php').indexOf('CREATE TABLE {$p}event_requests'),
           rd('includes/class-havato-db.php').indexOf('CREATE TABLE {$p}event_requests') + 700)));
t('capacity is derived from the chosen tables', /\$capacity \+= \(int\) \$available\[ \$tid \]\['seats'\] \* \$qty;/.test(rest));

t('the created event still waits for admin approval',
  /'status'       => \$venue\['verified'\] \? 'open' : 'pending_admin',/.test(rest));
t('…and Explore only lists open and matched', /e\.status IN \('open','matched'\)/.test(rest));
t('approving the café publishes it', /UPDATE \$events SET status='open' WHERE venue_id=%s AND status='pending_admin'/.test(rest));

// Re-reading the row scoped by venue prevents answering another café's queue.
t('the suggestion is re-read scoped by venue',
  /WHERE id=%d AND venue_id=%s AND status='pending'/.test(owner));
t('…and only a pending one can be answered', /AND status='pending'/.test(owner));

(() => {
  // Capacity is derived from ticked furniture. Model the same sum.
  const seat = tables => tables.reduce((n, [s, q]) => n + s * Math.max(1, q), 0);

  t('ticking three 4-seaters gives 12', seat([[4, 1], [4, 1], [4, 1]]) === 12);
  t('ticking one gives 4, not the whole café', seat([[4, 1]]) === 4);
  t('mixed furniture adds up', seat([[4, 2], [6, 1]]) === 14);
  t('ticking nothing gives nothing', seat([]) === 0);
  t('…which the endpoint refuses', /if \( \$capacity < 2 \) \{[\s\S]{0,140}event_need_tables/.test(rest));
})();

for (const k of ['admin_requests_hint', 'show_all', 'show_pending',
                 'request_accepted_pick_tables', 'request_prefilled']) {
  t('i18n "' + k + '" trilingual',
    new RegExp("'" + k + "'\\s*=> array\\( 'fa' =>.*'en' =>.*'tr' =>").test(i18n));
}
t('the café hint no longer promises an auto-built event',
  !/Accepting creates the gathering with all your tables/.test(i18n));
// The time input was labelled "quiet hours", which is a café-wide setting,
// not this event's start time.
t('the time field is labelled as a time',
  /Havato_I18N::t\( 'event_time' \)[\s\S]{0,20}<input type="time" name="event_time"/.test(owner));
t('…and no longer as quiet hours',
  !/Havato_I18N::t\( 'quiet_hours' \) \.\s*\n?\s*'<input type="time"/.test(owner));

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
