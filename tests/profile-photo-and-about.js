/* v1.34.0 — two reports:

   1) the event page should carry written descriptions of BOTH the gathering
      and the café, not just the gathering
   2) the profile photo could not be changed from anywhere in the app

   (2) turned out to be an orphaned handler: the upload code has been there
   since the beginning, but the button it binds to was lost when the profile
   header was consolidated in 1.17.0. That class of bug — live code with no
   way to reach it — is what the wiring assertions below are for.          */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const js = rd('assets/js/havato-app.js');
const css = rd('assets/css/havato-app.css');
const rest = rd('includes/class-havato-rest.php');
const db = rd('includes/class-havato-db.php');
const owner = rd('includes/class-havato-owner-admin.php');
const i18n = rd('includes/class-havato-i18n.php');
const main = rd('havato.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

/* =====================================================================
 * 1. The profile photo can actually be changed
 * ================================================================== */
console.log('--- 1. changing the profile photo ---');

t('an upload button is rendered', /id="hv-avatar-upload"/.test(js));
t('the handler binds to it', /\$\('#hv-avatar-upload'\)/.test(js));

(() => {
  // The bug: the handler existed and the element did not, so the code was
  // unreachable. Count both sides — one occurrence means it is orphaned again.
  const refs = (js.match(/hv-avatar-upload/g) || []).length;
  t('button and handler both present (' + refs + ' references)', refs >= 2);
})();

(() => {
  // The card is emitted inside the `if (profile.is_self)` branch, so a guest
  // viewing someone else never sees a button to change that person's photo.
  const at = js.indexOf('hv-avatar-upload');
  const before = js.slice(Math.max(0, at - 1400), at);
  const lastSelf = before.lastIndexOf('if (profile.is_self)');
  const lastNotSelf = before.lastIndexOf('if (!profile.is_self)');
  t('it only appears on your own profile', lastSelf > lastNotSelf);
})();
t('it opens a file picker', /pickFile\(function \(file\)/.test(js));
t('…restricted to images', /input\.accept = 'image\/\*'/.test(js));
t('it posts to the avatar endpoint', /uploadWithProgress\('profile\/avatar', file/.test(js));
t('the endpoint exists and is authenticated',
  /'profile\/avatar'     => array\( 'POST', 'upload_avatar', \$auth \)/.test(rest));
t('the profile reloads afterwards, so the new photo shows',
  /uploadWithProgress\('profile\/avatar'[\s\S]{0,160}viewProfile\(\)/.test(js));
t('a failure is reported rather than silent', /\.catch\(function \(err\) \{ uploadFailed\(err\); \}\)/.test(js));

t('the current photo is previewed', /hv-avatar-preview/.test(js));
t('…with initials when there is none yet', /hv-avatar-fallback[\s\S]{0,80}initials\(/.test(js));
t('the card is styled', /\.hv-avatar-card \{/.test(css));
t('the preview is a circle', /\.hv-avatar-preview \{[\s\S]{0,300}border-radius: 50%/.test(css));

for (const k of ['profile_photo', 'profile_photo_hint', 'change_photo']) {
  t('i18n "' + k + '" trilingual',
    new RegExp("'" + k + "'\\s*=> array\\( 'fa' =>.*'en' =>.*'tr' =>").test(i18n));
}

/* =====================================================================
 * 2. Both descriptions on the event page
 * ================================================================== */
console.log('\n--- 2. the gathering and the café both describe themselves ---');

t('the gathering description is shown', /event\.description[\s\S]{0,140}hv-event-desc/.test(js));
t('the café description is shown too', /venue\.description[\s\S]{0,120}hv-event-desc/.test(js));
t('…under the café heading, before the address',
  /about_venue[\s\S]{0,200}venue\.description[\s\S]{0,200}hv-venue-block/.test(js));
t('each is omitted when empty rather than leaving a heading over nothing',
  /\(event\.description\s*\n?\s*\?/.test(js) && /\(venue\.description\s*\n?\s*\?/.test(js));

console.log('\n--- 3. the café has somewhere to write it ---');

t('a column exists', /CREATE TABLE \{\$p\}venues[\s\S]{0,600}description text NULL/.test(db));
t('the schema was bumped', /HAVATO_DB_VERSION', '1\.16\.0'/.test(main));
t('the venue payload carries it', /'description'   => isset\( \$row\['description'\] \)/.test(rest));
(() => {
  // It must sit in the shared part of venue_payload(), not behind $private,
  // or a guest would never see it.
  const body = rest.slice(rest.indexOf('private static function venue_payload'));
  const fn = body.slice(0, body.indexOf('\n\t}'));
  t('it is public, not owner-only',
    fn.indexOf("'description'") !== -1 &&
    fn.indexOf("'description'") < fn.indexOf('if ( $private )'));
})();

t('the café can write one', /name="description" rows="4"/.test(owner));
t('…with a hint about who reads it', /venue_about_hint/.test(owner));
t('the form field reaches the endpoint',
  /foreach \( array\( 'address', 'description' \) as \$key \)/.test(owner));
t('the endpoint accepts the field', /'description' => '%s',/.test(rest));
t('…and clamps it like every other free text',
  /'description' === \$key[\s\S]{0,200}havato_clamp_text[\s\S]{0,60}1000/.test(rest));

for (const k of ['venue_about', 'venue_about_hint']) {
  t('i18n "' + k + '" trilingual',
    new RegExp("'" + k + "'\\s*=> array\\( 'fa' =>.*'en' =>.*'tr' =>").test(i18n));
}

(() => {
  // Two different descriptions now exist. Confusing them would show the
  // café blurb as the evening's plan, so check they stay distinct.
  const eventDesc = /'description' => isset\( \$row\['description'\] \) \? \(string\) \$row\['description'\] : ''/.test(rest);
  const venueDesc = /'description'   => isset\( \$row\['description'\] \) \? \(string\) \$row\['description'\] : ''/.test(rest);
  t('the event payload has its own description field', eventDesc);
  t('the venue payload has its own', venueDesc);
  t('they are read from different rows on the client',
    /event\.description/.test(js) && /venue\.description/.test(js));
})();

console.log(f ? `\n❌ ${f} failing` : '\n✅ photo changeable, both descriptions shown and editable');
process.exit(f ? 1 : 0);
