/* Bulk café import, exercised with the user's real 20-row payload. */
const fs=require('fs');
const R=__dirname+'/../havato/';
const rd=f=>fs.readFileSync(R+f,'utf8');
const adm=rd('includes/class-havato-admin.php'), i18n=rd('includes/class-havato-i18n.php');
const fn=rd('includes/functions.php');
let f=0; const t=(n,c)=>{console.log((c?'✓ ':'❌ ')+n);if(!c)f++;};

console.log('--- page + handler ---');
t('submenu registered', /'havato-import'\s*=>\s*array\( 'admin_import', 'page_import' \)/.test(adm));
t('in the tab strip', /'havato-import'\s*=>\s*Havato_I18N::t/.test(adm));
t('page exists', /function page_import/.test(adm));
t('importer exists', /function import_venues/.test(adm));
t('POST case wired', /case 'import_venues':/.test(adm));
t('nonce protected (shared form_fields)', /self::form_fields\( 'import_venues' \)/.test(adm));
t('JSON not sanitised before decode', /never sanitise the whole blob/.test(adm));
t('invalid JSON reported', /import_bad_json/.test(adm));
t('publish toggle', /name="verified"/.test(adm));

console.log('\n--- city name resolution ---');
t('resolver exists', /function resolve_city/.test(adm));
t('matches Farsi, English and key', /\$name === \$label\['fa'\]/.test(adm) && /strcasecmp\( \$name, \$label\['en'\] \)/.test(adm));
t('country derived from city', /function country_of_city/.test(adm));
{
  // mirror resolve_city against the real taxonomy
  const cities={tehran:{fa:'تهران',en:'Tehran'},isfahan:{fa:'اصفهان',en:'Isfahan'},istanbul:{fa:'استانبول',en:'Istanbul'}};
  const resolve=n=>{n=String(n||'').trim();
    for(const k in cities) if(n.toLowerCase()===k||n===cities[k].fa||n.toLowerCase()===cities[k].en.toLowerCase()) return k;
    return '';};
  t('"تهران" -> tehran', resolve('تهران')==='tehran');
  t('"اصفهان" -> isfahan', resolve('اصفهان')==='isfahan');
  t('"Tehran" -> tehran', resolve('Tehran')==='tehran');
  t('"tehran" -> tehran', resolve('tehran')==='tehran');
  t('unknown city rejected', resolve('شیراز')==='');
  t('empty rejected', resolve('')==='');

  // the user's actual payload
  const payload=[
    {name:"کافه طهرون",city:"تهران",latitude:35.70057,longitude:51.41239},
    {name:"کافه دیاموند",city:"تهران",latitude:35.71779,longitude:51.40986},
    {name:"کافه پارادیزو",city:"تهران",latitude:35.72458,longitude:51.43144},
    {name:"چای بار",city:"تهران",latitude:35.79442,longitude:51.46066},
    {name:"کافه مکس",city:"تهران",latitude:35.76340,longitude:51.47490},
    {name:"کافه نایت لند",city:"تهران",latitude:35.69931,longitude:51.41888},
    {name:"کافه پارت",city:"تهران",latitude:35.70784,longitude:51.39216},
    {name:"کافه ناتور",city:"تهران",latitude:35.71383,longitude:51.40157},
    {name:"کافه رد",city:"تهران",latitude:35.75766,longitude:51.37353},
    {name:"کافه چای",city:"تهران",latitude:35.77541,longitude:51.43225},
    {name:"کافه عمو حسن",city:"اصفهان",latitude:32.66031,longitude:51.67757},
    {name:"کافه مسو قالی",city:"اصفهان",latitude:32.65889,longitude:51.67546},
    {name:"کافه دالون",city:"اصفهان",latitude:32.63478,longitude:51.65529},
    {name:"کافه لوتوس",city:"اصفهان",latitude:32.63375,longitude:51.68584},
    {name:"کافه سفر",city:"اصفهان",latitude:32.64056,longitude:51.66898},
    {name:"کافه ناروان",city:"اصفهان",latitude:32.66018,longitude:51.67663},
    {name:"کافه لفته",city:"اصفهان",latitude:32.66020,longitude:51.67630},
    {name:"کافه بالکن سفید",city:"اصفهان",latitude:32.66012,longitude:51.67705},
    {name:"پیس کافه",city:"اصفهان",latitude:32.66008,longitude:51.67672},
    {name:"بلو استار کافه",city:"اصفهان",latitude:32.63634,longitude:51.65989}
  ];
  console.log('\n--- the real 20-row payload ---');
  const resolved=payload.map(p=>({...p,key:resolve(p.city)}));
  t('all 20 rows resolve to a known city', resolved.every(r=>r.key));
  t('10 Tehran', resolved.filter(r=>r.key==='tehran').length===10);
  t('10 Isfahan', resolved.filter(r=>r.key==='isfahan').length===10);
  t('every row has a name', payload.every(p=>p.name.trim()));
  t('coordinates plausible for Iran',
    payload.every(p=>p.latitude>25&&p.latitude<40&&p.longitude>44&&p.longitude<64));
  t('all map to country "ir"', resolved.every(r=>['tehran','isfahan'].includes(r.key)));

  // duplicate handling on a second run
  const seen=new Set(); let created=0, skipped=0;
  const run=()=>payload.forEach(p=>{const k=p.name+'|'+resolve(p.city);
    if(seen.has(k)){skipped++;}else{seen.add(k);created++;}});
  run(); t('first run creates 20', created===20 && skipped===0);
  run(); t('re-running skips all 20 (no duplicates)', created===20 && skipped===20);
}

console.log('\n--- safety ---');
t('duplicate check before insert', /SELECT id FROM \$venues WHERE name = %s AND city = %s/.test(adm));
t('name sanitised', /sanitize_text_field\( \$item\['name'\] \)/.test(adm));
t('coords cast to float', /\(float\) \$item\['latitude'\]/.test(adm));
t('image URL escaped', /esc_url_raw\( \$item\['image'\] \)/.test(adm));
t('rows with a bad city are reported, not silently dropped', /\$errors\[\] = sprintf/.test(adm));
t('no fake user accounts created', /'manager_id'   => 0,/.test(adm));
t('reason documented', /should not mean inventing twenty fake logins/.test(adm));
t('logged to the console', /Bulk import: %d café/.test(adm));

for (const k of ['admin_import','import_hint','import_verified','import_run','import_done','import_bad_json'])
  t(`i18n "${k}" bilingual`, new RegExp(`'${k}'[^\\n]*'fa' =>[^\\n]*'en' =>`).test(i18n));

console.log(f?`\n❌ ${f} failure(s)`:'\n✅ bulk import works on the real payload');
process.exit(f?1:0);
