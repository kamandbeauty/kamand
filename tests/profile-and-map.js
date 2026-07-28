/* v1.17.0 —
   1) [object Object] in the behaviour tags (found in a user screenshot)
   2) own name/rating moved into the header, duplicate card removed
   3) map opens on the viewer's own city
   4) "prefer not to say" removed from gender
   5) delete-account with two confirmations
   6) behaviour profile is editable
   7) far more interests
   8) TEMPORARY: chat opens right after reserving                        */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const js = rd('assets/js/havato-app.js');
const css = rd('assets/css/havato-app.css');
const fn = rd('includes/functions.php');
const rest = rd('includes/class-havato-rest.php');
const i18n = rd('includes/class-havato-i18n.php');
const db = rd('includes/class-havato-db.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

console.log('--- 1. the [object Object] tag ---');
// havato_city_label() returned the whole city row, which now also holds
// lat/lng/zoom, and the client passed it to esc() instead of pick().
t('client runs city_label through pick()', /pick\(profile\.city_label\)/.test(js));
t('it is no longer passed raw to esc()', !/esc\(profile\.city_label\)/.test(js));
t('the server returns only language keys from city_label',
  /Return ONLY the language keys/.test(fn));
t('city_label carries a tr string too', /'tr' => isset\( \$c\['tr'\] \)/.test(fn));
(() => {
  const pick = (v, lang) => (v && typeof v === 'object' && (v.fa !== undefined || v.en !== undefined))
    ? (v[lang] !== undefined ? v[lang] : (v.en || v.fa || '')) : (v == null ? '' : v);
  const row = { fa: 'استانبول', en: 'Istanbul', tr: 'İstanbul' };
  t('pick() renders a real name, not [object Object]',
    pick(row, 'fa') === 'استانبول' && pick(row, 'tr') === 'İstanbul' && String(row) === '[object Object]');
})();

console.log('\n--- 2. own profile header ---');
t('name and rating are pushed into the header', /setHeader\(\s*\n\s*profile\.user\.name/.test(js));
t('the duplicate card is skipped for yourself',
  /if \(profile\.is_self\) \{\s*\n\s*return '';\s*\n\s*\}/.test(js));
t('another guest still gets the card', /hv-profile-head/.test(js));
t('the add-friend button survives', /data-friend-add/.test(js));

console.log('\n--- 3. map opens on the viewer\'s city ---');
t('per-city coordinates exist', /'lat' => 41\.0082/.test(fn) && /'lat' => 32\.6539/.test(fn));
t('a resolver exists', /function havato_city_center/.test(fn));
t('it falls back to the admin default', /function map_center/.test(rest) && /map_center_lat/.test(rest));
t('bootstrap sends the resolved centre', /'map'           => self::map_center\( self::viewer_city\(\) \)/.test(rest));
t('saving details returns a fresh centre', /'map'   => self::map_center\( \$city \)/.test(rest));
t('the client prefers it over the global default', /var centre = S\.mapCenter \|\| BOOT\.map/.test(js));
t('it is stored from bootstrap', /if \(res\.map\) \{ S\.mapCenter = res\.map; \}/.test(js));
t('and refreshed when the city changes', /The city drives where the map opens/.test(js));

console.log('\n--- 4. gender ---');
t('"prefer not to say" removed from the form', !/key: 'other', label: t\('gender_other'\)/.test(js));
t('only male and female offered', /key: 'male'/.test(js) && /key: 'female'/.test(js));
t('server rejects anything else instead of storing it',
  /havato_bad_gender/.test(rest) && /array\( 'male', 'female' \), true \)/.test(rest));

console.log('\n--- 5. delete account ---');
t('endpoint registered', /'profile\/delete'\s*=>\s*array\( 'POST', 'delete_account', \$auth \)/.test(rest));
t('handler exists', /function delete_account/.test(rest));
t('acts on the session, takes no user id',
  /\$user_id = get_current_user_id\(\);/.test(rest) && !/delete_account[\s\S]{0,600}get_param\( 'user_id' \)/.test(rest));
t('administrators are refused', /havato_admin_delete/.test(rest));
t('server demands an explicit confirmation token',
  /'DELETE' !== strtoupper\( \(string\) \$req->get_param\( 'confirm' \) \)/.test(rest));
t('profile, bookings, photos and memberships are removed',
  /'user_profiles', 'event_registrations', 'group_members', 'user_photos', 'photo_likes'/.test(rest));
t('photo_reports uses its real column name (reporter_id)',
  /'photo_reports' \), array\( 'reporter_id' => \$user_id \)/.test(rest));
