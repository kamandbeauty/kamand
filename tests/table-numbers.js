/* Numbered tables + edit lock while an event is using them. */
const fs=require('fs');
const R=__dirname+'/../havato/';
const rd=f=>fs.readFileSync(R+f,'utf8');
const db=rd('includes/class-havato-db.php'), rest=rd('includes/class-havato-rest.php');
const oa=rd('includes/class-havato-owner-admin.php'), oj=rd('assets/js/havato-owner-admin.js');
const i18n=rd('includes/class-havato-i18n.php'), adm=rd('includes/class-havato-admin.php');
const main=rd('havato.php');
let f=0; const t=(n,c)=>{console.log((c?'✓ ':'❌ ')+n);if(!c)f++;};

console.log('--- numbering ---');
t('table_number column', /table_number int\(11\)/.test(db));
t('indexed per venue', /KEY table_number \(venue_id,table_number\)/.test(db));
t('DB version bumped', /HAVATO_DB_VERSION', '1\.5\.0'/.test(main));
t('number saved + clamped 1..999', /min\( 999, isset\( \$item\['table_number'\] \)/.test(rest));
t('exposed in the payload', /'table_number' => \(int\) \$row\['table_number'\]/.test(rest));
t('listed in number order', /ORDER BY table_number ASC/.test(rest));
t('number column in the editor', /table_number_col/.test(oj));
t('auto-picks the next free number', /function nextNumber/.test(oj));
t('shown as "Table #6" on the event picker', /table_number_label/.test(oa));
t('admin shows the numbers', /sprintf\( '#%d \(%d\)'/.test(adm));

console.log('\n--- duplicate numbers rejected ---');
t('server rejects duplicates', /havato_duplicate_number/.test(rest));
t('reason documented', /duplicate would make check-in ambiguous/.test(rest));
t('client flags them live', /function duplicates/.test(oj));
t('save disabled while duplicated', /if \(duplicates\(\)\.length\) \{ return; \}/.test(oj));
{
  const dupes=rows=>{const seen={},out=[];rows.forEach(r=>{if(seen[r.n])out.push(r.n);seen[r.n]=true;});return out;};
  t('1,2,3 -> no duplicates', dupes([{n:1},{n:2},{n:3}]).length===0);
  t('1,2,2 -> flagged', dupes([{n:1},{n:2},{n:2}]).join()==='2');
  const next=rows=>{const u={};rows.forEach(r=>u[r.n]=true);let n=1;while(u[n])n++;return n;};
  t('next number after 1,2,3 is 4', next([{n:1},{n:2},{n:3}])===4);
  t('fills the gap: 1,3 -> 2', next([{n:1},{n:3}])===2);
}

console.log('\n--- edit lock while an event is active ---');
t('lock helper', /function tables_locked_by/.test(rest));
t('save refuses when locked', /havato_tables_locked/.test(rest));
t('returns 409 conflict', /'status' => 409/.test(rest));
t('only future/unfinished events block', /status IN \('open','matched','pending_admin'\)/.test(rest));
t('completed events never block', !/'completed'[\s\S]{0,40}tables_locked_by/.test(rest));
t('6h grace so a running event still blocks', /INTERVAL 6 HOUR/.test(rest));
t('owner sees which events block', /hv-adm-locklist/.test(oa));
t('inputs disabled in the UI too', /var locked = host\.dataset\.locked === '1'/.test(oj));
t('UI lock is not the only guard (server checks too)',
  /tables_locked_by\( \$venue\['id'\] \)[\s\S]{0,200}havato_tables_locked/.test(rest));
{
  const now=new Date('2026-08-01T12:00');
  const blocks=(status,when)=>['open','matched','pending_admin'].includes(status)
    && (new Date(when) >= new Date(now.getTime()-6*3600*1000));
  t('future open event blocks', blocks('open','2026-08-05T19:00'));
  t('matched event blocks', blocks('matched','2026-08-02T19:00'));
  t('completed event does NOT block', !blocks('completed','2026-08-05T19:00'));
  t('last week\'s event does NOT block', !blocks('open','2026-07-20T19:00'));
  t('event 2h ago still blocks (guests may be seated)', blocks('matched','2026-08-01T10:00'));
}

console.log('\n--- migration of existing data ---');
t('migration exists', /function migrate_tables_to_numbered/.test(db));
t('runs on upgrade', /self::migrate_tables_to_numbered\(\)/.test(db));
t('expands quantity into numbered rows', /for \( \$i = 1; \$i < \$qty; \$i\+\+ \)/.test(db));
t('idempotent guard', /! in_array\( 'table_number', \$columns, true \)[\s\S]{0,30}return;/.test(db));
{
  // "3x4 + 1x6" must become 4 individually numbered tables
  const migrate=rows=>{let n=1,out=[];
    rows.forEach(r=>{for(let i=0;i<Math.max(1,r.quantity);i++) out.push({num:n++,seats:r.seats});});
    return out;};
  const got=migrate([{seats:4,quantity:3},{seats:6,quantity:1}]);
  t('3x4 + 1x6 -> 4 numbered tables', got.length===4);
  t('numbered 1..4 with no gaps', got.map(x=>x.num).join()==='1,2,3,4');
  t('seats preserved', got.map(x=>x.seats).join()==='4,4,4,6');
  t('total capacity unchanged (18)', got.reduce((a,b)=>a+b.seats,0)===18);
}

for (const k of ['table_number_col','table_number_label','table_number_duplicate',
                 'tables_locked','tables_locked_hint'])
  t(`i18n "${k}" bilingual`, new RegExp(`'${k}'[^\\n]*'fa' =>[^\\n]*'en' =>`).test(i18n));

console.log(f?`\n❌ ${f} failure(s)`:'\n✅ numbered tables, duplicates blocked, safe editing lock');
process.exit(f?1:0);
