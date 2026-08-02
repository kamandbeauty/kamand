/* v1.11.0 —
   1) the country/city step was unusable: BOOT.locations was never sent
   2) the test is now personality-only, and longer
   3) personal details moved to a permanently editable profile form */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const js = rd('assets/js/havato-app.js');
const css = rd('assets/css/havato-app.css');
const sc = rd('includes/class-havato-shortcode.php');
const rest = rd('includes/class-havato-rest.php');
const db = rd('includes/class-havato-db.php');
const fn = rd('includes/functions.php');
const matcher = rd('includes/class-havato-matcher.php');
const settings = rd('includes/class-havato-settings.php');
const i18n = rd('includes/class-havato-i18n.php');
const main = rd('havato.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

console.log('--- 1. THE BUG: the location picker had no data ---');
// The UI reads BOOT.locations (the wp_localize_script payload) but the server
// only ever put locations in the bootstrap REST response, so the object was
// always {} and the step rendered zero buttons — the test could not be passed.
t('server now ships locations in the boot payload', /'locations'\s*=>\s*havato_locations\(\)/.test(sc));
t('the picker reads that same payload', /BOOT\.locations/.test(js));
t('bootstrap still carries it too (map/explore use it)',
  /'locations'\s*=>\s*havato_locations\(\)/.test(rest));
t('an empty list degrades to a message, not a blank gap',
  /if \(!countryBtns\)/.test(js));

console.log('\n--- 2. the test is psychometric only ---');
t('no location step left in the test', !/function stepLocation/.test(js));
t('no age step left in the test', !/function stepAge/.test(js));
t('no gender step left in the test', !/data-gender=/.test(js));
t('testData holds only traits + vibe + interests',
  /testData: \{[\s\S]{0,240}?extroversion[\s\S]{0,240}?interests: \[\]/.test(js) &&
  !/testData: \{[^}]*country/.test(js));
t('the test can always be completed (no blocking validation)',
  !/S\.testStep === 0 && \(!S\.testData\.country/.test(js));

console.log('\n--- 3. the test is longer and covers more ---');
const traits = ['extroversion', 'talkative', 'openness', 'humor', 'energy', 'planning', 'empathy'];
for (const k of traits) t(`asks about "${k}"`, new RegExp("key: '" + k + "'").test(js));
t('7 traits + vibe + interests = 9 steps', (() => {
  // Scope the count to the TEST_STEPS array; "{ key: '" also appears in the
  // budget filter and the report-reason list.
  const block = /var TEST_STEPS = \[([\s\S]*?)\n\t\];/.exec(js);
  if (!block) return false;
  const rows = (block[1].match(/\{ key: '/g) || []).length;
  return rows === 7 && /vibe: true/.test(block[1]) && /interests: true/.test(block[1]);
})());
t('progress dots follow the real step count', /var steps = TEST_STEPS\.length/.test(js));
t('server whitelists the same trait list',
  traits.every(k => new RegExp("'" + k + "'").test(rest)) && /function trait_keys/.test(rest));
t('server clamps every trait to 1..10', /max\( 1, min\( 10, \(int\) \$req->get_param\( \$key \) \) \)/.test(rest));

console.log('\n--- 4. details are separate and always editable ---');
t('a details endpoint exists', /'profile\/details'\s*=>\s*array\( 'POST', 'save_details'/.test(rest));
t('and its handler', /public static function save_details/.test(rest));
t('the button is on the profile', /hv-edit-details/.test(js));
t('it is NOT hidden once the test is done', (() => {
  // The button must sit outside any `completed` guard; only the test button
  // is allowed to disappear.
  const i = js.indexOf("hv-edit-details");
  const before = js.slice(Math.max(0, i - 700), i);
  return i !== -1 && !/if \(!?profile\.completed\)[^]*$/.test(before);
})());
t('the editor pre-fills from the current profile', /function openDetails/.test(js));
t('name is editable', /q_name/.test(js) && /hv-d-name/.test(js));
t('age is editable', /hv-d-age/.test(js));
t('country/city are editable', /data-dcountry=/.test(js) && /data-dcity=/.test(js));
t('saving a name updates the WP display_name', /wp_update_user/.test(rest));
t('name length validated server-side', /havato_bad_name/.test(rest));
t('age range validated server-side', /havato_bad_age/.test(rest));
t('city pair validated server-side', /havato_valid_city\( \$country, \$city \)/.test(rest));
t('details do NOT mark the personality test complete',
  /\$data\['completed'\]\s*=\s*0;/.test(rest));
t('users missing a city are prompted', /details_needed/.test(js) && /details_needed/.test(i18n));

console.log('\n--- 5. schema + safe upgrade ---');
for (const k of ['openness', 'humor', 'energy', 'planning', 'empathy'])
  t(`column personality_${k}`, new RegExp('personality_' + k + ' int\\(11\\)').test(db));
t('DB version is at or past the trait schema', (() => {
  const m = /HAVATO_DB_VERSION', '(\d+)\.(\d+)\.(\d+)'/.exec(main);
  if (!m) return false;
  const [maj, min] = [Number(m[1]), Number(m[2])];
  return maj > 1 || (maj === 1 && min >= 7);
})());
// A row written before the upgrade has no such key. Reading it as 0 would make
// the matcher treat everyone as an extreme introvert, so it must default to 5.
t('pre-upgrade rows read as the neutral midpoint 5',
  /Traits added in DB 1\.7\.0/.test(fn) && /\$row\[ \$havato_key \] = 5;/.test(fn));
t('new columns default to 5 in SQL too',
  (db.match(/personality_(openness|humor|energy|planning|empathy) int\(11\) NOT NULL DEFAULT 5/g) || []).length === 5);

console.log('\n--- 6. the richer test actually feeds the matcher ---');
t('humour similarity scored', /personality_humor/.test(matcher));
t('energy similarity scored', /personality_energy/.test(matcher));
t('empathy rewarded', /personality_empathy/.test(matcher));
t('weights are real settings, not undefined lookups',
  ['w_trait_humor', 'w_trait_energy', 'w_trait_empathy'].every(k => new RegExp("'" + k + "'").test(settings)));
t('missing traits fall back to 5 in the matcher', /: 5;/.test(matcher));
t('the new terms respect relaxed mode', /\$score\s*\+=\s*\$closeness \* \$weight \* \$softness/.test(matcher));

// The extra terms must refine, not dominate: bounded well under the 100 base.
(() => {
  const W = { humor: 6, energy: 6, empathy: 5 };
  const d = (a, b) => {
    let x = 0;
    for (const k of ['humor', 'energy']) x += (1 - Math.abs(a[k] - b[k]) / 9 * 2) * W[k];
    if (Math.max(a.empathy, b.empathy) >= 7) x += W.empathy;
    return x;
  };
  const best = d({ humor: 5, energy: 5, empathy: 9 }, { humor: 5, energy: 5, empathy: 9 });
  const worst = d({ humor: 1, energy: 1, empathy: 1 }, { humor: 10, energy: 10, empathy: 1 });
  t(`trait swing ${worst.toFixed(0)}..+${best.toFixed(0)} stays secondary to the 100 base`,
    best <= 25 && worst >= -25);
})();

console.log('\n--- 7. presentation + i18n ---');

/* The personality RESULT is deliberately not shown to anyone.
   It used to render as an "introvert 4/10" chip plus five trait bars, on the
   viewer's own profile AND on other people's. The scores exist to feed the
   matcher, which runs server-side; publishing them turns a matching input
   into a verdict the guest reads about themselves, and hands out a
   psychological read of a stranger. These assertions replace the old ones,
   which asserted the bars were present. */
t('trait bars are gone from the markup', !/hv-trait-bar/.test(js));
t('trait bar CSS removed too (no dead rules)', !/hv-trait-bar/.test(css));
t('no introvert/extrovert label on the profile',
  !/t\('introvert'\)/.test(js) && !/t\('extrovert'\)/.test(js));
t('no speaker/listener label on the profile',
  !/t\('speaker'\)/.test(js) && !/t\('listener'\)/.test(js));
t('the "behaviour profile" card is gone', !/t\('behaviour_id'\)/.test(js));
t('the card is now titled by what it shows', /t\('interests_title'\)/.test(js));

// The scores must not even reach the client for someone else's profile —
// hiding them in the markup alone would still leak them over the network.
{
  const selfBlock = /if \( \$is_self \) \{([\s\S]*?)\n\t\t\}/.exec(rest);
  t('scores are attached only inside an is_self branch', !!selfBlock);
  for (const k of ['extroversion', 'talkative', 'openness', 'humor',
                   'energy', 'planning', 'empathy', 'vibe']) {
    t(`  ${k} sent only to its owner`,
      !!selfBlock && new RegExp("\\$data\\['" + k + "'\\]").test(selfBlock[1]));
    // ...and NOT in the unconditional payload.
    const unconditional = rest.slice(rest.indexOf("$data = array("), rest.indexOf("if ( $is_self )"));
    t(`  ${k} absent from the public payload`,
      !new RegExp("'" + k + "'\\s*=>").test(unconditional));
  }
}

// The owner still needs them, or "edit" would reset every answer to 5.
t('the edit button re-reads the stored answers', /extroversion: p\.extroversion \|\| 5/.test(js));

t('city shown on the profile card', /profile\.city_label/.test(js));
t('interests still shown', /profile\.interests/.test(js));
for (const k of ['q_openness', 'q_humor', 'q_energy', 'q_planning', 'q_empathy',
                 'edit_details', 'details_title', 'q_name', 'details_saved',
                 'err_name_short', 'err_age_range', 'test_intro_body'])
  t(`i18n "${k}" bilingual`, new RegExp("'" + k + "'[\\s\\S]{0,260}?'fa' =>[\\s\\S]{0,260}?'en' =>").test(i18n));

console.log(f ? `\n❌ ${f} failing` : '\n✅ location picker fixed, test is personality-only, details editable');
process.exit(f ? 1 : 0);
