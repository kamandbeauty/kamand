/* v1.25.0 — two requests from the Explore screenshot:

   1) the line under the café name should say what the gathering is about
   2) tapping "reserve a seat" should open the event's own page first:
      the café, its menu, a description, the date and time, a live countdown,
      and only then the reserve button

   The countdown maths and the subject fallback are executed here, not just
   grepped, so a wrong unit or an off-by-one is caught.                      */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const js = rd('assets/js/havato-app.js');
const css = rd('assets/css/havato-app.css');
const rest = rd('includes/class-havato-rest.php');
const db = rd('includes/class-havato-db.php');
const i18n = rd('includes/class-havato-i18n.php');
const admin = rd('includes/class-havato-admin.php');
const owner = rd('includes/class-havato-owner-admin.php');
const seeder = rd('includes/class-havato-seeder.php');
const main = rd('havato.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

/* =====================================================================
 * 1. The card names the subject
 * ================================================================== */
console.log('--- 1. the card says what the evening is ---');

t('the subject line is rendered', /esc\(t\('event_subject'\)\) \+ ': ' \+ esc\(subject\)/.test(js));
t('the label is trilingual', /'event_subject'\s*=> array\( 'fa' =>.*'en' =>.*'tr' =>/.test(i18n));

(() => {
  // A café may leave the title blank, so the theme is the fallback. Model
  // the same expression the card uses.
  const subject = ev => (ev.title && String(ev.title).trim()) || ev.theme || '';

  t('a title is preferred', subject({ title: 'شب موسیقی', theme: 'Board games' }) === 'شب موسیقی');
  t('the theme fills in when there is no title', subject({ title: '', theme: 'Board games' }) === 'Board games');
  t('whitespace does not count as a title', subject({ title: '   ', theme: 'Film' }) === 'Film');
  t('with neither, nothing is claimed', subject({ title: '', theme: '' }) === '');
})();

t('an empty subject renders no line at all', /subject \? '<p class="hv-event-title">/.test(js));
t('the subject is computed once per card', /var subject = \(event\.title && String\(event\.title\)\.trim\(\)\) \|\| event\.theme \|\| '';/.test(js));

/* =====================================================================
 * 2. Reserve opens the event page first
 * ================================================================== */
console.log('\n--- 2. the reserve button opens the event page ---');

t('the card button opens the event', /btn\.onclick = function \(\) \{ openEvent\(btn\.dataset\.eventJoin\); \};/.test(js));
t('it no longer jumps straight to the seat picker',
  !/btn\.onclick = function \(\) \{ openReserve\(btn\.dataset\.eventJoin/.test(js));
t('the event page exists', /function openEvent\(eventId\)/.test(js));
t('the seat picker is still reachable from it', /openReserve\(event\.id, parseInt\(event\.seats_left, 10\)/.test(js));
t('choosing seats stops the countdown first', /stopCountdown\(\);\s*\n\s*openReserve\(/.test(js));

// One request, not two: the menu must not pop in after the page has drawn.
t('a single endpoint returns event and café', /'event'\s*=> array\( 'GET', 'get_event', \$pub \)/.test(rest));
t('the handler exists', /public static function get_event\(/.test(rest));
t('it returns both halves', /'event' => self::event_payload[\s\S]{0,220}'venue' => \$venue \? self::venue_payload/.test(rest));
t('the café phone stays out of a guest payload', /self::venue_payload\( \$venue, false \)/.test(rest));
t('the client makes one call', /api\('event', \{ params: \{ id: eventId \} \}\)/.test(js));

console.log('\n--- 3. what the page shows ---');
t('the café name', /esc\(pick\(venue\.name\) \|\| pick\(event\.venue\)\)/.test(js));
t('the subject', /hv-event-subject/.test(js));
t('the date, weekday and time', /pick\(event\.weekday\)\) \+ ' · ' \+ esc\(pick\(event\.date\)\) \+ ' · ' \+ num\(event\.time\)/.test(js));
t('the description', /event\.description[\s\S]{0,160}hv-event-desc/.test(js));
t('the café address', /venue\.address \? '<p class="hv-muted">'/.test(js));
t('the menu', /venue\.menu \|\| \[\]/.test(js));
t('…with prices', /pick\(item\.price_label\)/.test(js));
t('…and the display-only notice', /menu_display_only/.test(js));
t('seats left', /num\(event\.seats_left\) \+ ' ' \+ esc\(t\('seats_left'\)\)/.test(js));
t('a reserve button', /id="hv-event-reserve"/.test(js));
t('a full event offers no button', /full \|\| event\.status !== 'open'[\s\S]{0,140}disabled/.test(js));
t('an already-booked guest is told so', /event\.joined[\s\S]{0,120}joined_event/.test(js));
t('a way to close the page', /data-close="1"[\s\S]{0,60}esc\(t\('close'\)\)/.test(js));

/* =====================================================================
 * 4. The countdown
 * ================================================================== */
console.log('\n--- 4. the countdown ---');

t('the server sends the remaining seconds', /'starts_in'   => self::seconds_until/.test(rest));
t('a helper computes it', /private static function seconds_until/.test(rest));
t('it never goes negative', /return max\( 0, \$starts - \$now \);/.test(rest));
t('it uses the site clock on both sides', /strtotime\( havato_now\(\) \)/.test(rest));
t('a malformed date yields zero rather than a wrong number', /if \( ! \$starts \|\| ! \$now \) \{\s*\n\s*return 0;/.test(rest));

(() => {
  // Re-implement the client's formatting and drive it. Seconds are only
  // shown once the wait is short enough that watching them makes sense.
  function parts(left) {
    const days = Math.floor(left / 86400);
    const hours = Math.floor((left % 86400) / 3600);
    const mins = Math.floor((left % 3600) / 60);
    const secs = left % 60;
    const out = [];
    if (days) { out.push(days + 'd'); }
    if (days || hours) { out.push(hours + 'h'); }
    out.push(mins + 'm');
    if (!days && !hours) { out.push(secs + 's'); }
    return out.join(' ');
  }

  t('two days out', parts(2 * 86400 + 3 * 3600 + 4 * 60) === '2d 3h 4m');
  t('hours and minutes', parts(3 * 3600 + 25 * 60) === '3h 25m');
  t('under an hour shows seconds', parts(9 * 60 + 5) === '9m 5s');
  t('under a minute still reads sensibly', parts(45) === '0m 45s');
  t('exactly one day does not lose the hours slot', parts(86400) === '1d 0h 0m');
  t('no unit is ever negative', [0, 59, 3600, 86399, 172800].every(n => !/-/.test(parts(n))));
})();

t('zero shows "already started" instead of counting up', /if \(left <= 0\)[\s\S]{0,120}event_started/.test(js));
t('…and stops ticking there', /event_started[\s\S]{0,160}stopCountdown\(\);/.test(js));
t('the timer is declared in state', /countdownTimer: null/.test(js));
t('closing the modal clears it (no leaked interval)', /function closeModal\(\)[\s\S]{0,260}stopCountdown\(\);/.test(js));
t('a new countdown replaces the old one', /function startCountdown\(\) \{\s*\n\s*stopCountdown\(\);/.test(js));
t('the figure comes from the server, not the phone clock',
  /parseInt\(node\.dataset\.startsIn, 10\)/.test(js) && !/Date\.now\(\)[\s\S]{0,80}starts_in/.test(js));

for (const k of ['starts_in', 'event_started', 'unit_day', 'unit_hour', 'unit_minute',
                 'unit_second', 'event_about', 'about_venue', 'event_desc_hint']) {
  t('i18n "' + k + '" trilingual',
    new RegExp("'" + k + "'\\s*=> array\\( 'fa' =>.*'en' =>.*'tr' =>").test(i18n));
}

/* =====================================================================
 * 5. The description has somewhere to come from
 * ================================================================== */
console.log('\n--- 5. the description is real data, not a placeholder ---');

t('a column exists', /description text NULL/.test(db));
// The description column landed in schema 1.14.0. Later releases keep
// bumping this, so assert it is at or past that point.
t('the schema is at or past the description column', (() => {
  const m = /HAVATO_DB_VERSION', '(\d+)\.(\d+)\.(\d+)'/.exec(main);
  if (!m) { return false; }
  const [, major, minor] = m.map(Number);
  return major > 1 || (major === 1 && minor >= 14);
})());
t('it is in the event payload', /'description' => isset\( \$row\['description'\] \)/.test(rest));
t('the café can write one', /name="description"/.test(owner));
t('…and it reaches the endpoint', /\$req->set_param\(\s*\n?\s*'description',/.test(owner));
t('the endpoint stores it', /'description'  => \$description,/.test(rest));
t('it is clamped like every other free field', /\$description = havato_clamp_text\([\s\S]{0,120}1000\s*\)/.test(rest));
t('the admin can edit it too', /name="description" rows="3"/.test(admin));
t('…and the admin save writes it', /'description' => isset\( \$_POST\['description'\] \) \? havato_clamp_text/.test(admin));

(() => {
  // wpdb->insert() pairs values with the format array by position, so one
  // stray entry shifts every later column onto the wrong type and fails
  // silently. Count both sides of each events insert and compare.
  function check(src, startMark, endMark, label) {
    const block = src.slice(src.indexOf(startMark), src.indexOf(endMark, src.indexOf(startMark)));
    const values = [...block.matchAll(/'(\w+)'\s*=>/g)].map(m => m[1]);
    const fmtLine = (block.match(/array\(\s*'%[sdf]'[^)]*\)/g) || []).pop() || '';
    const formats = (fmtLine.match(/%[sdf]/g) || []);
    t(label + ' (' + values.length + ' values vs ' + formats.length + ' formats)',
      values.length === formats.length && values.length > 0);
    // The two columns that would break most quietly if shifted.
    t(label + ': status is written as a string',
      formats[values.indexOf('status')] === '%s');
    t(label + ': created_at is written as a string',
      formats[values.indexOf('created_at')] === '%s');
  }

  check(rest, '$event_id = havato_uid', '// Persist the chosen furniture', 'owner_create_event insert');
  check(seeder, '$events_t,', '// Attach the café', 'seeder event insert');
})();

t('demo events no longer carry an empty title', !/'title'        => '',/.test(seeder));
t('demo events get a subject', /\$subjects\[ \( \$index \+ \$d \) % count\( \$subjects \) \]\['title'\]/.test(seeder));
t('…and a description', /\$subjects\[ \( \$index \+ \$d \) % count\( \$subjects \) \]\['desc'\]/.test(seeder));

(() => {
  // Paired by index, so the lists must be the same length or a "کتاب"
  // evening would get the film blurb.
  const sBlock = seeder.slice(seeder.indexOf('$subjects = array('));
  const subjects = (sBlock.slice(0, sBlock.indexOf('\n\t\t);')).match(/'title' =>/g) || []).length;
  const tBlock = seeder.slice(seeder.indexOf('$themes  = array('));
  const themes = (tBlock.slice(0, tBlock.indexOf(');')).match(/'/g) || []).length / 2;
  t('subjects and themes are the same length (' + subjects + ' vs ' + themes + ')', subjects === themes && subjects > 0);
})();

console.log('\n--- 6. styling ---');
t('the subject line is styled', /\.hv-event-subject \{/.test(css));
t('the countdown is styled', /\.hv-countdown \{/.test(css));
t('digits do not jitter each second', /font-variant-numeric: tabular-nums/.test(css));
t('the description keeps its line breaks', /\.hv-event-desc \{[\s\S]{0,140}white-space: pre-line/.test(css));

console.log(f ? `\n❌ ${f} failing` : '\n✅ the card names the evening and the event page reads before it books');
process.exit(f ? 1 : 0);
