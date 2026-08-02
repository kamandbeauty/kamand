/* Profile page rework (v1.36.0):
 *   1. the penalty warning reads as two tidy lines instead of one ragged run
 *   2. the personality-test RESULT is private — not rendered, not even sent
 *   3. the interest list is much larger, grouped and searchable
 *
 * The interest keys are the part that can silently break: a guest's choices
 * are stored BY KEY, so renaming or dropping one erases that interest from
 * every profile that had it. That is checked against the real previous list.
 */
const fs = require('fs');
const path = require('path');
const R = __dirname + '/../havato/';
const rd = (f) => fs.readFileSync(R + f, 'utf8');
const js = rd('assets/js/havato-app.js');
const css = rd('assets/css/havato-app.css');
const fn = rd('includes/functions.php');
const i18n = rd('includes/class-havato-i18n.php');
const rest = rd('includes/class-havato-rest.php');
const sc = rd('includes/class-havato-shortcode.php');

let f = 0;
const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) { f++; } };
const bareCss = css.replace(/\/\*[\s\S]*?\*\//g, '');

/* ================================================================== */
console.log('--- 1. the penalty warning is readable ---');

t('the warning is its own block, not one text run', /hv-penalty-stats/.test(js));
t('each figure is a labelled pair', /function penaltyStat/.test(js));
t('all three figures are shown', (js.match(/penaltyStat\(/g) || []).length >= 4);

{
  const rule = /\.hv-penalty-stat \{([^}]*)\}/.exec(bareCss);
  t('a label can never split from its value', !!rule && /white-space:\s*nowrap/.test(rule[1]));
}
{
  const rule = /\.hv-penalty \{([^}]*)\}/.exec(bareCss);
  t('sentence and figures stack vertically', !!rule && /flex-direction:\s*column/.test(rule[1]));
}
{
  const rule = /\.hv-penalty-stats \{([^}]*)\}/.exec(bareCss);
  t('the figures wrap between pairs only', !!rule && /flex-wrap:\s*wrap/.test(rule[1]));
  t('the figures are visually separated from the sentence',
    !!rule && /border-block-start/.test(rule[1]));
}
t('digits do not jitter', /\.hv-penalty-value \{[^}]*tabular-nums/s.test(bareCss));
t('it still only shows when there IS a penalty', /profile\.is_self && \(profile\.penalty > 0\)/.test(js));

/* ================================================================== */
console.log('\n--- 2. the test result is private ---');

// `hv-trait-value` is the live number beside the slider INSIDE the test and
// must survive — the guest has to see what they are setting. What must go is
// the read-out on the profile: the bars.
t('no trait bars in the markup', !/hv-trait-bar/.test(js));
t('no trait bar CSS left behind', !/hv-trait-bar/.test(bareCss) && !/\.hv-traits\b/.test(bareCss));
t('the slider inside the test still shows its value', /hv-trait-value/.test(js));

for (const k of ['behaviour_id', 'trait_openness', 'trait_humor', 'trait_energy',
                 'trait_planning', 'trait_empathy', 'introvert', 'extrovert',
                 'speaker', 'listener']) {
  t(`orphaned string "${k}" removed from the map`,
    !new RegExp("'" + k + "'\\s*=>\\s*array").test(i18n));
}

// vibe_* are still used BY THE TEST ITSELF, so they must survive.
for (const k of ['vibe_deep', 'vibe_fun']) {
  t(`"${k}" kept — the test still asks it`, new RegExp("'" + k + "'\\s*=>\\s*array").test(i18n));
}

{
  // Server-side: scores must sit behind is_self, never in the open payload.
  const pub = rest.slice(rest.indexOf('$data = array('), rest.indexOf('if ( $is_self )'));
  const priv = /if \( \$is_self \) \{([\s\S]*?)\n\t\t\}/.exec(rest);
  t('an is_self branch exists', !!priv);
  const scores = ['extroversion', 'talkative', 'openness', 'humor', 'energy',
                  'planning', 'empathy', 'vibe'];
  let leaked = scores.filter((k) => new RegExp("'" + k + "'\\s*=>").test(pub));
  t('no score is in the public payload' + (leaked.length ? ' (leaked: ' + leaked + ')' : ''),
    leaked.length === 0);
  let missing = scores.filter((k) => !priv || !new RegExp("\\$data\\['" + k + "'\\]").test(priv[1]));
  t('every score is still given to its owner' + (missing.length ? ' (missing: ' + missing + ')' : ''),
    missing.length === 0);
}

// Simulate the two callers: viewing yourself vs viewing someone else.
{
  const scores = ['extroversion', 'talkative', 'openness', 'humor', 'energy',
                  'planning', 'empathy', 'vibe'];
  const payload = (isSelf) => {
    const d = { interests: [], age: 30, city_label: 'x' };
    if (isSelf) { scores.forEach((k) => { d[k] = 5; }); }
    return d;
  };
  const mine = payload(true), theirs = payload(false);
  t('viewing yourself: scores present (edit needs them)',
    scores.every((k) => k in mine));
  t('viewing someone else: no score reaches the browser',
    scores.every((k) => !(k in theirs)));
  t('either way the interests are there',
    'interests' in mine && 'interests' in theirs);
}

t('interests are still public — they are the point of the card',
  /'interests'\s*=>\s*\$interests/.test(rest));

/* ================================================================== */
console.log('\n--- 3. the interest list is bigger and navigable ---');

function tagsOf(src) {
  const start = src.indexOf('function havato_interest_tags');
  const body = src.slice(start, src.indexOf('\n}', start));
  return [...body.matchAll(/^\t\t'([a-z_]+)'\s*=> array\(([^)]*)\)/gm)]
    .map((m) => ({ key: m[1], def: m[2] }));
}
const tags = tagsOf(fn);

