/* v1.15.0 —
   1) Raspberry theme (from the food-delivery reference)
   2) Turkish as a third language, default for guests who pick Turkey
   3) café contact number, administrator-only
   4) map list: café name and city no longer collide                  */
const fs = require('fs');
const R = __dirname + '/../havato/';
const rd = f => fs.readFileSync(R + f, 'utf8');
const i18n = rd('includes/class-havato-i18n.php');
const themes = rd('includes/class-havato-themes.php');
const js = rd('assets/js/havato-app.js');
const css = rd('assets/css/havato-app.css');
const rest = rd('includes/class-havato-rest.php');
const db = rd('includes/class-havato-db.php');
const oa = rd('includes/class-havato-owner-admin.php');
const adm = rd('includes/class-havato-admin.php');
const fn = rd('includes/functions.php');
let f = 0; const t = (n, c) => { console.log((c ? '✓ ' : '❌ ') + n); if (!c) f++; };

const srgb = c => { c /= 255; return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); };
const lum = h => 0.2126 * srgb(parseInt(h.slice(1, 3), 16)) + 0.7152 * srgb(parseInt(h.slice(3, 5), 16)) + 0.0722 * srgb(parseInt(h.slice(5, 7), 16));
const cr = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };

console.log('--- 1. Raspberry theme ---');
t('registered', /'raspberry' => array\(/.test(themes));
const rasp = (() => {
  const i = themes.indexOf("'raspberry' => array(");
  const body = themes.slice(i, i + 1400);
  const g = k => (new RegExp("'" + k + "'\\s*=>\\s*'(#[0-9a-fA-F]{6})'").exec(body) || [])[1];
  return { light: g('light'), base: g('base'), deep: g('deep'), ink: g('ink'), accent: g('accent'), canvas: g('canvas'), text: g('text') };
})();
t('all colours parsed', Object.values(rasp).every(v => /^#[0-9a-f]{6}$/i.test(v || '')));
t(`white on base = ${cr('#ffffff', rasp.base).toFixed(2)}:1 (AA)`, cr('#ffffff', rasp.base) >= 4.5);
t('body text on canvas is AA', cr(rasp.text, rasp.canvas) >= 4.5);
t('ramp descends', lum(rasp.light) > lum(rasp.base) && lum(rasp.base) > lum(rasp.deep) && lum(rasp.deep) > lum(rasp.ink));
// The reference pink (#f0186e) is only 4.15:1 on white, so it may light the
// gradient but must not be the colour that carries white body text.
t('the vivid pink is kept as the highlight', rasp.light.toLowerCase() === '#f0186e');
t('…but is not the AA-critical base', rasp.base.toLowerCase() !== '#f0186e');
t('violet accent, as in the reference', /'accent'     => '#5b4bd6'/.test(themes));
t('label is trilingual', /'raspberry'[\s\S]{0,300}'tr' =>/.test(themes));

console.log('\n--- 2. Turkish ---');
t('registered as a language', /'tr' => array\(\s*\n\s*'label' => 'Türkçe'/.test(i18n));
t('LTR', /'label' => 'Türkçe',\s*\n\s*'dir'   => 'ltr'/.test(i18n));
t('sanitizer accepts it', /0 === strpos\( \$lang, 'tr' \)/.test(i18n));
t('bundle is generated from the registry, not hard-coded',
  /foreach \( array_keys\( self::languages\(\) \) as \$code \)/.test(i18n) &&
  !/'fa' => self::flat\( 'fa' \),\s*\n\s*'en' => self::flat\( 'en' \),/.test(i18n));

// Every key must carry a tr string, or the UI silently falls back to English.
(() => {
  const start = i18n.indexOf('self::$map = array(');
  const body = i18n.slice(start);
  const keys = [...body.matchAll(/'([a-z0-9_]+)'\s*=>\s*array\(\s*(?:\n\s*)?'fa'/g)].map(m => m[1]);
  const withTr = [...body.matchAll(/'([a-z0-9_]+)'\s*=>\s*array\([\s\S]{0,700}?'tr'\s*=>/g)].map(m => m[1]);
  const missing = [...new Set(keys)].filter(k => !withTr.includes(k));
  t(`all ${new Set(keys).size} keys translated (missing: ${missing.length})`, missing.length === 0);
  const dupes = keys.filter((k, i) => keys.indexOf(k) !== i);
  t('no duplicate keys', dupes.length === 0);
})();

console.log('\n--- 3. Turkey defaults to Turkish ---');
t('a country→language map exists', /function country_language/.test(i18n));
t('tr maps to Turkish', /'tr' => 'tr'/.test(i18n));
t('ir maps to Persian', /'ir' => 'fa'/.test(i18n));
t('extensible by filter', /apply_filters\(\s*\n?\s*'havato_country_languages'/.test(i18n));
// An explicit choice must always win, or switching language would not stick.
t('an explicit preference still wins', (() => {
  // The stored preference must be returned BEFORE the country fallback runs.
  const meta = i18n.indexOf("$meta = get_user_meta( $user_id, 'havato_lang', true )");
  const ret = i18n.indexOf('return self::sanitize_lang( $meta )', meta);
  const cty = i18n.indexOf('$by_country = self::country_language', meta);
  return meta !== -1 && ret !== -1 && cty !== -1 && ret < cty;
})());
t('applied when details are first saved',
  /if \( ! get_user_meta\( \$user_id, 'havato_lang', true \) \)[\s\S]{0,260}country_language/.test(rest));
// current_lang() can be reached from inside a profile read.
t('guarded against recursion', /static \$busy = false;/.test(i18n));
t('the panel switches immediately', /res\.lang && res\.lang !== S\.lang/.test(js));
t('client cycles all three languages', /var LANGS = \[/.test(js) && /code: 'tr'/.test(js));
t('the button shows the language it switches TO', /function nextLang/.test(js));
t('direction comes from the table, not a fa/en guess',
  !/S\.lang === 'fa' \? 'EN' : 'فا'/.test(js) && /info\.dir/.test(js));

console.log('\n--- 4. café contact number (admin only) ---');
t('column added', /manager_phone varchar\(32\)/.test(db));
t('documented as admin-only', /administrator-only and is never exposed to guests/.test(db));
t('accepted on save', /'manager_phone' => '%s'/.test(rest));
t('normalised like guest numbers', /'manager_phone' === \$key[\s\S]{0,320}havato_normalize_phone/.test(rest));
t('a bad number is dropped, not stored blank',
  /'manager_phone' === \$key[\s\S]{0,420}array_pop\( \$format \)/.test(rest));
t('owner form has the field', /name="manager_phone"/.test(oa));
t('owner form explains who sees it', /venue_phone_hint/.test(oa));
t('saved by the owner panel', /'manager_phone', 'quiet_hours'/.test(oa));
t('shown to the administrator', /manager_phone/.test(adm));
// The critical one: guests must never receive it.
t('only added to the PRIVATE payload', (() => {
  // It must appear inside the `if ( $private )` block and nowhere else.
  const open = rest.indexOf('if ( $private ) {');
  const close = rest.indexOf('\n\t\t}', open);
  const inside = rest.slice(open, close);
  const total = (rest.match(/\$payload\['manager_phone'\]/g) || []).length;
  return open !== -1 && inside.includes("$payload['manager_phone']") && total === 1;
})());
t('guest endpoints request the public payload',
  /venue_payload\( \$row, false \)/.test(rest));
t('the web app never references it', !/manager_phone/.test(js));
t('strings are trilingual', /'venue_phone'[\s\S]{0,200}'tr' =>/.test(i18n));

console.log('\n--- 5. map list spacing ---');
// The card is built from <span>s; margin/nowrap/ellipsis are all ignored on
// inline elements, so the name and the city ran together.
t('list body is block', /\.hv-list-body \{[^}]*display: block/.test(css));
t('title is block', /\.hv-list-title \{\s*\n\s*display: block/.test(css));
t('sub-line is block', /\.hv-list-sub \{\s*\n\s*display: block/.test(css));
t('the reason is documented', /MUST be block-level/.test(css) && /inline elements/.test(css));
t('the card shows the city', /venue\.city_label/.test(js));
t('separated from the address', /' · '/.test(js));
t('no separator when one side is missing', /venue\.city_label && venue\.address/.test(js));

console.log(f ? `\n❌ ${f} failing` : '\n✅ raspberry theme, full Turkish, admin-only café phone, map list fixed');
process.exit(f ? 1 : 0);
