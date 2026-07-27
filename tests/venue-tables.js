/* Café-defined furniture, per-event table selection, theme + optional photo. */
const fs=require('fs');
const R=__dirname+'/../havato/';
const rd=f=>fs.readFileSync(R+f,'utf8');
const db=rd('includes/class-havato-db.php'), rest=rd('includes/class-havato-rest.php');
const oa=rd('includes/class-havato-owner-admin.php'), oj=rd('assets/js/havato-owner-admin.js');
const adm=rd('includes/class-havato-admin.php'), i18n=rd('includes/class-havato-i18n.php');
const main=rd('havato.php'), css=rd('assets/css/havato-admin.css');
let f=0; const t=(n,c)=>{console.log((c?'✓ ':'❌ ')+n);if(!c)f++;};

console.log('--- schema ---');
t('venue_tables table', /CREATE TABLE \{\$p\}venue_tables/.test(db));
t('event_tables table', /CREATE TABLE \{\$p\}event_tables/.test(db));
t('seats + quantity per row', /seats int\(11\)/.test(db) && /quantity int\(11\)/.test(db));
t('both self-heal', /'venue_tables',/.test(db) && /'event_tables',/.test(db));
t('events gained theme + image', /theme varchar\(191\)/.test(db) && /image varchar\(255\)/.test(db));
{
  const v=/HAVATO_DB_VERSION', '(\d+)\.(\d+)\.(\d+)'/.exec(main);
  t('DB version bumped (>=1.4.0), got '+v[1]+'.'+v[2]+'.'+v[3],
    (+v[1])*10000+(+v[2])*100+(+v[3]) >= 10400);
}

console.log('\n--- owner defines the furniture ---');
t('"My tables" page', /function page_tables/.test(oa));
t('submenu registered', /'havato-venue-tables'/.test(oa));
t('GET + SAVE endpoints', /'owner\/tables'/.test(rest) && /'owner\/tables\/save'/.test(rest));
t('seats clamped 2..20', /max\( 2, min\( 20,/.test(rest));
// Each row is now ONE numbered physical table, so quantity is fixed at 1
// and the table NUMBER is what gets clamped instead.
t('quantity fixed at 1 per row', /'quantity'\s*=> 1,/.test(rest));
t('table number required, 1..999 enforced', /\$number < 1 \|\| \$number > 999/.test(rest));
t('removed tables soft-deleted, not dropped', /SET active = 0 WHERE venue_id = %s AND id NOT IN/.test(rest));
t('reason: past events keep resolving', /past events that referenced the table still resolve/.test(rest));
t('editor UI', /function initTables/.test(oj));
t('live seat total', /function totalSeats/.test(oj));

console.log('\n--- per-event selection ---');
t('checkbox per table', /hv-adm-tablepick-item/.test(oa));
t('quantity capped at what the café owns', /max="%d"[\s\S]{0,80}\$row\['quantity'\]/.test(oa) || /'quantity'/.test(oa));
t('only ticked tables submitted', /empty\( \$row\['use'\] \)/.test(oa));
t('capacity DERIVED, not typed', /\$capacity \+= \(int\) \$available\[ \$tid \]\['seats'\] \* \$qty/.test(rest));
t('cannot exceed owned quantity', /\$qty = min\( \$qty, \(int\) \$available\[ \$tid \]\['quantity'\] \)/.test(rest));
t('unknown table ids ignored', /! isset\( \$available\[ \$tid \] \)/.test(rest));
t('rejects an event with no capacity', /havato_no_tables/.test(rest));
t('legacy fallback to max_capacity', /Backwards compatible/.test(rest));
t('live capacity preview', /event_capacity_preview/.test(oj));

console.log('\n--- matcher seats one group PER TABLE ---');
const M=rd('includes/class-havato-matcher.php');
t('seat_plan() built from furniture', /function seat_plan/.test(M));
t('build_tables consumes the plan', /build_tables\( \$user_ids, \$profiles, \$seat_plan, \$relaxed \)/.test(M));
t('capacity advances per physical table', /\$plan_i\+\+;/.test(M));
{
  const plan=(tables,legacy)=>{let p=[];for(const r of tables)for(let i=0;i<r.quantity;i++)p.push(r.seats);
    return p.length?p.sort((a,b)=>b-a):[legacy];};
  const seat=(n,pl)=>{const out=[];let left=n,i=0;
    while(left>0&&i<50){const c=i<pl.length?pl[i]:pl[pl.length-1];out.push(Math.min(c,left));left-=Math.min(c,left);i++;}
    return out;};
  const p=plan([{seats:4,quantity:3},{seats:6,quantity:1}],6);
  t('3×4 + 1×6 -> capacity 18', p.reduce((a,b)=>a+b,0)===18);
  t('18 guests -> [6,4,4,4] not [18]', JSON.stringify(seat(18,p))==='[6,4,4,4]');
  t('7 guests -> [6,1], remaining tables unused', JSON.stringify(seat(7,p))==='[6,1]');
  t('legacy event -> one table', JSON.stringify(seat(6,plan([],6)))==='[6]');
}

console.log('\n--- theme + optional photo ---');
t('theme field on the form', /name="theme"/.test(oa));
t('photo picker on the form', /hv-event-image-pick/.test(oa));
t('photo optional — falls back to the café cover',
  /! empty\( \$row\['image'\] \) \? \$row\['image'\] :/.test(rest));
t('theme exposed to the app', /'theme'\s*=>\s*isset\( \$row\['theme'\] \)/.test(rest));
t('admin shows the layout (3×4 + 1×6)', /\$tbl\['quantity'\] \. '×' \. \$tbl\['seats'\]/.test(adm));
t('admin shows theme + event photo', /hv-adm-event-img/.test(adm));
t('styles added', /\.hv-adm-tablepick-item \{/.test(css));

for (const k of ['tab_tables','tables_hint','table_label','table_seats','table_quantity',
                 'event_tables_pick','event_capacity_preview','event_need_tables',
                 'event_theme','event_image'])
  t(`i18n "${k}" bilingual`, new RegExp(`'${k}'[^\\n]*'fa' =>[^\\n]*'en' =>`).test(i18n));

console.log(f?`\n❌ ${f} failure(s)`:'\n✅ furniture defined once, picked per event, matcher seats per table');
process.exit(f?1:0);
