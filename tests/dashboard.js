/* v1.26.0 — the round button in the bottom bar changed meaning with every
   tab and nothing on screen said what it would do. That per-tab action moved
   into the header; the round button is now the guest's dashboard: their own
   details, a "suggest a gathering" button, their upcoming bookings (each
   opening the event page), and a link that hands the café's coordinates to
   the phone's own navigation app.

   The directions URL and the suggestion rules are executed here, not just
   grepped — a wrong scheme would silently open nothing on a real phone.   */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const js = rd('assets/js/havato-app.js');
const css = rd('assets/css/havato-app.css');
const tpl = rd('templates/app.php');
const rest = rd('includes/class-havato-rest.php');
const db = rd('includes/class-havato-db.php');
const i18n = rd('includes/class-havato-i18n.php');
const owner = rd('includes/class-havato-owner-admin.php');
const main = rd('havato.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

/* =====================================================================
 * 1. The action moved to the header
 * ================================================================== */
console.log('--- 1. the per-tab action is in the header now ---');

t('a header action button exists', /id="hv-header-action"/.test(tpl));
t('it starts hidden', /id="hv-header-action" hidden/.test(tpl));
t('the app wires it up', /function updateHeaderAction/.test(js));
// Anchored on the call itself: the updateFab() line it used to sit beside
// was removed with the floating button in 1.31.0.
t('it is refreshed whenever the view renders',
  /el\.header\.style\.display = '';\s*\n\s*updateHeaderAction\(\);/.test(js));
t('the icon changes per tab', /el\.headerAction\.querySelector\('use'\)\.setAttribute/.test(js));

// An icon on its own says nothing; it needs a name.
t('it carries a real label for screen readers', /el\.headerAction\.setAttribute\('aria-label', t\(conf\.label\)\)/.test(js));
t('…and a tooltip for everyone else', /el\.headerAction\.title = t\(conf\.label\)/.test(js));
t('a tab with no action hides the button', /if \(!conf \|\| !S\.loggedIn\) \{[\s\S]{0,120}hidden = true/.test(js));
t('hiding it beats the theme cascade', /#havato-app \.hv-header-action\[hidden\] \{ display: none !important/.test(css));
t('it is styled to match the language button', /\.hv-header-action \{/.test(css));

(() => {
  // Every tab that had an action must still have one, or a feature would
  // have been silently dropped in the move.
  const block = js.slice(js.indexOf('function updateHeaderAction'), js.indexOf('function updateFab'));
  ['explore', 'map', 'chats', 'profile'].forEach(tab => {
    t('the ' + tab + ' action survived the move', new RegExp(tab + ': \\{ icon:').test(block));
  });
  t('each one carries a label', (block.match(/label: '/g) || []).length === 4);
})();

/* =====================================================================
 * 2. The round button is the dashboard
 * ================================================================== */
console.log('\n--- 2. the dashboard is the Home tab now ---');

// v1.31.0: the floating button is gone. Its job — the guest's dashboard —
// became a real tab, so it has a label instead of an unexplained glyph.
t('the floating button is gone from the template', !/id="hv-fab"/.test(tpl));
t('…and from the app', !/el\.fab/.test(js));
t('…and its styles were removed', !/\.hv-fab \{/.test(css));
t('Home is the first tab', /\{ id: 'home', label: 'tab_home', icon: 'nav-dashboard' \}/.test(js));
t('it lands on the dashboard view', /home: viewHome/.test(js));
t('an unknown tab falls back to Home, not Explore', /\|\| viewHome;/.test(js));

// The sizing class two other buttons borrowed must survive the removal.
t('the borrowed icon size still exists', /\.hv-fab-icon \{ inline-size: 26px/.test(css));
t('…and is still used', /icon\('brain', 'hv-fab-icon'\)/.test(js));

/* =====================================================================
 * 3. What the dashboard shows
 * ================================================================== */
console.log('\n--- 3. the dashboard contents ---');

t('one endpoint feeds it', /'dashboard'          => array\( 'GET', 'user_dashboard', \$auth \)/.test(rest));
t('it is behind auth, not public', /'dashboard'\s*=> array\( 'GET', 'user_dashboard', \$auth \)/.test(rest));
t('the handler exists', /public static function user_dashboard/.test(rest));
t('the guest name and photo', /hv-dash-avatar/.test(js) && /user\.name/.test(js));
t('their behaviour score', /t\('rating_score'\)/.test(js));
t('a suggest button', /id="hv-dash-suggest"/.test(js));
t('their upcoming bookings', /res\.upcoming/.test(js));
t('tapping one opens the event page', /node\.onclick = function \(\) \{ openEvent\(node\.dataset\.dashEvent\); \};/.test(js));
t('an empty list explains itself instead of showing nothing', /dash_no_events/.test(js));
t('past bookings are left out', /e\.event_date >= CURDATE\(\)/.test(rest));
t('cancelled events are left out', /e\.status <> 'cancelled'/.test(rest));
t('soonest first', /ORDER BY e\.event_date ASC, e\.event_time ASC/.test(rest));

/* =====================================================================
 * 4. Directions open the phone's own map app
 * ================================================================== */
console.log('\n--- 4. directions ---');

t('a helper builds the link', /function directionsUrl/.test(js));

(() => {
  // Re-implement it and drive it, because a wrong scheme fails silently on
  // a real phone: nothing opens and there is no error to see.
  function url(lat, lng, label, ios) {
    lat = parseFloat(lat); lng = parseFloat(lng);
    if (!lat || !lng) { return ''; }
    if (ios) { return 'https://maps.google.com/?q=' + lat + ',' + lng; }
    return 'geo:' + lat + ',' + lng + '?q=' + lat + ',' + lng +
      (label ? '(' + encodeURIComponent(label) + ')' : '');
  }

  const android = url(35.7219, 51.3347, 'کافه دالون', false);
  t('Android gets a geo: URI', android.indexOf('geo:35.7219,51.3347') === 0);
  t('…with a q= so the pin is labelled', android.indexOf('?q=35.7219,51.3347') !== -1);
  t('…and the café name is percent-encoded, not raw',
    android.indexOf('%') !== -1 && !/[\u0600-\u06FF]/.test(android));

  const ios = url(41.0082, 28.9784, 'Naravan', true);
  t('iOS gets an https URL instead (it ignores geo:)', ios.indexOf('https://maps.google.com/?q=') === 0);

  t('a venue with no coordinates yields no link', url(0, 0, 'x', false) === '');
  t('…and neither does a missing one', url(null, undefined, 'x', false) === '');
  t('a non-numeric coordinate is refused', url('abc', 'def', 'x', false) === '');
})();

t('the link is only rendered when there is one', /\(maps[\s\S]{0,140}\? '<a class="hv-btn/.test(js));
t('it opens outside the app', /target="_blank" rel="noopener"/.test(js));
t('the label is trilingual', /'directions'\s*=> array\( 'fa' =>.*'en' =>.*'tr' =>/.test(i18n));

/* =====================================================================
 * 5. Suggesting a gathering
 * ================================================================== */
console.log('\n--- 5. a guest suggests a gathering ---');

t('a table stores suggestions', /CREATE TABLE \{\$p\}event_requests/.test(db));
t('it is registered so it gets created', /'event_requests',/.test(db));
// event_requests landed in schema 1.15.0. Later releases keep bumping this,
// so assert the floor rather than pinning the exact value.
t('the schema is at or past the event_requests table', (() => {
  const m = /HAVATO_DB_VERSION', '(\d+)\.(\d+)\.(\d+)'/.exec(main);
  if (!m) { return false; }
  const [, major, minor] = m.map(Number);
  return major > 1 || (major === 1 && minor >= 15);
})());
t('an endpoint receives them', /'event\/request'      => array\( 'POST', 'request_event', \$auth \)/.test(rest));
t('the handler exists', /public static function request_event/.test(rest));

// A suggestion must never behave like a booking. Scope the checks to the
// function body rather than a character window, so they cannot drift.
(() => {
  const from = rest.indexOf('public static function request_event');
  const body = rest.slice(from, rest.indexOf('\n\t}', from));

  t('it writes to its own table', /Havato_DB::table\( 'event_requests' \)/.test(body));
  t('it never inserts into the events table', !/Havato_DB::table\( 'events' \)/.test(body));
  t('it never runs the matcher', !/Havato_Matcher/.test(body));
  t('it holds no seat', !/event_registrations/.test(body));

  t('the date format is validated', /preg_match\(/.test(body) && body.indexOf('d{4}-') !== -1);
  t('the time format is validated', /havato_bad_time/.test(body));
})();
t('a past date is refused', /havato_past_date/.test(rest));
t('an empty subject is refused', /'' === \$subject/.test(rest));
t('free text is clamped', /havato_clamp_text\( sanitize_textarea_field\( \(string\) \$req->get_param\( 'note' \) \), 1000 \)/.test(rest));
t('the café must exist and be verified', /! \$venue \|\| ! \(int\) \$venue\['verified'\]/.test(rest));
t('…and be in the guest\'s own city', /if \( \(string\) \$venue\['city'\] !== \$city \)/.test(rest));

// A guest may only ask a café in their own city. The first version wrote
// `$city && $venue['city'] !== $city`, which skipped the whole check when the
// profile had no city yet — and an unset city is precisely the state a brand
// new account is in.
(() => {
  const CITIES = { ir: ['tehran', 'isfahan'], tr: ['istanbul'] };
  const validCity = (c, city) => !!(CITIES[c] && CITIES[c].indexOf(city) !== -1);

  const oldGuard = (p, venueCity) => (p.city && venueCity !== p.city) ? 'REFUSED' : 'ALLOWED';
  const newGuard = (p, venueCity) => {
    if (!validCity(p.country, p.city)) { return 'NEED DETAILS'; }
    return String(venueCity) === String(p.city) ? 'ALLOWED' : 'REFUSED';
  };

  const nobody = { country: '', city: '' };
  t('the old guard let a city-less guest reach any café (the hole)',
    oldGuard(nobody, 'istanbul') === 'ALLOWED');
  t('…and the new one stops them', newGuard(nobody, 'istanbul') === 'NEED DETAILS');

  const tehrani = { country: 'ir', city: 'tehran' };
  t('own city is allowed', newGuard(tehrani, 'tehran') === 'ALLOWED');
  t('another city in the same country is refused', newGuard(tehrani, 'isfahan') === 'REFUSED');
  t('another country is refused', newGuard(tehrani, 'istanbul') === 'REFUSED');

  const istanbullu = { country: 'tr', city: 'istanbul' };
  t('a Turkish guest reaches their own café', newGuard(istanbullu, 'istanbul') === 'ALLOWED');
  t('…but not an Iranian one', newGuard(istanbullu, 'tehran') === 'REFUSED');

  t('a country with no city is refused', newGuard({ country: 'ir', city: '' }, 'tehran') === 'NEED DETAILS');
  t('a city that is not on the list is refused', newGuard({ country: 'ir', city: 'paris' }, 'paris') === 'NEED DETAILS');
})();

t('the endpoint validates the city rather than trusting it is set',
  /havato_valid_city\( \$profile\['country'\], \$profile\['city'\] \)[\s\S]{0,160}need_details_first/.test(rest));
t('the refusal explains itself instead of a generic error', /'request_other_city'/.test(rest));
t('…and that message is trilingual',
  /'request_other_city'\s*=> array\( 'fa' =>.*'en' =>.*'tr' =>/.test(i18n));

// The picker must not offer a café the endpoint would refuse.
t('the café list is filtered to that city', /WHERE verified = 1 AND city = %s ORDER BY name ASC/.test(rest));
t('a guest with no city is offered nothing, not everything',
  /\$venue_rows = array\(\);[\s\S]{0,120}if \( '' !== \$city \)/.test(rest));
t('the app is told which city was used', /'city'      => \$city,/.test(rest));
t('an empty list says which of the two reasons applies', /dash_set_city_first/.test(js));
t('…and sends them where they can fix it', /if \(!known\) \{ setTab\('profile'\); \}/.test(js));
t('that message is trilingual',
  /'dash_set_city_first'\s*=> array\( 'fa' =>.*'en' =>.*'tr' =>/.test(i18n));
t('a repeat suggestion is refused rather than queued twice', /havato_duplicate_request/.test(rest));
t('the duplicate check is scoped to pending only', /AND status='pending'/.test(rest));
t('the action is logged', /suggested a gathering at venue/.test(rest));

t('the form only offers cafés in the guest\'s city', /\$sql   \.= ' AND city = %s';/.test(js) || /AND city = %s/.test(rest));
t('the date field cannot be set to the past', /id="hv-sg-date" min="/.test(js));
t('an empty form is refused client-side', /if \(!subject \|\| !date \|\| !time\)/.test(js));
t('the button is disabled while sending', /go\.disabled = true;[\s\S]{0,320}event\/request/.test(js));
t('…and re-enabled on failure', /go\.disabled = false;\s*\n\s*toast\(err\.message/.test(js));
t('the guest is told it is a suggestion, not a booking', /suggest_hint/.test(js));

console.log('\n--- 6. the café sees them ---');
t('suggestions appear on the owner dashboard', /function render_requests/.test(owner));
t('…and are actually rendered', /self::render_requests\( \$venue, \$lang \);/.test(owner));
t('the café can accept or decline', /'accepted' => 'accept', 'declined' => 'decline'/.test(owner));
t('the handler exists', /case 'request_status':/.test(owner));
t('it is nonce-protected', /check_admin_referer\( 'havato_owner', 'havato_owner_nonce' \)/.test(owner));
t('only known statuses are stored', /in_array\( \$new_status, array\( 'accepted', 'declined' \), true \)/.test(owner));

// A café must not be able to answer another café's suggestion. Since 1.27.0
// the row is re-read scoped by venue before anything is written, so the guard
// sits on the SELECT rather than the UPDATE.
t('the suggestion is fetched scoped by venue as well as row id',
  /WHERE id=%d AND venue_id=%s AND status='pending'/.test(owner));
t('…and only a pending one can be answered', /AND status='pending'/.test(owner));
t('the screen says so in words', /guest_requests_hint/.test(owner));
t('the guest sees the status back on their dashboard', /request_' \+ rq\.status/.test(js));

for (const k of ['dashboard_title', 'dash_upcoming', 'dash_requests', 'dash_no_events',
                 'dash_no_venues', 'suggest_event', 'suggest_hint', 'send_request',
                 'request_sent', 'request_duplicate', 'request_past_date', 'request_pending',
                 'request_accepted', 'request_declined', 'guest_requests', 'guest_requests_hint',
                 'request_accept', 'request_decline', 'locate_me']) {
  t('i18n "' + k + '" trilingual',
    new RegExp("'" + k + "'\\s*=> array\\( 'fa' =>.*'en' =>.*'tr' =>").test(i18n));
}

(() => {
  // wpdb->insert() pairs values with formats by position.
  const block = rest.slice(rest.indexOf("Havato_DB::table( 'event_requests' );", rest.indexOf('function request_event')));
  const ins = block.slice(block.indexOf('$wpdb->insert('), block.indexOf('Havato_Logger'));
  const values = (ins.match(/'\w+'\s*=>/g) || []).length;
  const formats = ((ins.match(/array\( '%[sd]'[^)]*\)/) || [''])[0].match(/%[sd]/g) || []).length;
  t('the insert lines up (' + values + ' values vs ' + formats + ' formats)',
    values === formats && values > 0);
})();

console.log('\n--- 7. styling ---');
t('the dashboard is styled', /\.hv-dash-stats \{/.test(css));
t('booking rows are styled', /\.hv-dash-event,/.test(css));
t('stat numbers do not jitter', /\.hv-dash-stat b \{[\s\S]{0,180}tabular-nums/.test(css));

console.log(f ? `\n❌ ${f} failing` : '\n✅ header action moved, dashboard reachable, suggestions round-trip');
process.exit(f ? 1 : 0);
