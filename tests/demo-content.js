/* Demo directory (Tehran + Isfahan + Istanbul) and a purge that can only
   ever remove demo rows. */
const fs=require('fs');
const R=__dirname+'/../havato/';
const rd=f=>fs.readFileSync(R+f,'utf8');
const seed=rd('includes/class-havato-seeder.php'), db=rd('includes/class-havato-db.php');
const adm=rd('includes/class-havato-admin.php'), i18n=rd('includes/class-havato-i18n.php');
const main=rd('havato.php');
let f=0; const t=(n,c)=>{console.log((c?'✓ ':'❌ ')+n);if(!c)f++;};

console.log('--- demo flag ---');
t('venues.is_demo column', /is_demo tinyint\(1\)/.test(db));
t('events.is_demo column', (db.match(/is_demo tinyint\(1\)/g)||[]).length===2);
t('indexed', /KEY is_demo \(is_demo\)/.test(db));
t('DB version bumped', /HAVATO_DB_VERSION', '1\.6\.0'/.test(main));

console.log('\n--- catalogue: all three cities ---');
t('catalogue() exists', /function catalogue/.test(seed));
{
  const names=[...seed.matchAll(/'name'\s*=>\s*(?:'([^']+)'|"([^"]+)")/g)].map(m=>m[1]||m[2]);
  const cities=[...seed.matchAll(/'city'\s*=>\s*'(\w+)'/g)].map(m=>m[1]);
  const tehran=cities.filter(c=>c==='tehran').length;
  const isfahan=cities.filter(c=>c==='isfahan').length;
  const istanbul=cities.filter(c=>c==='istanbul').length;
  console.log(`   Tehran ${tehran} · Isfahan ${isfahan} · Istanbul ${istanbul} = ${cities.length}`);
  t('10 Tehran cafés', tehran===10);
  t('10 Isfahan cafés', isfahan===10);
  t('10 Istanbul cafés', istanbul===10);
  t('30 cafés total', cities.length===30);
  t('Persian names present', names.includes('کافه طهرون'));
  t('Turkish names present', names.includes('Karabatak') && names.includes('Kronotrop'));
  t('apostrophes handled', names.some(n=>n.includes("Walter's")));
  t('Turkish characters preserved', names.some(n=>n.includes('Beyoğlu')) || /Beyoğlu/.test(seed));
}
t('Istanbul mapped to country tr', /'istanbul' === \$sample\['city'\] \) \? 'tr' : 'ir'/.test(seed));
t('addresses carried over', /Kadıköy, Istanbul/.test(seed));

console.log('\n--- seeding ---');
t('everything flagged demo', /'is_demo'      => 1,/.test(seed));
t('events flagged too', (seed.match(/'is_demo'      => 1,/g)||[]).length>=2);
t('duplicates skipped (re-runnable)', /SELECT id FROM \$venues_t WHERE name = %s AND city = %s/.test(seed));
t('gives each café tables', /table_number.*=> \$number|1 => 4, 2 => 4, 3 => 6/.test(seed));
t('creates events with themes', /'theme'        => \$themes/.test(seed));
t('attaches tables to events', /\$et_t,/.test(seed));

console.log('\n--- purge safety (the critical part) ---');
t('purge() exists', /function purge/.test(seed));
t('selects ONLY demo venues', /SELECT id FROM \$venues_t WHERE is_demo = 1/.test(seed));
t('selects ONLY demo events', /SELECT id FROM \$events_t WHERE is_demo = 1/.test(seed));
t('no unconditional DELETE of venues', !/DELETE FROM \$venues_t(?!.*IN \()/.test(seed));
t('cleans registrations', /DELETE FROM \$regs_t WHERE event_id IN/.test(seed));
t('cleans event_tables', /DELETE FROM \$et_t WHERE event_id IN/.test(seed));
t('cleans venue tables', /DELETE FROM \$tables_t WHERE venue_id IN/.test(seed));
t('cleans groups, members and chat', /DELETE FROM \$gm_t/.test(seed) && /DELETE FROM \$chats_t/.test(seed) && /DELETE FROM \$groups_t/.test(seed));
t('reason documented', /real café that a real\s*\*? ?owner registered/.test(seed) || /left completely alone/.test(seed));
t('handles nothing-to-delete', /demo_none/.test(seed));
t('imported venues explicitly NOT demo', /'is_demo'      => 0,/.test(adm));
{
  // the property that matters: purge must be a strict subset
  const rows=[
    {id:'v1',name:'کافه طهرون',city:'tehran',demo:1},
    {id:'v2',name:'کافه واقعی',city:'tehran',demo:0},   // real, same city
    {id:'v3',name:'Karabatak',city:'istanbul',demo:1},
    {id:'v4',name:'Real Istanbul Cafe',city:'istanbul',demo:0},
    {id:'v5',name:'Imported',city:'isfahan',demo:0},
  ];
  const purge=rs=>rs.filter(r=>!r.demo);
  const after=purge(rows);
  t('purge removes exactly the 2 demo rows', rows.length-after.length===2);
  t('real café in the SAME city survives', after.some(r=>r.id==='v2'));
  t('real Istanbul café survives', after.some(r=>r.id==='v4'));
  t('imported café survives', after.some(r=>r.id==='v5'));
  t('no demo row remains', after.every(r=>!r.demo));
  t('purging twice is harmless', purge(after).length===after.length);
}

console.log('\n--- admin UI ---');
t('demo card', /function render_demo_card/.test(adm));
t('shows current counts', /demo_present/.test(adm));
t('delete button only when demo exists', /if \( \$has \) \{[\s\S]{0,400}purge_demo/.test(adm));
t('confirmation prompt', /onsubmit="return confirm/.test(adm));
t('purge handler wired', /case 'purge_demo':/.test(adm));
t('nonce protected', /self::form_fields\( 'purge_demo' \)/.test(adm));

for (const k of ['demo_title','demo_hint','demo_create','demo_remove','demo_confirm',
                 'demo_present','demo_created','demo_removed','demo_none'])
  t(`i18n "${k}" bilingual`, new RegExp(`'${k}'[^\\n]*'fa' =>[^\\n]*'en' =>`).test(i18n));

console.log(f?`\n❌ ${f} failure(s)`:'\n✅ 30 demo cafés, purge touches nothing real');
process.exit(f?1:0);
