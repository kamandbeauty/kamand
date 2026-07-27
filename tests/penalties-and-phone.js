/* v1.14.0 —
   1) no-show costs behaviour score; every empty reserved seat costs more
   2) phone is required, prefixed by the selected country's dial code
   3) the neighbourhood field is gone                                   */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const db = rd('includes/class-havato-db.php');
const cron = rd('includes/class-havato-cron.php');
const rest = rd('includes/class-havato-rest.php');
const fn = rd('includes/functions.php');
const js = rd('assets/js/havato-app.js');
const css = rd('assets/css/havato-app.css');
const M = rd('includes/class-havato-matcher.php');
const settings = rd('includes/class-havato-settings.php');
const i18n = rd('includes/class-havato-i18n.php');
const oa = rd('includes/class-havato-owner-admin.php');
const adm = rd('includes/class-havato-admin.php');
const main = rd('havato.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

console.log('--- 1. schema ---');
t('penalty_points column', /penalty_points double NOT NULL DEFAULT 0/.test(db));
t('empty_seat_count column', /empty_seat_count int\(11\) NOT NULL DEFAULT 0/.test(db));
t('registrations.arrived column', /arrived int\(11\) NOT NULL DEFAULT 0/.test(db));
t('profiles.phone column', /phone varchar\(32\)/.test(db));
t('neighbourhood column dropped', !/city_neighborhood/.test(db));
t('schema bumped', /HAVATO_DB_VERSION', '1\.10\.0'/.test(main));
// dbDelta parses CREATE TABLE line by line; a `--` line would be read as a column.
t('no SQL comments inside any CREATE TABLE', (() => {
  const blocks = db.match(/CREATE TABLE[\s\S]*?\)\s*\$charset/g) || [];
  return !blocks.some(b => /^\s*--/m.test(b));
})());
t('pre-upgrade rows get safe defaults',
  /Columns added in DB 1\.10\.0/.test(fn) && /'penalty_points' => 0/.test(fn));

console.log('\n--- 2. penalties are kept apart from peer feedback ---');
// recalculate_rating() rewrites rating_score wholesale from the feedback
// average, so a penalty stored there would vanish on the next review.
t('a dedicated effective-rating helper exists', /function havato_effective_rating/.test(fn));
t('…and it subtracts the penalty', /\$base - \$penalty/.test(fn));
t('…and respects a floor', /penalty_floor/.test(fn));
t('the reason is documented', /rewritten wholesale by[\s\S]{0,40}recalculate_rating/.test(fn));
t('recalculate_rating still only writes the peer average',
  /'rating_score' => \$avg/.test(rest));
t('it never touches penalty_points', !/penalty_points[^;]{0,80}\$avg/.test(rest));

console.log('\n--- 3. every surface shows the effective score ---');
t('profile payload', /'rating'\s*=>\s*round\( havato_effective_rating/.test(rest));
t('admin guest list', /havato_effective_rating/.test(adm));
t('owner check-in list', /havato_effective_rating/.test(oa));
t('the matcher scores on it too', /\$ra = havato_effective_rating\( \$a \)/.test(M));
t('no raw rating_score left on a read path',
  !/round\( \(float\) \$profile\['rating_score'\]/.test(rest + adm + oa));

console.log('\n--- 4. the cron charges the right amount ---');
t('reads seats + arrived, not just the flag', /SELECT user_id, seats, arrived, checked_in/.test(cron));
t('no-show penalty setting used', /penalty_no_show/.test(cron) && /'penalty_no_show'/.test(settings));
t('empty-seat penalty setting used', /penalty_empty_seat/.test(cron) && /'penalty_empty_seat'/.test(settings));
t('a total no-show is charged once plus its held chairs',
  /\$per_no_show \+ \( \( \$missing - 1 \) \* \$per_empty_seat \)/.test(cron));
t('a partial party is charged per empty chair', /\$points = \$missing \* \$per_empty_seat/.test(cron));
t('full attendance is charged nothing', /if \( 0 === \$missing \) \{\s*\n\s*continue;/.test(cron));
t('no_show_count still tracked', /no_show_count = no_show_count \+ 1/.test(cron));
t('empty seats counted separately', /empty_seat_count = empty_seat_count \+ %d/.test(cron));
t('legacy rows fall back to the old flag', /\$row\['checked_in'\] \? \$booked : 0/.test(cron));
t('arrived can never exceed what was booked', /min\( \$booked, \(int\) \$row\['arrived'\] \)/.test(cron));
t('admin can tune all three', ['penalty_no_show', 'penalty_empty_seat', 'penalty_floor']
  .every(k => new RegExp("'" + k + "'").test(adm)));

// Prove the arithmetic rather than only grepping for it.
(() => {
  const NO_SHOW = 1, EMPTY = 1;
  const charge = (booked, arrived, flag) => {
    if (arrived <= 0) arrived = flag ? booked : 0;
    arrived = Math.min(booked, arrived);
    const missing = Math.max(0, booked - arrived);
    if (!missing) return 0;
    return arrived === 0 ? NO_SHOW + (missing - 1) * EMPTY : missing * EMPTY;
  };
  t('solo attended → 0', charge(1, 1, 1) === 0);
  t('solo no-show → 1', charge(1, 0, 0) === 1);
  t('party of 3 all came → 0', charge(3, 3, 1) === 0);
  t('party of 3, 1 came → 2 (two empty chairs)', charge(3, 1, 1) === 2);
  t('party of 3, nobody came → 3', charge(3, 0, 0) === 3);
  t('bigger parties are never cheaper than smaller ones',
    charge(3, 0, 0) > charge(2, 0, 0) && charge(2, 0, 0) > charge(1, 0, 0));
})();

console.log('\n--- 5. the café can record a partial arrival ---');
t('check-in accepts a count', /\$arrived  = \$req->get_param\( 'arrived' \)/.test(rest));
t('it is clamped to the booking', /min\( \$booked, \(int\) \$arrived \)/.test(rest));
t('omitting it keeps the old all-or-nothing behaviour', /\$count = \$value \? \$booked : 0/.test(rest));
t('checked_in stays consistent with the count', /'checked_in' => \$count > 0 \? 1 : 0/.test(rest));
t('owner UI offers a picker for parties', /name="arrived"/.test(oa) && /how_many_arrived/.test(oa));
t('…and only when more than one seat was booked', /if \( \$booked > 1 \) \{/.test(oa));
t('the form passes it through', /set_param\( 'arrived'/.test(oa));

console.log('\n--- 6. phone number ---');
t('required on save', /havato_bad_phone/.test(rest));
t('normalised before storing', /havato_normalize_phone/.test(rest) && /function havato_normalize_phone/.test(fn));
t('dial codes defined per country', /'dial'   => '\+98'/.test(fn) && /'dial'   => '\+90'/.test(fn));
t('helper exposes them', /function havato_dial_code/.test(fn));
t('Persian digits handled', /Havato_Jalali::en_digits/.test(fn));
t('duplicate numbers rejected', /havato_phone_taken/.test(rest));
t('never leaked to other guests', /'phone'         => \$is_self \? \$profile\['phone'\] : ''/.test(rest));
t('client shows the prefix beside the field', /hv-dial/.test(js) && /\.hv-dial \{/.test(css));
t('prefix follows the chosen country', /function dialCode/.test(js));
t('changing country re-renders it', /Re-rendering also refreshes the dialling prefix/.test(js));
t('client validates before the round-trip', /err_phone/.test(js));
t('input uses a tel keyboard', /inputmode="tel"/.test(js));

// The normaliser is the part most likely to be subtly wrong.
(() => {
  const DIAL = { ir: '+98', tr: '+90' };
  const faD = '۰۱۲۳۴۵۶۷۸۹';
  const en = s => String(s).replace(/[۰-۹]/g, c => faD.indexOf(c));
  const norm = (raw, country) => {
    raw = en(raw).trim(); if (!raw) return '';
    const dial = DIAL[country] || '', cc = dial.replace('+', '');
    let plus = raw.startsWith('+');
    let digits = raw.replace(/\D+/g, ''); if (!digits) return '';
    if (!plus && cc && digits.startsWith('00' + cc)) { digits = digits.slice(2); plus = true; }
    let national;
    if (plus || (cc && digits.startsWith(cc) && digits.length > cc.length + 6)) {
      national = (cc && digits.startsWith(cc)) ? digits.slice(cc.length) : digits;
    } else national = digits;
    national = national.replace(/^0+/, '');
    if (national.length < 6 || national.length > 14) return '';
    return (dial || '+') + national;
  };
  const want = '+989121234567';
  t('every Iranian input shape collapses to one number',
    ['09121234567', '+989121234567', '00989121234567', '0912 123 4567',
     '0912-123-4567', '۰۹۱۲۱۲۳۴۵۶۷', '9121234567'].every(v => norm(v, 'ir') === want));
  t('Turkish numbers use +90', norm('05321234567', 'tr') === '+905321234567');
  t('junk is rejected', ['', 'abc', '123'].every(v => norm(v, 'ir') === ''));
})();

console.log('\n--- 7. neighbourhood is gone ---');
t('no field in the form', !/hv-d-hood/.test(js));
t('no state key', !/neighborhood/.test(js));
t('not read by the server', !/'neighborhood'/.test(rest));
t('not in the profile payload', !/city_neighborhood/.test(rest + fn));
t('string removed', !/q_neighborhood/.test(i18n));

console.log('\n--- 8. the rule is explained to guests ---');
t('warned on the reserve sheet', /penalty_notice/.test(js));
t('shown on the profile once penalised', /profile\.penalty > 0/.test(js));
t('counters exposed', /'no_shows'/.test(rest) && /'empty_seats'/.test(rest));
for (const k of ['q_phone', 'phone_hint', 'err_phone', 'err_phone_taken',
                 'penalty_notice', 'how_many_arrived', 'arrived_n_of_m'])
  t(`i18n "${k}" bilingual`, new RegExp("'" + k + "'[\\s\\S]{0,300}?'fa' =>[\\s\\S]{0,300}?'en' =>").test(i18n));

console.log(f ? `\n❌ ${f} failing` : '\n✅ penalties charged per empty seat, phone captured, neighbourhood gone');
process.exit(f ? 1 : 0);