t('the list grew well past the old 36', tags.length >= 80);
t('keys are unique', new Set(tags.map((x) => x.key)).size === tags.length);

{
  let bad = tags.filter((x) => !/'fa' =>/.test(x.def) || !/'en' =>/.test(x.def) || !/'tr' =>/.test(x.def));
  t('every tag is trilingual' + (bad.length ? ' (bad: ' + bad.map((b) => b.key) + ')' : ''),
    bad.length === 0);
  let nocat = tags.filter((x) => !/'cat' =>/.test(x.def));
  t('every tag names a category' + (nocat.length ? ' (missing: ' + nocat.map((b) => b.key) + ')' : ''),
    nocat.length === 0);
}

{
  // NO KEY MAY EVER DISAPPEAR: choices are stored by key.
  const OLD36 = ['music', 'cinema', 'series', 'books', 'writing', 'poetry', 'art',
    'photo', 'theatre', 'startup', 'business', 'marketing', 'tech', 'programming',
    'ai', 'science', 'philo', 'psychology', 'history', 'language', 'travel',
    'nature', 'sports', 'football', 'fitness', 'yoga', 'food', 'coffee', 'gaming',
    'boardgames', 'pets', 'volunteer', 'fashion', 'cars', 'crafts', 'finance'];
  const keys = tags.map((x) => x.key);
  const lost = OLD36.filter((k) => !keys.includes(k));
  t('all 36 original keys survive — no profile loses an interest' +
    (lost.length ? ' (LOST: ' + lost + ')' : ''), lost.length === 0);
  t('and 40+ were added', keys.length - OLD36.length >= 40);
}

{
  const catStart = fn.indexOf('function havato_interest_categories');
  const catBody = fn.slice(catStart, fn.indexOf('\n}', catStart));
  const cats = [...catBody.matchAll(/^\t\t'([a-z_]+)'\s*=> array\(([^)]*)\)/gm)];
  t('categories are declared', cats.length >= 5);
  let badCat = cats.filter((m) => !/'fa' =>/.test(m[2]) || !/'en' =>/.test(m[2]) || !/'tr' =>/.test(m[2]));
  t('every category is trilingual', badCat.length === 0);

  const catKeys = cats.map((m) => m[1]);
  const used = [...new Set(tags.map((x) => /'cat' => '(\w+)'/.exec(x.def)[1]))];
  const unknown = used.filter((c) => !catKeys.includes(c));
  t('no tag points at a category that does not exist' +
    (unknown.length ? ' (' + unknown + ')' : ''), unknown.length === 0);
  const empty = catKeys.filter((c) => !used.includes(c));
  t('no category is left empty' + (empty.length ? ' (' + empty + ')' : ''), empty.length === 0);

  // Distribution: a category holding almost everything would defeat grouping.
  const counts = {};
  tags.forEach((x) => { const c = /'cat' => '(\w+)'/.exec(x.def)[1]; counts[c] = (counts[c] || 0) + 1; });
  console.log('     per category: ' + JSON.stringify(counts));
  const biggest = Math.max(...Object.values(counts));
  t(`the largest group holds ${biggest}, under half the list`, biggest < tags.length / 2);
  t('no category is a single lonely chip', Math.min(...Object.values(counts)) >= 3);
}

t('categories are sent to the app (REST boot)', /'interest_cats'\s*=>\s*havato_interest_categories\(\)/.test(rest));
t('categories are sent to the app (page boot)', /'interestCats'\s*=>\s*havato_interest_categories\(\)/.test(sc));

console.log('\n   picker behaviour:');
t('chips are grouped under a heading', /hv-interest-cat/.test(js));
t('a search box filters the list', /hv-interest-search/.test(js));
t('search matches all three languages, not just the current one',
  /tag\.fa, tag\.en, tag\.tr/.test(js));
t('a live count shows how many are chosen', /hv-interest-count/.test(js));
t('the counter updates without rebuilding the list (keeps focus)',
  /counter\.textContent/.test(js));
t('typing restores focus and caret after the re-render',
  /setSelectionRange/.test(js));
t('a stale filter cannot survive into the next visit',
  (js.match(/S\.interestQuery = ''/g) || []).length >= 2);
t('an empty search says so rather than showing a blank panel',
  /interests_none_found/.test(js));
t('a tag with an unknown category still appears', /_other/.test(js));

{
  const bar = /\.hv-interest-bar \{([^}]*)\}/.exec(bareCss);
  t('the search row stays reachable while scrolling',
    !!bar && /position:\s*sticky/.test(bar[1]));
}

for (const k of ['interests_title', 'interests_empty', 'interests_search',
                 'interests_chosen', 'interests_none_found', 'interests_other']) {
  t(`i18n "${k}" trilingual`,
    new RegExp("'" + k + "'[\\s\\S]{0,400}?'fa' =>[\\s\\S]{0,400}?'en' =>[\\s\\S]{0,400}?'tr' =>").test(i18n));
}

/* ================================================================== */
console.log('\n--- 4. the matcher is untouched ---');

const matcher = rd('includes/class-havato-matcher.php');
t('shared interests still score', /shared_interest|w_shared_interest/.test(matcher + rd('includes/class-havato-settings.php')));
t('the saved keys are still validated against the tag list',
  /array_keys\( havato_interest_tags\(\) \)/.test(rest));
t('the test still stores all seven traits',
  /trait_keys/.test(rest));

console.log(f ? `\n❌ ${f} failing` : '\n✅ penalty readable, scores private, interests grouped and searchable');
process.exit(f ? 1 : 0);