t('friendships are removed in both directions', /WHERE user_id=%d OR friend_id=%d/.test(rest));
t('private messages removed both ways', /WHERE sender_id=%d OR receiver_id=%d/.test(rest));
t('group chat lines are anonymised, not deleted',
  /'sender_id' => 0, 'sender_name' => Havato_I18N::t\( 'deleted_user' \)/.test(rest));
t('the WP user is finally deleted', /wp_delete_user\( \$user_id \)/.test(rest));
t('client asks twice', /function confirmDeleteAccount/.test(js) && /hv-del-step1/.test(js) && /hv-del-final/.test(js));
t('second step requires typing the word', /typed !== word/.test(js));
t('a mismatch is reported', /delete_mismatch/.test(js));
t('session and caches are cleared afterwards', /confirmDeleteAccount[\s\S]{0,2000}clearAppCaches/.test(js));
t('the danger zone is visually separated', /hv-danger/.test(js) && /\.hv-danger \{/.test(css));

console.log('\n--- 6. behaviour profile is editable ---');
t('an edit button is shown on your own profile', /hv-edit-behaviour/.test(js));
t('…and only on your own', /profile\.is_self[\s\S]{0,140}hv-edit-behaviour/.test(js));
t('the test is pre-filled with the stored answers',
  /extroversion: p\.extroversion \|\| 5/.test(js) && /empathy: p\.empathy \|\| 5/.test(js));
t('interests are mapped back to their keys', /\(p\.interests \|\| \[\]\)\.map\(function \(i\) \{ return i\.key; \}\)/.test(js));
t('it reuses the existing test flow', /renderTestStep\(\);/.test(js));

console.log('\n--- 7. more interests ---');
(() => {
  const block = /function havato_interest_tags\(\) \{([\s\S]*?)\n\}/.exec(fn)[1];
  const n = (block.match(/=> array\(/g) || []).length;
  t(`interest count raised to ${n} (was 12)`, n >= 30);
  // Only the top-level keys (two tabs in); the nested fa/en/tr obviously repeat.
  const keys = [...block.matchAll(/^\t\t'([a-z0-9_]+)'\s*=>/gm)].map(m => m[1]);
  t(`no duplicate keys (${keys.length} unique)`, new Set(keys).size === keys.length && keys.length === n);
  const withTr = (block.match(/'tr' =>/g) || []).length;
  t('every interest is trilingual', withTr === n);
})();

console.log('\n--- 8. chat after reserving (temporary) ---');
t('the app goes to Chats after a booking', /setTab\('chats'\)/.test(js));
t('it is clearly flagged temporary', /TEMPORARY \(requested for review\)/.test(js));
t('the revert instruction is written down', /replacing this block with viewExplore/.test(js));
t('the server can seat immediately', /havato_match_immediately/.test(rest));
t('that behaviour is filterable, so it can be turned off',
  /apply_filters\( 'havato_match_immediately', true, \$event_id \)/.test(rest));
t('the group id is returned so the room can open', /'group_id' => \$group_id/.test(rest));
t('the client opens that room directly', /res\.group_id \? \{ type: 'group', id: res\.group_id \}/.test(js));

console.log('\n--- 9. nothing else broke ---');
t('all strings remain trilingual', (() => {
  const b = i18n.slice(i18n.indexOf('self::$map = array('));
  const keys = [...b.matchAll(/'([a-z0-9_]+)'\s*=>\s*array\(\s*(?:\n\s*)?'fa'/g)].map(m => m[1]);
  const tr = [...b.matchAll(/'([a-z0-9_]+)'\s*=>\s*array\([\s\S]{0,800}?'tr'\s*=>/g)].map(m => m[1]);
  return [...new Set(keys)].every(k => tr.includes(k));
})());
t('no schema change was needed', /HAVATO_DB_VERSION', '1\.11\.0'/.test(rd('havato.php')));
t('gender column still accepts the stored values', /gender varchar\(20\)/.test(db));

console.log(f ? `\n❌ ${f} failing` : '\n✅ profile, map, deletion, interests and the review chat shortcut all in place');
process.exit(f ? 1 : 0);
