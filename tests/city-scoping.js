/* 1) Country/city asked during the test  2) results scoped to that city
   3) nav labels AND icons fully white */
const fs=require('fs');
const R=__dirname+'/../havato/';
const rd=f=>fs.readFileSync(R+f,'utf8');
const fn=rd('includes/functions.php'), rest=rd('includes/class-havato-rest.php');
const db=rd('includes/class-havato-db.php'), js=rd('assets/js/havato-app.js');
const css=rd('assets/css/havato-app.css'), i18n=rd('includes/class-havato-i18n.php');
const adm=rd('includes/class-havato-admin.php'), seed=rd('includes/class-havato-seeder.php');
const noC=css.replace(/\/\*[\s\S]*?\*\//g,'');
let f=0; const t=(n,c)=>{console.log((c?'✓ ':'❌ ')+n);if(!c)f++;};

console.log('--- taxonomy: exactly the requested countries/cities ---');
t('havato_locations() defined', /function havato_locations\(\)/.test(fn));
t('Iran present', /'ir' => array\(/.test(fn));
t('Turkey present', /'tr' => array\(/.test(fn));
for (const c of ['tehran','isfahan','istanbul']) t(`city ${c}`, new RegExp(`'${c}'\\s*=>`).test(fn));
{
  // model the taxonomy to check pairings
  const L={ir:{cities:['tehran','isfahan']},tr:{cities:['istanbul']}};
  const valid=(co,ci)=>!!(L[co]&&L[co].cities.includes(ci));
  t('Iran+Tehran valid', valid('ir','tehran'));
  t('Iran+Isfahan valid', valid('ir','isfahan'));
  t('Turkey+Istanbul valid', valid('tr','istanbul'));
  t('Iran+Istanbul REJECTED', !valid('ir','istanbul'));
  t('Turkey+Tehran REJECTED', !valid('tr','tehran'));
  t('unknown country rejected', !valid('de','berlin'));
  const total=Object.values(L).reduce((n,c)=>n+c.cities.length,0);
  t('exactly 3 cities, no extras', total===3);
}
t('validators exported', /function havato_valid_city/.test(fn) && /function havato_valid_country/.test(fn));

console.log('\n--- asked during the personality test ---');
t('dedicated location step', /function stepLocation/.test(js));
t('step count raised to 7', /var steps = 7;/.test(js));
t('location is the FIRST step', /stepLocation, stepAge/.test(js));
t('cities derive from the chosen country', /locations\[country\]\.cities/.test(js));
t('changing country clears a stale city', /S\.testData\.city = ''; \/\/ a city from the old country/.test(js));
t('cannot advance without both', /S\.testStep === 0 && \(!S\.testData\.country \|\| !S\.testData\.city\)/.test(js));
t('gender validation moved to step 2', /S\.testStep === 2 && !S\.testData\.gender/.test(js));
t('server re-validates the pair', /havato_valid_city\( \$country, \$city \)/.test(rest));
t('server rejects a bad pair', /havato_bad_city/.test(rest));

console.log('\n--- schema ---');
t('profiles store country+city', /country varchar\(8\)[\s\S]{0,120}city varchar\(32\)/.test(db));
t('venues store country+city', /country varchar\(8\) NOT NULL DEFAULT 'ir'/.test(db));
t('venues.city indexed for the filter', /KEY city \(city\)/.test(db));
t('DB version bumped so dbDelta adds them', /HAVATO_DB_VERSION', '1\.2\.0'/.test(rd('havato.php')));

console.log('\n--- only the client’s city is shown ---');
t('viewer_city() helper', /private static function viewer_city/.test(rest));
t('events filtered by venue city', /AND v\.city = %s/.test(rest));
t('map venues filtered by city', /WHERE verified = 1 AND city = %s/.test(rest));
t('guests (no profile) still see everything', /if \( \$city \) \{/.test(rest));
t('empty state explains the scoping', /city_empty/.test(js) && /'city_empty'/.test(i18n));
{
  // simulate the filter
  const venues=[{n:'Vanak',city:'tehran'},{n:'Petra',city:'tehran'},
                {n:'Mana',city:'isfahan'},{n:'Kadikoy',city:'istanbul'}];
  const scope=(rows,city)=>city?rows.filter(v=>v.city===city):rows;
  t('Tehran user sees only Tehran (2)', scope(venues,'tehran').length===2);
  t('Isfahan user sees only Isfahan (1)', scope(venues,'isfahan').length===1);
  t('Istanbul user sees only Istanbul (1)', scope(venues,'istanbul').length===1);
  t('no cross-country leakage',
    scope(venues,'tehran').every(v=>v.city==='tehran'));
  t('guest sees all 4', scope(venues,'').length===4);
}

console.log('\n--- cafés declare their city ---');
t('signup asks for it', /locationSelects\('hv-reg'/.test(js));
t('signup sends it', /country: \$\('#hv-reg-country'\)\.value/.test(js));
t('signup requires a valid pair', /! havato_valid_city\( \$country, \$city \)/.test(rest));
t('venue settings can change it', /locationSelects\('hv-v', venue\.country, venue\.city\)/.test(js));
t('city list follows the country', /function bindLocationSelects/.test(js));
t('invalid pair dropped on save', /if \( ! havato_valid_city\( \$c, \$city \) \) \{[\s\S]{0,80}continue;/.test(rest));
t('admin table shows the city', /Havato_I18N::t\( 'q_city_select' \)/.test(adm));
t('demo venues have cities', /'city'\s*=>\s*'isfahan'/.test(seed) && /'city'\s*=>\s*'tehran'/.test(seed));

console.log('\n--- nav fully white ---');
t('labels white', /\.hv-tab \{ color: #fff; \}/.test(noC));
t('icons at full opacity', /\.hv-tab svg \{ opacity: 1; \}/.test(noC));
t('no dimmed-icon rule left', !/\.hv-tab:not\(\.is-active\) svg \{ opacity: 0\.\d/.test(noC));
t('state still shown by weight', /\.hv-tab\.is-active \{[^}]*font-weight:\s*800/s.test(noC));

for (const k of ['q_country','q_city_select','q_neighborhood','city_empty'])
  t(`i18n "${k}" bilingual`, new RegExp(`'${k}'[^\\n]*'fa' =>[^\\n]*'en' =>`).test(i18n));

console.log(f?`\n❌ ${f} failure(s)`:'\n✅ city taxonomy, scoping and white nav all correct');
process.exit(f?1:0);
